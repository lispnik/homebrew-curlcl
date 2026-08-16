# lispnik/curlcl

Homebrew formula for [curlcl](https://github.com/lispnik/curlcl) — a
curl-compatible command-line HTTP client, and the Common Lisp binding to
libcurl it is built on.

```
brew tap lispnik/curlcl
brew install curlcl
```

Or in one line, without tapping first:

```
brew install lispnik/curlcl/curlcl
```

The formula builds from `master` with SBCL and [ocicl](https://github.com/ocicl/ocicl);
neither is needed afterwards, since the Lisp image is dumped with a copy of the
runtime inside it.

It depends on Homebrew's `curl` deliberately. curlcl opens libcurl at startup
rather than linking it, from a search list that begins with Homebrew's keg-only
path — so installing this way gets you a recent libcurl that can speak `ws://`,
rather than the older one in the macOS dyld shared cache that cannot. `curlcl -V`
prints which library it found:

```
$ curlcl -V
curlcl 0.1.0 (aarch64-apple-darwin25.4.0) libcurl/8.21.0 OpenSSL/3.6.3
Library: /opt/homebrew/opt/curl/lib/libcurl.4.dylib
Protocols: … http https … ws wss
```

Prebuilt binaries for Linux, macOS and Windows are on the
[releases page](https://github.com/lispnik/curlcl/releases) if you would rather
not build.
