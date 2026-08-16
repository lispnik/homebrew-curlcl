class Curlcl < Formula
  desc "Curl-compatible command-line HTTP client, and a Common Lisp binding to libcurl"
  homepage "https://github.com/lispnik/curlcl"
  # The released tarball rather than master, which is what makes the version
  # mean anything.  Built from a branch with a pinned version, brew compares
  # version strings, sees 0.1.0 both sides and never rebuilds -- so `brew
  # upgrade' is a no-op however far master has moved, and two people installing
  # on different days get different code calling itself the same release.
  url "https://github.com/lispnik/curlcl/archive/refs/tags/v0.1.2.tar.gz"
  sha256 "7847f1447fd483d0a1509aadc2545f41f34d88b3f40a638e997f12faddafb990"
  license "MIT"

  # For anyone who does want master: brew install --HEAD curlcl, and
  # brew upgrade --fetch-HEAD to move it on.
  head "https://github.com/lispnik/curlcl.git", branch: "master"

  # SBCL and ocicl are build-only: program-op dumps the Lisp image together
  # with a copy of the SBCL runtime, so the installed binary needs neither.
  depends_on "ocicl" => :build
  depends_on "pkgconf" => :build
  depends_on "sbcl" => :build

  # curl is not optional here, and not only for the headers.  The binding opens
  # libcurl at startup from a search list that begins with Homebrew's keg-only
  # path, so this decides *which* libcurl the installed binary talks to: the
  # newer one with websockets, rather than the 8.7.1 in the dyld shared cache
  # that has no ws:// at all.  `curlcl -V' prints the one it found.
  depends_on "curl"
  # cffi-libffi calls through libffi -- the whole reason it exists is that
  # curl_easy_setopt is variadic and needs a real libffi call on stack-passing
  # ABIs like Darwin arm64.
  depends_on "libffi"
  # Not used by curlcl, but linked into every image SBCL dumps: Homebrew's SBCL
  # is built with core compression, so the runtime carries a reference to
  # libzstd by absolute path.  The ocicl formula in homebrew-core declares this
  # for the same reason.  Without it the binary cannot start.
  depends_on "zstd"

  def install
    # ocicl writes its runtime and its registry under HOME.  Point that at the
    # build directory so nothing is read from, or left in, the real one.
    build_home = buildpath/"build-home"
    build_home.mkpath
    ENV["HOME"] = build_home

    system "ocicl", "setup"
    system "ocicl", "install"

    # Through asdf:make, and deliberately not through sb-ext:save-lisp-and-die.
    # program-op dumps by way of uiop:dump-image, which runs the image-dump
    # hooks -- and one of those closes libcurl before the image is written.  A
    # raw save-lisp-and-die skips them, the saved image keeps a record of the
    # shared object, and dyld reopens it at startup by soname, which resolves
    # through the shared cache to the system libcurl.  The binary then runs
    # against a different library than the one it was built against, silently.
    system "sbcl", "--non-interactive",
           "--load", build_home/".local/share/ocicl/ocicl-runtime.lisp",
           "--eval", "(asdf:initialize-source-registry " \
                     "(list :source-registry (list :directory (uiop:getcwd)) " \
                     ":inherit-configuration))",
           "--eval", "(asdf:make :curlcl/cli)"

    bin.install "bin/curlcl"
  end

  test do
    # -V reports the libcurl that was actually opened, which is the thing worth
    # asserting: it proves the dump-time unload and the startup reopen both
    # worked, and that the keg-only curl above is the one that was found.
    version_output = shell_output("#{bin}/curlcl -V")
    assert_match "curlcl #{version}", version_output
    assert_match "libcurl/", version_output
    assert_match formula_opt_prefix("curl").to_s, version_output

    # A real transfer, served locally so the test needs no network.
    (testpath/"hello.txt").write "hello from the formula test"
    port = free_port
    pid = spawn "python3", "-m", "http.server", port.to_s, "-d", testpath
    begin
      sleep 2
      assert_equal "hello from the formula test",
                   shell_output("#{bin}/curlcl -s http://127.0.0.1:#{port}/hello.txt")
      # Asserted through the exit status rather than --write-out, because the
      # status is the part a script depends on: these are libcurl's own
      # CURLcode values, and 22 is what curl --fail exits with on a 404.
      shell_output("#{bin}/curlcl -s -f -o /dev/null " \
                   "http://127.0.0.1:#{port}/nope", 22)
    ensure
      Process.kill "TERM", pid
      Process.wait pid
    end
  end
end
