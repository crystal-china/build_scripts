## Dependencies

On Linux, most of these tools are already available, though you may need to install the Zig compiler.

- `bash` (version > 4.0)
- `sed`
- `zig` compiler
- `tar` with xz support for extracting and packaging the libraries
- `make` `gcc` `m4` `llvm`, which build the Linux GMP libraries.
  `gcc` provides `cc`; `llvm` provides the three `llvm-*` tools. GMP uses `m4` to preprocess assembly files.
- `crystal` and `shards` (optional): only needed if you want to fetch/build the libraries yourself.

## How to use it

1. `git clone https://github.com/crystal-china/crystal_build_scripts`.
2. `shards install`
3. `shards build`
4. `bin/tasks all`, it's also builds the non-LTO GMP libraries for both Linux targets.

Following is the all tasks available.

```bash
 ╰──➤ $ bin/tasks
Usage: bin/tasks <task>
all # Fetch all libraries and build Linux GMP
fetch:aarch64-linux-musl
fetch:aarch64-linux-musl:gc-static # 8.2.12-r0
fetch:aarch64-linux-musl:libxml2-static # 2.13.9-r2
fetch:aarch64-linux-musl:openssl-libs-static # 3.5.9-r0
fetch:aarch64-linux-musl:pcre2-static # 10.49-r0
fetch:aarch64-linux-musl:sqlite-static # 3.53.4-r0
fetch:aarch64-linux-musl:xz-static # 5.8.4-r0
fetch:aarch64-linux-musl:yaml-static # 0.2.5-r2
fetch:aarch64-linux-musl:zlib-static # 1.3.2-r0
fetch:aarch64-sonoma
fetch:aarch64-sonoma:bdw-gc # 8.2.12
fetch:aarch64-sonoma:gmp # 6.3.0
fetch:aarch64-sonoma:libiconv # 1.19
fetch:aarch64-sonoma:libxml2 # 2.15.3
fetch:aarch64-sonoma:libyaml # 0.2.5
fetch:aarch64-sonoma:openssl@3 # 3.6.3
fetch:aarch64-sonoma:pcre2 # 10.47_1
fetch:aarch64-sonoma:sqlite # 3.53.4
fetch:aarch64-sonoma:zlib # 1.3.2
fetch:x86_64-linux-musl
fetch:x86_64-linux-musl:gc-static # 8.2.12-r0
fetch:x86_64-linux-musl:libxml2-static # 2.13.9-r2
fetch:x86_64-linux-musl:openssl-libs-static # 3.5.9-r0
fetch:x86_64-linux-musl:pcre2-static # 10.49-r0
fetch:x86_64-linux-musl:sqlite-static # 3.53.4-r0
fetch:x86_64-linux-musl:xz-static # 5.8.4-r0
fetch:x86_64-linux-musl:yaml-static # 0.2.5-r2
fetch:x86_64-linux-musl:zlib-static # 1.3.2-r0
fetch:x86_64-sonoma
fetch:x86_64-sonoma:bdw-gc # 8.2.12
fetch:x86_64-sonoma:gmp # 6.3.0
fetch:x86_64-sonoma:libiconv # 1.19
fetch:x86_64-sonoma:libxml2 # 2.15.3
fetch:x86_64-sonoma:libyaml # 0.2.5
fetch:x86_64-sonoma:openssl@3 # 3.6.3
fetch:x86_64-sonoma:pcre2 # 10.47_1
fetch:x86_64-sonoma:sqlite # 3.53.4
fetch:x86_64-sonoma:zlib # 1.3.2
gmp:build:aarch64-linux-musl # 6.3.0
gmp:build:x86_64-linux-musl # 6.3.0
gmp:rebuild:aarch64-linux-musl # 6.3.0
gmp:rebuild:x86_64-linux-musl # 6.3.0
clean # Remove prebuilt_libs and tmp; keep downloads and pkg
clobber # Remove prebuilt_libs, tmp, downloads, and pkg
clobber_package # Remove pkg and its cache marker
package # Run all, then create the pkg archive if needed
repackage # Run all, then recreate the pkg archive
```

