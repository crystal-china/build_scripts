## Dependencies

On Linux, most of these tools are already available, though you may need to install the Zig compiler.

- Bash (version > 4.0)
- sed
- Zig compiler
- Ruby (optional): only needed if you want to fetch the libraries yourself. I also upload the libraries as assets on the [releases page](https://github.com/crystal-china/crystal_build_scripts/releases).

## How to use it

1. Clone the repository: `git clone https://github.com/crystal-china/crystal_build_scripts`.
2. In the repository directory, run `bundle install`, followed by `rake fetch:all`. You can skip this step if you download the libraries from the GitHub releases page instead. Extract them so that `PROJECT_ROOT/lib` has the following structure:

```
 ╰─ $ tree -L1 lib
lib
├── aarch64-linux-musl
├── aarch64-sonoma
├── x86_64-linux-musl
└── x86_64-sonoma
```

3. Add `PROJECT_ROOT/bin` to your `$PATH`. You can then use `sb` to cross-compile a Crystal program.

4. Go to the Crystal project you want to build. I use the following command to build an AMD64 static binary that I can copy to and run on any AMD64 Linux host:

```sh
$: sb --cross-compile --target=x86_64-linux-musl --static --no-debug --link-flags=-s --release
```

You can use `sb` in place of `shards build`; it takes care of using `zig cc` when cross-compiling.

----------------

The following examples show how I cross-compile binaries for `x86_64-linux-musl`, `aarch64-linux-musl`, `x86_64-darwin`, and `aarch64-darwin` on my Linux host.

```sh
 ╰─ $ sb --cross-compile --target=x86_64-linux-musl --static
zig cc -target x86_64-linux-musl bin/college.o -o bin/college  -rdynamic -static -L/home/zw963/Crystal/crystal-china/crystal_build_scripts/lib/x86_64-linux-musl -lgmp -lyaml -lz `command -v pkg-config > /dev/null && pkg-config --libs --silence-errors libssl || printf %s '-lssl -lcrypto'` `command -v pkg-config > /dev/null && pkg-config --libs --silence-errors libcrypto || printf %s '-lcrypto'` -lpcre2-8 -lgc -lpthread -ldl -levent -lunwind

 ╰─ $ file bin/college
bin/college: ELF 64-bit LSB executable, x86-64, version 1 (SYSV), static-pie linked, with debug_info, not stripped
```

You can use `sb --target=amd64` instead.

-------------

```sh

 ╰─ $ sb --cross-compile --target=aarch64-linux-musl --static
zig cc -target aarch64-linux-musl bin/college.o -o bin/college  -rdynamic -static -L/home/zw963/Crystal/crystal-china/crystal_build_scripts/lib/aarch64-linux-musl -lgmp -lyaml -lz `command -v pkg-config > /dev/null && pkg-config --libs --silence-errors libssl || printf %s '-lssl -lcrypto'` `command -v pkg-config > /dev/null && pkg-config --libs --silence-errors libcrypto || printf %s '-lcrypto'` -lpcre2-8 -lgc -lpthread -ldl -levent -lunwind

 ╰─ $ file bin/college
bin/college: ELF 64-bit LSB executable, ARM aarch64, version 1 (SYSV), static-pie linked, with debug_info, not stripped
```

You can use `sb --target=arm64` instead.

-------------

```sh
 ╰─ $ sb --cross-compile --target=x86_64-darwin --static
zig cc -target x86_64-macos-none bin/college.o -o bin/college  -rdynamic -static -L/home/zw963/Crystal/crystal-china/crystal_build_scripts/lib/x86_64-sonoma -lgmp -lyaml -lz `command -v pkg-config > /dev/null && pkg-config --libs --silence-errors libssl || printf %s '-lssl -lcrypto'` `command -v pkg-config > /dev/null && pkg-config --libs --silence-errors libcrypto || printf %s '-lcrypto'` -lpcre2-8 -lgc -lpthread -ldl -levent -liconv -lunwind

  ╰─ $ file bin/college
bin/college: Mach-O 64-bit x86_64 executable, flags:<NOUNDEFS|DYLDLINK|TWOLEVEL|NO_REEXPORTED_DYLIBS|PIE|HAS_TLV_DESCRIPTORS>
```

You can use `sb --target=amd64-mac` instead.

------------

```sh

 ╰─ $ sb --cross-compile --target=aarch64-darwin --static
zig cc -target aarch64-macos-none bin/college.o -o bin/college  -rdynamic -static -L/home/zw963/Crystal/crystal-china/crystal_build_scripts/lib/aarch64-sonoma -lgmp -lyaml -lz `command -v pkg-config > /dev/null && pkg-config --libs --silence-errors libssl || printf %s '-lssl -lcrypto'` `command -v pkg-config > /dev/null && pkg-config --libs --silence-errors libcrypto || printf %s '-lcrypto'` -lpcre2-8 -lgc -lpthread -ldl -levent -liconv -lunwind

 ╰─ $ file bin/college
bin/college: Mach-O 64-bit arm64 executable, flags:<NOUNDEFS|DYLDLINK|TWOLEVEL|NO_REEXPORTED_DYLIBS|PIE|HAS_TLV_DESCRIPTORS>
```

You can use `sb --target=arm64-mac` instead.

-----------

I've been using this workflow for a long time, and it works well for me. I don't want to add unnecessary complexity to achieve the same result. I'm comfortable with Docker too; I just prefer to use it only when I need it.

## Currently supported libraries (Alpine package name / macOS package name)

- gc-dev/bdw-gc
- gmp-dev/gmp
- pcre2-dev/pcre2
- libevent-static/libevent
- libsodium-static/libsodium
- openssl-libs-static/openssl@3
- sqlite-static/sqlite
- yaml-static/yaml
- zlib-static/zlib
- libxml2-static/libxml2
- xz-static/xz (used by libxml2)
- gnu-libiconv/libiconv (used only for macOS)

If you need support for other third-party libraries, feel free to open an issue.

## Updating library versions

### Updating libraries for Alpine

1. Open the package directory for the Alpine release you want to use in your browser, and find the latest package filename. For example, the output below uses `gc-dev-8.2.12-r0.apk` from https://dl-cdn.alpinelinux.org/alpine/v3.24/main
2. Run `./scripts/alpine_sha256_gen gc-dev-8.2.12-r0.apk` in your terminal. The output will look like this:

```sh
 ╰──➤ $ scripts/alpine_sha256_gen gc-static-8.2.12-r0.apk
--2026-10-02 14:27:58--  https://mirrors.tuna.tsinghua.edu.cn/alpine/v3.24/main/aarch64/gc-static-8.2.12-r0.apk
Loaded CA certificate '/etc/ssl/certs/ca-certificates.crt'
Resolving mirrors.tuna.tsinghua.edu.cn (mirrors.tuna.tsinghua.edu.cn)... 2402:f000:1:400::2, 101.6.15.130
Connecting to mirrors.tuna.tsinghua.edu.cn (mirrors.tuna.tsinghua.edu.cn)|2402:f000:1:400::2|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 478041 (467K) [application/octet-stream]
Saving to: ‘/tmp/gc-static-8.2.12-r0.apk.aarch64’

/tmp/gc-static-8.2.12-r0.apk.aarc 100%[============================================================>] 466.84K  1.49MB/s    in 0.3s

2026-10-02 14:27:58 (1.49 MB/s) - ‘/tmp/gc-static-8.2.12-r0.apk.aarch64’ saved [478041/478041]

--2026-10-02 14:27:58--  https://mirrors.tuna.tsinghua.edu.cn/alpine/v3.24/main/x86_64/gc-static-8.2.12-r0.apk
Loaded CA certificate '/etc/ssl/certs/ca-certificates.crt'
Resolving mirrors.tuna.tsinghua.edu.cn (mirrors.tuna.tsinghua.edu.cn)... 2402:f000:1:400::2, 101.6.15.130
Connecting to mirrors.tuna.tsinghua.edu.cn (mirrors.tuna.tsinghua.edu.cn)|2402:f000:1:400::2|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 484181 (473K) [application/octet-stream]
Saving to: ‘/tmp/gc-static-8.2.12-r0.apk.x86_64’

/tmp/gc-static-8.2.12-r0.apk.x86_ 100%[============================================================>] 472.83K  2.05MB/s    in 0.2s

2026-10-02 14:27:59 (2.05 MB/s) - ‘/tmp/gc-static-8.2.12-r0.apk.x86_64’ saved [484181/484181]

    - platform: aarch64-linux-musl
      url: https://mirrors.tuna.tsinghua.edu.cn/alpine/v3.24/main/aarch64/gc-static-8.2.12-r0.apk
      sha256: "bd52c9a0c74f54e7bf1992fc84221d4223969469fad996cc0cc160808c06e0aa"
    - platform: x86_64-linux-musl
      url: https://mirrors.tuna.tsinghua.edu.cn/alpine/v3.24/main/x86_64/gc-static-8.2.12-r0.apk
      sha256: "c8f2dc4491237014595585a01b3219701215d44100bc90e2d4d6cba931367d28"
```

Then copy the last part into the corresponding entries in `libs.yml`.

3. Before running `alpine_sha256_gen`, make sure the Alpine version in the script matches the release you want to use. The example above uses Alpine v3.24. Alpine's prebuilt GMP 6.3.0 library still does not work with this cross-compilation workflow; I opened an [issue](https://github.com/ziglang/zig/issues/21112) to track it.

### Updating libraries for Darwin (macOS)

1. Visit https://github.com/Homebrew/homebrew-core/tree/master/Formula.
2. Press `t` and search for the package name. Homebrew names may differ from
   Alpine names: for example, the `gc` library uses `bdw-gc.rb`. Check the
   `homebrew formulae` comments in `libs.yml` for the correct formula name.
3. Check the `bottle do` block. Select the oldest macOS release supported by
   both x86_64 and aarch64 across all selected libraries. Currently, we use Sonoma
   (`arm64_sonoma` for aarch64 and `sonoma` for x86_64). If the current formula
   has no Intel macOS bottle, use the most recent formula revision that provides both
   architectures; the pinned formula links are recorded in `libs.yml`.
4. Update the GHCR blob URL and `sha256`, and set `darwin_version` to the
   bottle's package version, including any Homebrew revision suffix (e.g. `10.47_1`).
   Keep the Alpine `version` separate. If the selected macOS release changes, update
   the platform names in `libs.yml` and the library directory mappings in `bin/sb`.
5. iconv is only needed for Darwin, so you don't need to update it for Alpine.
6. The Darwin ICU entries intentionally use stubs because the selected libxml2 bottles
   do not depend on ICU. libxml2 bottles provide `libxml2.16.dylib` and
   `libxml2.dylib`; the Alpine package still provides `libxml2.a`.

## How it works

See [Using Zig CC as an alternative linker](use_zig_cc_as_an_alternative_linker.md).

## Contributing

1. [Fork the repository](https://github.com/crystal-china/crystal_build_scripts/fork).
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Open a pull request.

## Contributors

- [luislavena](https://github.com/luislavena) - creator and maintainer
- [Billy.Zheng](https://github.com/zw963) - current maintainer
