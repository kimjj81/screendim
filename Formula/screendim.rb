class Screendim < Formula
  desc "Dim every display to zero with one hotkey; any key, click or unlock restores"
  homepage "https://github.com/kimjj81/screendim"
  url "https://github.com/kimjj81/screendim/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "85e48bd79c65cadaf6ab823bea89bb9506b5aa4b8c7e17f1c7934138e840e910"
  license "MIT"
  head "https://github.com/kimjj81/screendim.git", branch: "main"

  depends_on arch: :arm64
  depends_on :macos

  def install
    system "make"
    bin.install "screendim"
  end

  def caveats
    <<~EOS
      Run this once to start screendim at login and enable the hotkey (ctrl+opt+cmd+b):
        screendim install
    EOS
  end

  test do
    assert_match "Usage:", shell_output("#{bin}/screendim help")
  end
end