Above also print the supported libraries and version, feel free to open an issue
if you need support for other third-party libraries.


### Why build GMP from source

We build GMP from source for both Alpine targets (aarch64-linux-musl and x86_64-linux-musl) to avoid the undefined-symbol errors encountered when linking Alpine’s prebuilt GMP 6.3.0 archive with  zig cc.

The build uses `zig cc with -O3  -fno-lto` to produce a compatible static libgmp.a. 

bin/tasks all handles this automatically and reuses cached builds when the version and build inputs remain unchanged. 

For macOS, we use the prebuilt Homebrew bottles.

I also upload the libraries as assets on the [releases page](https://github.com/crystal-china/crystal_build_scripts/releases).
You can skip run tasks if you download the `libs-{version}.tar.xz` from the GitHub releases page instead.
then run `tar -xJf libs-0.6.1.tar.xz` from the repository root.

```
 ╰──➤ $ cd build_scripts/

 ╰──➤ $ tree -L1 prebuilt_libs/
prebuilt_libs/
├── aarch64-linux-musl
├── aarch64-sonoma
├── x86_64-linux-musl
└── x86_64-sonoma

5 directories, 0 files
```

3. Add `PROJECT_ROOT/bin` to your `$PATH`. You can then use `sb` or `cb` to cross-compile a Crystal program.

4. build an AMD64/ARM64 static binary, with no debug info, strip symbols, and use release mode.

```sh
$: sb --target=amd64 --no-debug --link-flags=-s --release
$: sb --target=arm64 --no-debug --link-flags=-s --release
```

> **Alpine static builds:** Do **not** pass Crystal's `--static` for either `x86_64-linux-musl` or `aarch64-linux-musl`. In this workflow, `zig cc` already links a static musl binary. `--static` makes Crystal ask the build host's `pkg-config` for extra static dependencies, which may not match the Alpine libraries in `prebuilt_libs`.

In fact, You can use `sb` in place of `shards build` when do cross compile directly
it takes care of using `zig cc` when cross-compiling.

To build a `.cr` file directly, use `cb` instead of `crystal build` instead. 

It uses the same setup as `sb`:

```sh
$: cb --target=arm64 hello.cr -o bin/hello
```

----------------

The following examples show how I cross-compile binaries for `x86_64-linux-musl`, `aarch64-linux-musl`, `x86_64-darwin`, and `aarch64-darwin` on my Linux host.

```sh
 ╰──➤ $ sb --cross-compile --target=x86_64-linux-musl
CRYSTAL_WORKERS=
args=   --target=x86_64-linux-musl --cross-compile
I: Dependencies are satisfied
I: Building: tasks
cc /home/zw963/Crystal/crystal-china/build_scripts/bin/tasks.o -o /home/zw963/Crystal/crystal-china/build_scripts/bin/tasks  -rdynamic -fuse-ld=mold -L/home/zw963/Crystal/bin/../lib/crystal -lz `command -v pkg-config > /dev/null && pkg-config --libs --silence-errors libssl || printf %s '-lssl -lcrypto'` `command -v pkg-config > /dev/null && pkg-config --libs --silence-errors libcrypto || printf %s '-lcrypto'` -lyaml -lpcre2-8 -lgc -lpthread -ldl
zig cc -target x86_64-linux-musl /home/zw963/Crystal/crystal-china/build_scripts/bin/tasks.o -o /home/zw963/Crystal/crystal-china/build_scripts/bin/tasks  -rdynamic -fuse-ld=mold -L/home/zw963/Crystal/crystal-china/build_scripts/prebuilt_libs/x86_64-linux-musl -lz `command -v pkg-config > /dev/null && pkg-config --libs --silence-errors libssl || printf %s '-lssl -lcrypto'` `command -v pkg-config > /dev/null && pkg-config --libs --silence-errors libcrypto || printf %s '-lcrypto'` -lyaml -lpcre2-8 -lgc -lpthread -ldl -lunwind

 ╰──➤ $ file bin/tasks
bin/tasks: ELF 64-bit LSB executable, x86-64, version 1 (SYSV), statically linked, with debug_info, not stripped
```

Above command same as `sb --target=amd64`

-------------

Following is several useful commands:

```bash
sb --cross-compile --target=aarch64-linux-musl # sb --target=amd64-mac

sb --cross-compile --target=x86_64-darwin  # sb --target=amd64-mac

sb --cross-compile --target=aarch64-darwin # sb --target=arm64-mac
```

I've been using this workflow for a long time, and it works well for me.
I don't want to add unnecessary complexity to achieve the same result.
I'm comfortable with docker/podman too; I just prefer to use it only when I need it.

### Running a Crystal program that uses XML on macOS

The macOS libxml2 bottle provides a dynamic library. Linking a Crystal program
with `require "xml"` succeeds on Linux, but the resulting macOS executable also
needs that library at runtime; even `--static` does not change this.

For example, from this repository's root, build the [XML example](../examples/mac_xml_hello.cr) for an Apple Silicon Mac:

```shz
bin/cb --target=arm64-mac examples/mac_xml_hello.cr -o mac_xml_hello_arm64
```

Copy `mac_xml_hello_arm64` and `prebuilt_libs/aarch64-sonoma/libxml2.16.dylib` to the same directory on the Mac.
Then run:

```sh
cd folder # Or whichever directory contains both files
DYLD_LIBRARY_PATH="$PWD" ./mac_xml_hello_arm64
```

This prints `macOS XML OK: world` on the tested Apple Silicon Mac.
`DYLD_LIBRARY_PATH` names the directory containing the dylib, not the dylib
itself. The Homebrew bottle's embedded libxml2 path still contains
`@@HOMEBREW_PREFIX@@`; without the environment variable, the copied executable
failed with `Symbol not found: _xmlFree`.

## Updating library versions

In `libs.yml`, pair `alpine_package` with `alpine_version` and `homebrew_formula` with `homebrew_version`. 

Omit the unused pair when a library is needed on only for one platform. 

Downloading is the default: include `url` and `sha256`.

To build GMP, set `action` to its task name, such as `gmp:build:aarch64-linux-musl`
the task uses GMP's top-level `source`.

### Updating libraries for Alpine

1. Open the package directory for the Alpine release you want to use in your browser, and find the latest package filename. For example, the output below uses `gc-static-8.2.12-r0.apk` from https://dl-cdn.alpinelinux.org/alpine/v3.24/main
2. Run `./scripts/alpine_sha256_gen gc-static-8.2.12-r0.apk` in your terminal. The output will look like this:

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

3. Before running `alpine_sha256_gen`, make sure the Alpine version in the script
   matches the release you want to use. 

### Updating libraries for Darwin (macOS)

1. Visit https://github.com/Homebrew/homebrew-core/tree/master/Formula.
2. Press `t` and search for the package name. Homebrew names may differ from
   Alpine names: for example, `gc-static` uses `bdw-gc.rb`. Check `homebrew_formula`
   in `libs.yml` for the correct formula name.
3. Check the `bottle do` block. Select the oldest macOS release supported by
   both x86_64 and aarch64 across all selected libraries. Currently, we use Sonoma
   (`arm64_sonoma` for aarch64 and `sonoma` for x86_64). If the current formula
   has no Intel macOS bottle, use the most recent formula revision that provides both
   architectures; the pinned formula links are recorded in `libs.yml`.
4. Update the GHCR blob URL and `sha256`, and set `homebrew_version` to the
   bottle's package version, including any Homebrew revision suffix (e.g. `10.47_1`).
   Keep the `alpine_version` separate when present. If the selected macOS
   release changes, update the platform names in `libs.yml` and the library
   directory mappings in `bin/sb`.

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
