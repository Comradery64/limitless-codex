class LimitlessCodux < Formula
  desc "Prevent Codex agent downtime by auto-resetting rate limits"
  homepage "https://github.com/limitless-codex/limitless-codex"
  url "https://github.com/limitless-codex/limitless-codex/releases/download/v1.0.0/limitless-codex-darwin-arm64"
  version "1.0.0"
  sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

  bottle :unneeded

  depends_on "openai/codex/codex"

  def install
    bin.install "limitless-codex-darwin-arm64" => "limitless-codex"
  end

  service do
    run [opt_bin/"limitless-codex"]
    keep_alive true
    log_path "#{ENV['HOME']}/.local/var/log/limitless-codex.log"
    error_log_path "#{ENV['HOME']}/.local/var/log/limitless-codex-error.log"
  end

  test do
    system "#{bin}/limitless-codex", "--version"
  end
end
