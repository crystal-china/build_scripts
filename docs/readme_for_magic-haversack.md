## Dependencies

If you are use linux, all dependencies is almost available, except zig compiler.

- BASH (version > 4.0)
- sed
- zig compiler
- Ruby (Optional), It only necessary if you want download the libraries by yourself, I will upload those libraries as assets in [release page](https://github.com/crystal-china/crystal_build_scripts/releases).

## How to use it.

1.  git clone https://github.com/crystal-china/crystal_build_scripts
2.  Run `bundle install` then `rake fetch:all`, You can skip this step if you download libraries from github release page instead, and extract it into `PROJECT_ROOT/lib`, as following:

```
 ╰─ $ tree -L1 lib
lib
├── aarch64-linux-musl
├── aarch64-sonoma
├── x86_64-linux-musl
└── x86_64-sonoma
```

3. Add `PROJECT_ROOT/bin` into system $PATH, then you can run `sb` script for cross build a Crystal program, you can always use `sb ...` as an alternative of `shards build ...`

4. Entering the Crystal project you want to execute the build on, I use following command for built an AMD64 static binary which can copy into and running it on any linux host.

```sh
$: sb --cross-compile --target=x86_64-linux-musl --static --no-debug --link-flags=-s --release
```

You can use sb as a alias for `shards build`, but it where take care use zig cc if cross compile.

----------------

Check following example for cross build a binary for `x86_64-linux-musl`, `aarch-linux-musl`，`x86_64-darwin` and `aarch-darwin` on my linux host.

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

 I have been using this workflow for a long time, and it work quite well, so i don't want add unnecessary complexity for same purpose, don't misunderstand me, i use docker quite well, but I use it only necessary.
 
## Current supported lib (alpine package name/macOS package name)

- gc-dev/gdw-gc
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

If you use other third-party libraries, please feel free to submit an issue.

## Update libraries version

### Steps to update libraries version for alpine:

1. Visit https://dl-cdn.alpinelinux.org/alpine/v3.20/main/aarch64/ use browser, and find out the latest package name, e.g. gc-dev-8.2.6-r0.apk
2. run `./scripts/alpine_sha256_gen gc-dev-8.2.6-r0.apk' in the terminal, it will output like following:

```sh
 ╰─ $ ./scripts/alpine_sha256_gen gc-dev-8.2.6-r0.apk
--2024-08-18 16:27:08--  https://mirrors.tuna.tsinghua.edu.cn/alpine/v3.20/main/aarch64/gc-dev-8.2.6-r0.apk
Loaded CA certificate '/etc/ssl/certs/ca-certificates.crt'
Resolving mirrors.tuna.tsinghua.edu.cn (mirrors.tuna.tsinghua.edu.cn)... 2402:f000:1:400::2, 101.6.15.130
Connecting to mirrors.tuna.tsinghua.edu.cn (mirrors.tuna.tsinghua.edu.cn)|2402:f000:1:400::2|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 538608 (526K) [application/octet-stream]
Saving to: ‘/tmp/gc-dev-8.2.6-r0.apk.aarch64’

/tmp/gc-dev-8.2.6-r0.apk.aarc 100%[===============================================>] 525.98K   987KB/s    in 0.5s

2024-08-18 16:27:09 (987 KB/s) - ‘/tmp/gc-dev-8.2.6-r0.apk.aarch64’ saved [538608/538608]

--2024-08-18 16:27:09--  https://mirrors.tuna.tsinghua.edu.cn/alpine/v3.20/main/x86_64/gc-dev-8.2.6-r0.apk
Loaded CA certificate '/etc/ssl/certs/ca-certificates.crt'
Resolving mirrors.tuna.tsinghua.edu.cn (mirrors.tuna.tsinghua.edu.cn)... 2402:f000:1:400::2, 101.6.15.130
Connecting to mirrors.tuna.tsinghua.edu.cn (mirrors.tuna.tsinghua.edu.cn)|2402:f000:1:400::2|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 546905 (534K) [application/octet-stream]
Saving to: ‘/tmp/gc-dev-8.2.6-r0.apk.x86_64’

/tmp/gc-dev-8.2.6-r0.apk.x86_ 100%[===============================================>] 534.09K  1.06MB/s    in 0.5s

2024-08-18 16:27:10 (1.06 MB/s) - ‘/tmp/gc-dev-8.2.6-r0.apk.x86_64’ saved [546905/546905]

url: https://dl-cdn.alpinelinux.org/alpine/v3.20/main/aarch64/gc-dev-8.2.6-r0.apk
sha256: "6a2eec3ee1117941e25549a044f4d8db8bfc9fe3083db767e50b50c7100e6770"
url: https://dl-cdn.alpinelinux.org/alpine/v3.20/main/x86_64/gc-dev-8.2.6-r0.apk
sha256: "b9d32564cd61897c56b3d57eb8cf573f9f38bd591f75f74d5b20bceddaaf94f2"
```

Then override specified yaml section use the above url,sha256 output part.

3. you probably need replace alpine version with latest version before running `alpine_sha256_gen`,current use alpine v3.20, except gmp, 6.3.0 still not work for now, i create a [issue](https://github.com/ziglang/zig/issues/21112) for tracing it.

### Steps to update libraries version For Darwin:

1. Visit https://github.com/Homebrew/homebrew-core/tree/master/Formula
2. Typing t, then filter with the package name(probably use different name with alpine, 
   e.g. for `gc` library, need search file `bdw-gc.rb`), check `homebrew formulae` 
   in libs.yml for correct file name.
3. Check the `bottle do` block. Select the oldest macOS code name supported by
   both x86_64/aarch64 across all selected libraries. Currently we use Sonoma
   (`arm64_sonoma` for aarch64 and `sonoma` for x86_64). If the current formula
   has no Intel macOS bottle, use the last formula revision that provides both
   architectures; the pinned formula links are recorded in `libs.yml`.
4. Update both the GHCR blob URL and `sha256`, and set `darwin_version` to the
   bottle package version, including any Homebrew revision suffix (e.g. `10.47_1`).
   Keep the Alpine `version` separate. If the macOS code name changes, update
   the platform names in `libs.yml` and the library directory mappings in `bin/sb`.
5. iconv is necessary only for Darwin, you don't need update it for alpine.
6. Darwin ICU entries intentionally use stubs: the selected libxml2 bottles
   do not depend on ICU. libxml2 bottles provide `libxml2.16.dylib` and
   `libxml2.dylib`; the Alpine package still provides `libxml2.a`.

## How it works

Check [use_zig_cc_as_an_alternative_linker](docs/use_zig_cc_as_an_alternative_linker.md)

## Contributing

1. Fork it (<https://github.com/crystal-china/hashr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [luislavena](https://github.com/luislavena) - creator and maintainer
- [Billy.Zheng](https://github.com/zw963) - current maintainer
