# frozen_string_literal: true

require "digest/sha1"
require "etc"
require "mini_portile2"
require "fileutils"
require "rake/clean"
require "rake/packagetask"
require "yaml"

# extend MiniPortile for local compilation
require_relative "scripts/custom_portile"

HAVERSACK_VERSION = "0.6.1"
GMP_NON_LTO_VERSION = "6.3.0"
GMP_NON_LTO_SOURCE = "https://ftp.gnu.org/gnu/gmp/gmp-#{GMP_NON_LTO_VERSION}.tar.xz"

directory "downloads"
directory "lib"
directory "tmp"

CLEAN.push("lib", "tmp")
CLOBBER.push("downloads", "pkg")

# load libs.yml
libs = YAML.safe_load_file("libs.yml")

# build list of platforms from `libs`
SUPPORTED_PLATFORMS = Set.new
libs.each do |lib|
  lib["binaries"].each do |binary|
    SUPPORTED_PLATFORMS << binary["platform"]
  end
end

# define tasks for download of each platform
libs.each do |lib|
  binaries = lib["binaries"]

  SUPPORTED_PLATFORMS.each do |platform|
    port = CustomPortile.new(lib["name"], lib["version"])
    port.host = platform

    downloads_dir = "downloads/#{platform}"
    lib_dir = "lib/#{platform}"
    pkg_dir = File.join(lib_dir, "pkgconfig")

    directory downloads_dir
    directory pkg_dir

    if (found = binaries.find { |b| b["platform"] == platform })
      # save path before changing target
      tmp_port_path = File.join("tmp", port.port_path)
      port.target = downloads_dir

      task "fetch:#{platform}:#{lib["name"]}" => ["tmp", downloads_dir, pkg_dir] do
        # determine single or multiple files present
        if found["url"]
          port.files << {
            url: found["url"],
            sha256: found["sha256"],
          }
        end

        urls = found["urls"]
        if urls && !urls.empty?
          urls.each do |entry|
            port.files << {
              url: entry["url"],
              sha256: entry["sha256"],
            }
          end
        end

        checkpoint_download = "tmp/.#{port.host}-#{port.name}-#{port.version}.download"

        unless File.exist?(checkpoint_download)
          port.download unless port.downloaded?
          mkdir_p tmp_port_path

          port.files.each do |file|
            file_path = File.expand_path(File.basename(file[:url]), port.archives_path)
            sh "tar -tf #{file_path} 2>#{IO::NULL} | grep -E '#{lib["files"].join("|")}' | xargs -I '{}' tar -xf #{file_path} -C #{tmp_port_path} --no-anchored '{}' 2>#{IO::NULL}"
          end

          FileUtils.touch(checkpoint_download)
        end

        # collect SHA1 of all `.a` and `.pc` extracted files
        files_digest = Digest::SHA1.new
        port_files = Dir.glob("#{tmp_port_path}/**/*.{a,pc,dylib}")
        port_files.each do |file|
          files_digest.update File.binread(file)
        end

        checkpoint_extract = "tmp/.#{port.host}-#{port.name}-#{port.version}-#{files_digest.hexdigest}.extract"

        unless File.exist?(checkpoint_extract)
          port_files.each do |file|
            path = File.extname(file) == ".pc" ? pkg_dir : lib_dir
            target_file = File.join(path, File.basename(file))

            if File.exist?(target_file) && !FileUtils.compare_file(file, target_file)
              rm target_file, force: true
            end

            cp file, target_file
          end

          FileUtils.touch(checkpoint_extract)
        end
      end
    end

    desc "Fetch all for '#{platform}'"
    task "fetch:#{platform}" => ["fetch:#{platform}:#{port.name}"]

    desc "Fetch all"
    task "fetch:all" => ["fetch:#{platform}"]
  end
end

