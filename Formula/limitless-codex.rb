class LimitlessCodex < Formula
  desc "Resets your Codex rate limit at 99% so your agents never stall"
  homepage "https://github.com/Comradery64/limitless-codex"
  license "MIT"
  head "https://github.com/Comradery64/limitless-codex.git", branch: "main"

  depends_on "go" => :build
  depends_on macos: :ventura

  # Built from source and signed ad hoc on the user's Mac, so Gatekeeper never
  # quarantines it and no Apple Developer account is involved.
  def install
    system "make", "app", "VERSION=#{version}"
    prefix.install "bin/limitless-codex.app"
    bin.install_symlink prefix/"limitless-codex.app/Contents/MacOS/limitless-codex"
  end

  def caveats
    <<~EOS
      Finish setup (Codex sign-in, notifications, background monitoring):
        limitless-codex setup
    EOS
  end

  test do
    system "codesign", "--verify", prefix/"limitless-codex.app"
    output = shell_output("CODEX_BIN=/nonexistent #{bin}/limitless-codex --mode=status 2>&1", 1)
    assert_match "Failed to create Codex client", output
  end
end
