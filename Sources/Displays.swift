// Brightness read/write for every online display: native (DisplayServices) first, DDC otherwise.

import ColorSync
import CoreGraphics
import Foundation

private let ds = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)
private typealias GetFn = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
private typealias SetFn = @convention(c) (UInt32, Float) -> Int32
private let dsGet = unsafeBitCast(dlsym(ds, "DisplayServicesGetBrightness"), to: GetFn.self)
private let dsSet = unsafeBitCast(dlsym(ds, "DisplayServicesSetBrightness"), to: SetFn.self)

struct Saved: Codable {
    var uuid: String
    var name: String
    var kind: String   // "native" | "ddc"
    var value: Float   // native: 0~1, ddc: raw VCP value
    var max: Float     // native: 1, ddc: VCP max
}

enum Displays {
    static func online() -> [CGDirectDisplayID] {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var n: UInt32 = 0
        CGGetOnlineDisplayList(16, &ids, &n)
        return Array(ids.prefix(Int(n)))
    }

    static func uuid(_ id: CGDirectDisplayID) -> String? {
        guard let u = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, u) as String
    }

    static func id(forUUID uuid: String) -> CGDirectDisplayID? {
        online().first { self.uuid($0) == uuid }
    }

    static func name(_ id: CGDirectDisplayID) -> String {
        if CGDisplayIsBuiltin(id) != 0 { return "Built-in" }
        return String(format: "%04X:%04X", CGDisplayVendorNumber(id), CGDisplayModelNumber(id))
    }

    static func snapshot() -> [Saved] {
        let ports = DDC.ports()
        return online().compactMap { id in
            guard let uuid = uuid(id) else { return nil }
            var b: Float = -1
            if dsGet(id, &b) == 0, b >= 0 {
                return Saved(uuid: uuid, name: name(id), kind: "native", value: b, max: 1)
            }
            if let port = DDC.port(for: id, in: ports), let r = DDC.read(port, DDC.luminance) {
                return Saved(uuid: uuid, name: name(id), kind: "ddc", value: Float(r.current), max: Float(r.max))
            }
            return nil
        }
    }

    /// `fraction` is 0~1 of the display's range.
    static func set(_ d: Saved, fraction: Float) {
        set(d, raw: d.kind == "native" ? fraction : (fraction * d.max).rounded())
    }

    static func set(_ d: Saved, raw: Float) {
        guard let id = id(forUUID: d.uuid) else { return }
        if d.kind == "native" {
            _ = dsSet(id, raw)
        } else if let port = DDC.port(for: id, in: DDC.ports()) {
            DDC.write(port, DDC.luminance, Int(raw))
        }
    }
}
