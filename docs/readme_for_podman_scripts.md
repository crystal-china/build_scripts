# Dependencies

You'll need to run this using [Podman](https://github.com/containers/podman). Check out the [installation instructions](instli)
for how to set it up.

Podman works pretty much the same way as Docker, so using Docker might work instead, 
but I can't guarantee it.

Honestly, I can't see why anyone would still use Docker! 

You can switch to Podman easily and painlessly without any issues, plus you get 
these awesome benefits:

1. No need to start a dockerd daemon anymore.
2. podman = docker + docker-compose + docker buildx + pod manager
3. It's (way) faster than Docker.
4. Say goodbye to fixuid!

# How to build a Crystal binary

## For a Crystal AMD64 static binary

```sh
# For a project managed by shards
$: crystal_build_amd64_binary # The built binary will land in the `bin/` folder.

# Build one file
$: crystal_build_amd64_binary foo.cr # The built binary will land in the current folder.
```

## For a Crystal ARM64 static binary

```sh
# For a project managed by shards
$: crystal_build_arm64_binary

# Build one file
$: crystal_build_arm64_binary foo.cr
```

## Passing build flags

You can find all the default build arguments in the sample file: [build_flags.conf.sample](/bin/build_flags.conf.sample).

```conf
compile_time_flags=-Dstrict_multi_assign -Dno_number_autocast -Duse_pcre2 -Dpreview_overload_order

# Don't add --progress; it doesn't work well with this script!
flags=--release --no-debug --stats --time

link_flags=--link-flags=-Wl,-L/app --link-flags=-s --link-flags=-pie
```

Just rename that file to `build_flags.conf`, set your arguments there, and both scripts
will automatically pick them up.

Passing the `-f` option invalidates the cache and makes the script rerun `shards install` to fetch all your dependencies again.
Passing the `-ff` option forces `--pull=always --no-cache`, so the script always pulls the latest image and rebuilds from scratch.

## Cross-compiling static binaries for general C programs (using make) and Rust (using cargo)

You can also use this for general C programs, assuming the toolchains support it.

```sh
# To build an AMD64 binary (this is the default)
$: build_binary

# To build an ARM64 binary:
$: PLATFORM=linux/arm64/v8 build_binary
```

By default, the script runs the command: `make CC=gcc LDFLAGS='-static -Wl,-s'`.

You can easily override this default command by just passing your preferred command
directly, like this:

```sh
$: cd a_rust_project
$: PLATFORM=linux/arm64/v8 build_binary cargo build --release
```

The currently supported platforms are:

"linux/arm64/v8" "linux/arm/v7" "linux/arm/v6" "linux/amd64" "linux/386"

You can run the command below to get additional platform information:

```sh
$ podman run --rm mplatform/mquery alpine:latest
```

## The build_rust_binary script builds Rust programs using only zig cc

Usage:

	$: build_rust_binary

Or:

	$: PLATFORM=linux/arm64/v8 build_rust_binary