Rake::PackageTask.new("magic-haversack", HAVERSACK_VERSION) do |t|
  t.need_tar_xz = true

  globs = SUPPORTED_PLATFORMS.map { |platform| "lib/#{platform}/**/*.{a,pc,dylib}" }
  t.package_files.include(globs)
end

task "package" => ["fetch:all"]

# 下面是 codex 发现 6.3.0 无法在 alpine 下使用的原因, 因此使用自己编译的 gmp 6.3.0

# • 现在关键事实已经出来了：gmp 6.3.0-r3 的 archive 成员不是普通 ELF 对象，而是 GCC LTO slim objects。llvm-
#   nm 直接只看到 __gnu_lto_slim。这基本解释了为什么 Alpine 原生工具链能过，而 Zig/LLD 这条路不行。为了把结
#   论钉死，我再和你现有的 6.2.1-r3 库做一次正面对比。

# • Explored
#   └ List objs

# • Ran mkdir -p /tmp/gmp-6.2-test && cd /tmp/gmp-6.2-test && llvm-ar x /home/zw963/Crystal/crystal-china/
#   │ build_scripts/lib/x86_64-linux-musl/libgmp.a mp_set_fns.o memory.o && file mp_set_fns.o memory.o &&
#   │ llvm-nm mp_set_fns.o memory.o | sed -n '1,120p'
#   └ mp_set_fns.o: ELF 64-bit LSB relocatable, x86-64, version 1 (SYSV), not stripped
#     memory.o:     ELF 64-bit LSB relocatable, x86-64, version 1 (SYSV), not stripped
#     … +25 lines
#                      U realloc
#                      U stderr

# • Ran ZIG_GLOBAL_CACHE_DIR=/tmp/zig-cache zig cc -target x86_64-linux-musl /tmp/gmp-6.3-test/min.c /home/
#   │ zw963/Crystal/crystal-china/build_scripts/lib/x86_64-linux-musl/libgmp.a -o /tmp/gmp-6.2-test/
#   │ min-zig-621
#   └ (no output)

# ─────────────────────────────────────────────────────────────────────────────────────────────────────────

# • 结论已经比较清楚了：问题不是 sb 的替换逻辑，也不是 __gmp_set_memory_functions 真的从 GMP 6.3 里消失了，
#   而是 Alpine 3.22 的 gmp-static-6.3.0-r3.apk 里那份 /tmp/gmp-6.3-test/x86_64/unpack/gmp-static/usr/lib/
#   libgmp.a 是用 GCC LTO 产出的 slim objects，zig cc/ld.lld 没有把这类 archive 成员当成可直接链接的普通对
#   象来处理。

#   我本地做了几组最小实验，结果是：

#   - 6.3.0-r3 的 libgmp.a 里，__gmp_set_memory_functions 确实存在，nm 能看到它在 mp_set_fns.o 里。
#   - 但把 mp_set_fns.o 和 memory.o 从 6.3 的 archive 里拆出来后，llvm-nm 只看到 __gnu_lto_slim，说明它们本
#     质上是 LTO slim objects，不是普通目标文件。
#   - 用最小 C 程序直接链接 6.3 的 libgmp.a，zig cc -target x86_64-linux-musl ... libgmp.a 也会稳定报你同样
#     的错：ld.lld: error: undefined symbol: __gmp_set_memory_functions。
#   - 同一个最小程序，链接你现在仓库里的 6.2.1 版本 lib/x86_64-linux-musl/libgmp.a 可以直接成功。
#   - 系统 cc 去链接 6.3 的静态库时，也会报 LTO 版本相关错误：generated with LTO version 14.0 instead of
#     the expected 15.1。这进一步说明 6.3 的静态库格式/构建方式才是关键差异。

#   所以现在可以把根因概括成一句话：

#   - Alpine gmp-static-6.3.0-r3 的 libgmp.a 是 GCC LTO slim archive。
#   - podman/alpine 里用原生工具链时，这类库能被正确处理。
#   - 你这条本机 zig cc cross-link 路线下，lld 对这份 archive 处理失败，于是出现 __gmp_set_memory_functions
#     unresolved。

