# Podman Build Scripts

Build statically linked Linux binaries with [Podman](https://github.com/containers/podman), without installing Crystal or a cross-compilation toolchain on the host. 

The Crystal scripts support AMD64 and ARM64; the resulting binaries can also be packaged into minimal scratch images.

Run these commands from the project root. The build scripts mount the current directory at /app, so compiled files are written directly into your project.

## Requirements

- Linux, Bash, and [Podman](https://podman.io/docs/installation).
- Cross-architecture builds require QEMU user-mode emulation and binfmt support. 
  For example, on Arch Linux:

  ```sh
  sudo pacman -S --needed qemu-user-static qemu-user-static-binfmt
  sudo systemctl restart systemd-binfmt.service
  ```

  Verify that ARM64 emulation works:

  ```sh
  podman run --rm --platform linux/arm64 alpine uname -m
  # aarch64
  ```
- `readelf` (from `binutils`) is required for image packaging.

## Build Crystal binaries

The following examples use [Crystal China](https://github.com/crystal-china/website). Ensure the scripts in `bin/` are available on your `PATH`.

### Build a Shards project

```sh
cd website

# Build the targets defined in shard.yml (AMD64).
crystal_build_amd64_binary

# Build the same targets for ARM64, with --release
crystal_build_arm64_binary --release

# Build only a named target.
SHARDS_TARGET=crystal_china crystal_build_arm64_binary --release
```

Shards outputs binaries under `bin/` (for example, `bin/crystal_china`). If `SHARDS_TARGET` is unset, all targets in `shard.yml` are built.

The ARM64 build runs Crystal's cross-compiler natively on the host architecture, then uses an ARM64 container for linking. On an AMD64 host, QEMU is only needed for the linking stage, not for compilation.

### Build a single Crystal file

Pass a `.cr` file as the first argument to use `crystal build` instead of `shards build`:

```sh
# Default Crystal output: ./tasks
crystal_build_arm64_binary ./tasks.cr

# Specify the output path and enable release optimizations.
crystal_build_arm64_binary ./tasks.cr -o bin/tasks --release

# The same interface is available for AMD64.
crystal_build_amd64_binary ./tasks.cr -o bin/tasks --release
```

Additional compiler options, such as `--release`, `--no-debug`, and `-o`, are passed through to the Crystal compiler.

If the project has a `shard.yml`, its dependencies are installed before compilation, otherwise, dependency installation is skipped. 

### Cache controls

| Option | Behavior |
| --- | --- |
| *(none)* | Re-run Crystal compilation on every invocation while reusing unchanged environment and dependency-installation layers. |
| `-f` | Also re-run `shards install` when the project has a `shard.yml`. |
| `-ff` | Disable image-layer cache, pull base images, and rebuild every Dockerfile stage. ARM64 builds also print the full Crystal compilation log. |

### Per-project build configuration

To customize the default compiler and linker flags for a project, copy the [sample configuration](../build_flags.conf.sample) into that project's root directory:

```sh
cp /path/to/build_scripts/build_flags.conf.sample ./build_flags.conf
```

For example:

```ini
flags=--release --stats --time
compile_time_flags=-Dstrict_multi_assign -Dno_number_autocast -Duse_pcre2 -Dpreview_overload_order
link_flags=--link-flags=-Wl,-L/app --link-flags=-s --link-flags=-no-pie
```

Both Crystal build scripts load a nonempty `./build_flags.conf` automatically and print a warning when they do. This file is **project-specific**, not a global configuration; consider adding `/build_flags.conf` to the project's `.gitignore`.

## Package a static binary into an image

`crystal_package_image` packages an existing, fully static AMD64 or ARM64 ELF binary in a `scratch` image:

```sh
# Build and package the Crystal China web application for ARM64.
crystal_build_arm64_binary --release
crystal_package_image bin/crystal_china localhost/crystal-china:latest

# Inspect the result.
podman image inspect localhost/crystal-china:latest
```

The script automatically detects whether the binary is AMD64 or ARM64 and builds the image for the correct architecture, rejects dynamically linked binaries, and includes CA certificates and timezone data (`tzdata`). 

The final `scratch` image contains no shell or package manager and runs `/app/binary` as its entrypoint.

To copy the image to a Raspberry Pi using an existing SSH alias:

```sh
podman save localhost/crystal-china:latest | ssh pi 'podman load'
```

### Example: deploy database migration tasks separately

```sh
crystal_build_arm64_binary ./tasks.cr -o bin/tasks --release
rsync -av bin/tasks pi:apps/crystal_china_production/bin/
ssh pi 'cd ~/apps/crystal_china_production && bin/tasks db.migrate'
```

## Breaking changes

- **No implicit `--release`**: pass `--release` explicitly or enable it in the project's `build_flags.conf`.
- **Build configuration is per project**: `build_flags.conf` is now read from the project working directory.

## Cross-compiling static C/C++ binaries

The `build_binary` script can build general C/C++ projects using Podman, provided the project and its dependencies support the target architecture.

By default, it runs `make CC=gcc LDFLAGS='-static -Wl,-s'`.

```sh
# Build for AMD64 (default).
build_binary

# Build for ARM64.
PLATFORM=linux/arm64/v8 build_binary
```

You can override the default build command by passing your own:

```sh
PLATFORM=linux/arm64/v8 build_binary make CC=gcc
```

The script currently supports these platforms:

- `linux/arm64/v8`
- `linux/arm/v7`
- `linux/arm/v6`
- `linux/amd64`
- `linux/386`

To see which platforms an image supports:

```sh
podman run --rm mplatform/mquery alpine:latest
```

## Cross-compiling static Rust binaries

The `build_rust_binary` script uses `cargo-zigbuild` and Zig to build statically linked Rust binaries.

```sh
# Build for AMD64 (default).
build_rust_binary

# Build for ARM64.
PLATFORM=linux/arm64/v8 build_rust_binary
```

The script currently supports AMD64 and ARM64. It runs `cargo zigbuild --release` by default, targeting the corresponding musl platform.

Use `-f` to rebuild the toolchain image, or `-ff` to rebuild it without using image-layer cache.

Without these options, an existing toolchain image is reused.

As with `build_binary`, you can run any command available inside the build container instead of the default.

The above two are separate helpers; the Crystal-specific options described above do not necessarily apply to them.

## Why use podman instead of docker?

Podman is largely compatible with Docker, so these scripts might work with Docker too, though I haven't tested them.

Personally, I see little reason to stick with Docker. Switching to Podman was easy, and it comes with some nice advantages:

1. Daemonless — No more running a dockerd daemon in the background.

2. More than Docker — A familiar Docker-compatible CLI, Buildx compatibility, Compose support, and built-in pod management.

3. Lightweight — In my experience, Podman feels faster and less resource-hungry.

4. Rootless by design — Better support for running containers without root, with fewer permission headaches. I no longer need tools like `fixuid` for my workflow.
