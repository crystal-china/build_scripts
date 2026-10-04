require "spec"
require "http/server"
require "file_utils"

SPEC_ROOT = File.join(Dir.tempdir, "haversack-tasks-spec-#{Process.pid}")
ENV["HAVERSACK_ROOT"] = SPEC_ROOT
require "../src/haversack_tasks"

describe HaversackTasks do
  before_each { FileUtils.mkdir_p(SPEC_ROOT) }
  after_each { FileUtils.rm_rf(SPEC_ROOT) }

  it "creates writable library files from a read-only archive and can fetch again" do
    input = File.join(SPEC_ROOT, "input", "usr", "lib")
    FileUtils.mkdir_p(input)
    File.write(File.join(input, "libtest.a"), "library")
    File.chmod(File.join(input, "libtest.a"), 0o444)
    File.write(File.join(input, "libsecond.a"), "second library")

    archive = File.join(SPEC_ROOT, "downloads", "x86_64-sonoma", "archives", "bottle.tar.gz")
    FileUtils.mkdir_p(File.dirname(archive))
    Process.run("tar", ["-czf", archive, "-C", File.join(SPEC_ROOT, "input"), "usr"]).success?.should be_true
    source = HaversackTasks::Source.new("http://example.test/bottle.tar.gz", HaversackTasks.digest(archive))
    library = HaversackTasks::Library.new("test", "1", ["libtest.a"], {"x86_64-sonoma" => HaversackTasks::Binary.new("fetch", source)})

    HaversackTasks.fetch(library, "x86_64-sonoma")
    output = File.join(SPEC_ROOT, "prebuilt_libs", "x86_64-sonoma", "libtest.a")
    File.info(output).permissions.owner_write?.should be_true
    HaversackTasks.fetch(library, "x86_64-sonoma")
    File.info(output).permissions.owner_write?.should be_true
    expanded = HaversackTasks::Library.new("test", "1", ["libtest.a", "libsecond.a"], {"x86_64-sonoma" => HaversackTasks::Binary.new("fetch", source)})
    HaversackTasks.fetch(expanded, "x86_64-sonoma")
    File.read(File.join(SPEC_ROOT, "prebuilt_libs", "x86_64-sonoma", "libsecond.a")).should eq("second library")
  end

  it "retries transient HTTP failures, verifies cached files, and replaces a damaged cache" do
    requests = 0
    payload = "verified archive content"
    server = HTTP::Server.new do |context|
      requests += 1
      if requests <= 2
        context.response.status_code = 503
      else
        context.response.print(payload)
      end
    end
    address = server.bind_tcp("127.0.0.1", 0)
    spawn { server.listen }
    begin
      destination = File.join(SPEC_ROOT, "cached.tar.gz")
      source = HaversackTasks::Source.new("http://127.0.0.1:#{address.port}/file", Digest::SHA256.hexdigest(payload))
      HaversackTasks.download(source, destination)
      File.read(destination).should eq(payload)
      requests.should eq(3)

      HaversackTasks.download(source, destination)
      requests.should eq(3)

      File.write(destination, "damaged")
      HaversackTasks.download(source, destination)
      File.read(destination).should eq(payload)
      requests.should eq(4)
      Dir.glob("#{destination}.part.*").should be_empty
    ensure
      server.close
    end
  end

  it "fails fast on a permanent HTTP error without keeping a partial file" do
    requests = 0
    server = HTTP::Server.new do |context|
      requests += 1
      context.response.status_code = 404
    end
    address = server.bind_tcp("127.0.0.1", 0)
    spawn { server.listen }
    begin
      destination = File.join(SPEC_ROOT, "missing.tar.gz")
      source = HaversackTasks::Source.new("http://127.0.0.1:#{address.port}/missing", "0" * 64)
      expect_raises(Exception, /Unable to download/) { HaversackTasks.download(source, destination) }
      requests.should eq(1)
      File.exists?(destination).should be_false
      Dir.glob("#{destination}.part.*").should be_empty
    ensure
      server.close
    end
  end

  it "retries a checksum mismatch and honors a numeric Retry-After" do
    requests = 0
    payload = "correct bytes"
    server = HTTP::Server.new do |context|
      requests += 1
      case requests
      when 1
        context.response.status_code = 429
        context.response.headers["Retry-After"] = "0"
      when 2
        context.response.print("wrong bytes")
      else
        context.response.print(payload)
      end
    end
    address = server.bind_tcp("127.0.0.1", 0)
    spawn { server.listen }
    begin
      destination = File.join(SPEC_ROOT, "retry.tar.gz")
      source = HaversackTasks::Source.new("http://127.0.0.1:#{address.port}/retry", Digest::SHA256.hexdigest(payload))
      HaversackTasks.download(source, destination)
      requests.should eq(3)
      File.read(destination).should eq(payload)
    ensure
      server.close
    end
  end

  it "packages libraries under the renamed directory and keeps Shards dependencies during clean" do
    library = File.join(SPEC_ROOT, "prebuilt_libs", "x86_64-linux-musl", "libtest.a")
    FileUtils.mkdir_p(File.dirname(library))
    File.write(library, "test library")
    shard = File.join(SPEC_ROOT, "lib", "croupier", "shard.yml")
    FileUtils.mkdir_p(File.dirname(shard))
    File.write(shard, "name: croupier")

    library_config = HaversackTasks::Library.new("test", "1", ["libtest.a"], {"x86_64-linux-musl" => HaversackTasks::Binary.new("fetch", nil)})
    HaversackTasks.package(["x86_64-linux-musl"], [library_config])
    archive = File.join(SPEC_ROOT, "pkg", "libs-0.6.1.tar.xz")
    listing = IO::Memory.new
    status = Process.run("tar", ["-tf", archive], output: listing)
    status.success?.should be_true
    listing.to_s.should contain("libs-0.6.1/prebuilt_libs/x86_64-linux-musl/libtest.a")

    File.write(archive, "damaged package")
    HaversackTasks.package(["x86_64-linux-musl"], [library_config])
    Process.run("tar", ["-tf", archive], output: Process::Redirect::Close).success?.should be_true

    HaversackTasks.package(["x86_64-linux-musl"], [library_config], force: true)
    Process.run("tar", ["-tf", archive], output: Process::Redirect::Close).success?.should be_true

    HaversackTasks.clobber_package
    File.exists?(archive).should be_false
    File.exists?(library).should be_true

    HaversackTasks.clean
    File.exists?(library).should be_false
    File.exists?(shard).should be_true
  end

  it "reads build and noop actions from libs.yml without placeholder downloads" do
    File.write(File.join(SPEC_ROOT, "libs.yml"), <<-YAML)
    - name: gmp
      version: "6.3.0"
      source:
        url: https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz
        sha256: #{"a" * 64}
      files: [libgmp.a]
      binaries:
        - platform: x86_64-linux-musl
          action: build
    - name: iconv
      version: "1.19"
      files: [libiconv.a]
      binaries:
        - platform: x86_64-linux-musl
          action: noop
    YAML
    libraries = HaversackTasks.read_libraries
    libraries.first.version.should eq("6.3.0")
    libraries.first.source.not_nil!.sha256.should eq("a" * 64)
    libraries.first.binaries["x86_64-linux-musl"].action.should eq("build")
    libraries.last.binaries["x86_64-linux-musl"].action.should eq("noop")
    libraries.last.binaries["x86_64-linux-musl"].source.should be_nil
  end

  it "restores a checked GMP build from downloads after clean and ignores a different version" do
    platform = "x86_64-linux-musl"
    source = HaversackTasks::Source.new("https://example.test/gmp-6.3.0.tar.xz", "a" * 64)
    binary = HaversackTasks::Binary.new("build", nil)
    library = HaversackTasks::Library.new("gmp", "6.3.0", ["libgmp.a"], {platform => binary}, source)
    cache = File.join(SPEC_ROOT, "downloads", "built", platform, "gmp-6.3.0")
    FileUtils.mkdir_p(cache)
    cached_library = File.join(cache, "libgmp.a")
    cached_pc = File.join(cache, "gmp.pc")
    File.write(cached_library, "built library")
    File.write(cached_pc, "version=6.3.0")
    File.write(File.join(cache, "manifest.yml"), {
      "signature"        => HaversackTasks.gmp_cache_signature(library, platform),
      "library_sha256"   => HaversackTasks.digest(cached_library),
      "pkgconfig_sha256" => HaversackTasks.digest(cached_pc),
    }.to_yaml)

    HaversackTasks.build_gmp(library, platform)
    output = File.join(SPEC_ROOT, "prebuilt_libs", platform, "libgmp.a")
    File.read(output).should eq("built library")
    HaversackTasks.clean
    HaversackTasks.build_gmp(library, platform)
    File.read(output).should eq("built library")
    changed = HaversackTasks::Library.new("gmp", "6.3.1", ["libgmp.a"], {platform => binary}, source)
    HaversackTasks.gmp_cache_signature(changed, platform).should_not eq(HaversackTasks.gmp_cache_signature(library, platform))
  end

  it "excludes files for noop platforms from the package" do
    platform = "x86_64-linux-musl"
    output = File.join(SPEC_ROOT, "prebuilt_libs", platform)
    FileUtils.mkdir_p(output)
    File.write(File.join(output, "libtest.a"), "wanted")
    File.write(File.join(output, "libiconv.a"), "stale")
    fetch = HaversackTasks::Binary.new("fetch", nil)
    noop = HaversackTasks::Binary.new("noop", nil)
    libraries = [
      HaversackTasks::Library.new("test", "1", ["libtest.a"], {platform => fetch}),
      HaversackTasks::Library.new("iconv", "1", ["libiconv.a"], {platform => noop}),
    ]
    HaversackTasks.package([platform], libraries)
    listing = IO::Memory.new
    Process.run("tar", ["-tf", File.join(SPEC_ROOT, "pkg", "libs-0.6.1.tar.xz")], output: listing).success?.should be_true
    listing.to_s.should contain("libtest.a")
    listing.to_s.should_not contain("libiconv.a")
  end
end