#   这也解释了为什么：

#   - 6.2.1-r3 没事，因为它的 archive 成员是普通 ELF relocatable objects。
#   - 6.3.0-r3 只在 zig 这条链路上炸，podman 不炸。

#   接下来可行的方案基本只有三类：

#   1. 继续固定 Alpine GMP 在 6.2.1-r3。
#   2. 仍然用 GMP 6.3，但不要直接使用 Alpine 那个 gmp-static-6.3.0-r3.apk 里的静态库，而是自己构建一份“非
#      LTO 的 libgmp.a”。
#   3. 单独给 GMP 走 podman/原生 linker，这会把你现在这条干净的本机 cross-link 流程搞复杂，一般不值得。

#   如果你愿意，我下一步可以直接帮你做其中一个：

#   - 改 libs.yml 和文档，把这个限制写死并说明原因。
#   - 或者写一个小 task，专门产出一份适合 zig cc 的 GMP 6.3 非 LTO 静态库。
def build_non_lto_gmp(platform, zig_target)
  source_archive = File.join("tmp", "gmp-#{GMP_NON_LTO_VERSION}.tar.xz")
  source_dir = File.join("tmp", "gmp-#{GMP_NON_LTO_VERSION}")
  build_dir = File.join("tmp", "gmp-build-#{platform}")
  zig_cache_dir = File.expand_path(File.join("tmp", "zig-cache"))
  lib_dir = File.join("lib", platform)
  pkg_dir = File.join(lib_dir, "pkgconfig")

  mkdir_p zig_cache_dir

  unless File.exist?(source_archive)
    sh "curl -fL #{GMP_NON_LTO_SOURCE} -o #{source_archive}"
  end

  unless Dir.exist?(source_dir)
    sh "tar -xf #{source_archive} -C tmp"
  end

  rm_rf build_dir
  mkdir_p build_dir

  configure = [
    "cd #{build_dir}",
    "&&",
    "ZIG_GLOBAL_CACHE_DIR=#{zig_cache_dir}",
    "CC='zig cc -target #{zig_target}'",
    "CC_FOR_BUILD='cc'",
    "CFLAGS='-O3'",
    "AR='llvm-ar'",
    "RANLIB='llvm-ranlib'",
    "#{File.expand_path("configure", source_dir)}",
    "--host=#{zig_target}",
    "--build=x86_64-pc-linux-gnu",
    "--disable-shared",
    "--enable-static",
    "--disable-cxx",
    "--with-pic",
  ].join(" ")

  sh configure
  sh "cd #{build_dir} && ZIG_GLOBAL_CACHE_DIR=#{zig_cache_dir} make -j#{Etc.nprocessors}"
  sh "strip -g #{File.join(build_dir, ".libs", "libgmp.a")}"

  cp File.join(build_dir, ".libs", "libgmp.a"), File.join(lib_dir, "libgmp.a")
  cp File.join(build_dir, "gmp.pc"), File.join(pkg_dir, "gmp.pc")
end

namespace "gmp" do
  namespace "build" do
    desc "Build a non-LTO GMP #{GMP_NON_LTO_VERSION} static library for x86_64-linux-musl"
    task "x86_64-linux-musl" => ["tmp", "lib", "lib/x86_64-linux-musl/pkgconfig"] do
      build_non_lto_gmp("x86_64-linux-musl", "x86_64-linux-musl")
    end

    desc "Build a non-LTO GMP #{GMP_NON_LTO_VERSION} static library for aarch64-linux-musl"
    task "aarch64-linux-musl" => ["tmp", "lib", "lib/aarch64-linux-musl/pkgconfig"] do
      build_non_lto_gmp("aarch64-linux-musl", "aarch64-linux-musl")
    end
  end
end
