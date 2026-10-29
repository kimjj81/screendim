// DDC/CI over IOAVService (Apple Silicon). No external tools needed.

import CoreGraphics
import Foundation
import IOKit

@_silgen_name("IOAVServiceCreateWithService")
func IOAVServiceCreateWithService(_ allocator: CFAllocator?, _ service: io_service_t) -> Unmanaged<CFTypeRef>?

@_silgen_name("IOAVServiceReadI2C")
func IOAVServiceReadI2C(_ service: CFTypeRef, _ chipAddress: UInt32, _ offset: UInt32,
                        _ buffer: UnsafeMutableRawPointer, _ size: UInt32) -> IOReturn

@_silgen_name("IOAVServiceWriteI2C")
func IOAVServiceWriteI2C(_ service: CFTypeRef, _ chipAddress: UInt32, _ dataAddress: UInt32,
                         _ buffer: UnsafeMutableRawPointer, _ size: UInt32) -> IOReturn

enum DDC {
    static let luminance: UInt8 = 0x10
    private static let chip: UInt32 = 0x37
    private static let dataAddress: UInt32 = 0x51
    private static let hostAddress: UInt8 = 0x6E

    struct Port {
        let edidUUID: String
        let service: CFTypeRef
    }

    /// External AV services, each paired with the EDID UUID of the framebuffer listed just before it.
    static func ports() -> [Port] {
        var iter = io_iterator_t()
        guard IORegistryEntryCreateIterator(IORegistryGetRootEntry(kIOMainPortDefault), kIOServicePlane,
                                            IOOptionBits(kIORegistryIterateRecursively), &iter) == KERN_SUCCESS
        else { return [] }
        defer { IOObjectRelease(iter) }

        var ports: [Port] = []
        var pendingUUID: String?
        while case let entry = IOIteratorNext(iter), entry != 0 {
            defer { IOObjectRelease(entry) }
            var nameBuf = [CChar](repeating: 0, count: 128)
            IORegistryEntryGetName(entry, &nameBuf)
            let name = String(cString: nameBuf)

            if name == "AppleCLCD2" || name == "IOMobileFramebufferShim" {
                pendingUUID = property(entry, "EDID UUID") as? String
            } else if name == "DCPAVServiceProxy",
                      property(entry, "Location") as? String == "External",
                      let uuid = pendingUUID,
                      let svc = IOAVServiceCreateWithService(kCFAllocatorDefault, entry)?.takeRetainedValue() {
                ports.append(Port(edidUUID: uuid, service: svc))
                pendingUUID = nil
            }
        }
        return ports
    }

    /// EDID UUID starts with vendor ID then product ID (little-endian), e.g. "05900016-..." → 0x0590, 0x1600.
    static func port(for display: CGDirectDisplayID, in ports: [Port]) -> Port? {
        let vendor = String(format: "%04X", CGDisplayVendorNumber(display))
        let model = CGDisplayModelNumber(display)
        let modelLE = String(format: "%02X%02X", model & 0xFF, (model >> 8) & 0xFF)
        return ports.first { $0.edidUUID.uppercased().hasPrefix(vendor + modelLE) }
    }

    static func read(_ port: Port, _ vcp: UInt8) -> (current: Int, max: Int)? {
        var req: [UInt8] = [0x82, 0x01, vcp]
        req.append(checksum(hostAddress ^ UInt8(dataAddress), req))
        for _ in 0..<4 {
            for _ in 0..<2 {
                _ = req.withUnsafeMutableBytes { IOAVServiceWriteI2C(port.service, chip, dataAddress, $0.baseAddress!, UInt32($0.count)) }
                usleep(10_000)
            }
            usleep(40_000)
            var reply = [UInt8](repeating: 0, count: 12)
            let r = reply.withUnsafeMutableBytes { IOAVServiceReadI2C(port.service, chip, dataAddress,$0.baseAddress!, UInt32($0.count)) }
            if r == kIOReturnSuccess, reply[2] == 0x02, reply[3] == 0x00, reply[4] == vcp {
                let max = Int(reply[6]) << 8 | Int(reply[7])
                let cur = Int(reply[8]) << 8 | Int(reply[9])
                return (cur, max)
            }
            usleep(50_000)
        }
        return nil
    }

    @discardableResult
    static func write(_ port: Port, _ vcp: UInt8, _ value: Int) -> Bool {
        var data: [UInt8] = [0x84, 0x03, vcp, UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)]
        data.append(checksum(hostAddress ^ UInt8(dataAddress), data))
        var ok = false
        for _ in 0..<2 {
            let r = data.withUnsafeMutableBytes { IOAVServiceWriteI2C(port.service, chip, dataAddress, $0.baseAddress!, UInt32($0.count)) }
            ok = ok || r == kIOReturnSuccess
            usleep(10_000)
        }
        return ok
    }

    private static func checksum(_ seed: UInt8, _ bytes: [UInt8]) -> UInt8 {
        bytes.reduce(seed, ^)
    }

    private static func property(_ entry: io_registry_entry_t, _ key: String) -> Any? {
        IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }
}
