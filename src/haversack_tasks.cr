require "croupier"
require "digest/sha256"
require "file_utils"
require "http/client"
require "uri"
require "yaml"

module HaversackTasks
  ROOT              = ENV["HAVERSACK_ROOT"]? || File.expand_path("..", __DIR__)
  VERSION           = "0.6.1"
  GMP_SOURCE_MIRROR = "https://ftp.gnu.org/gnu/gmp/"
  GMP_SOURCE_BACKUP = "https://gmplib.org/download/gmp/"
  ALPINE_MIRROR     = "https://mirrors.tuna.tsinghua.edu.cn/alpine/"
  ALPINE_OFFICIAL   = "https://dl-cdn.alpinelinux.org/alpine/"
  RETRIES           = 6

  record Source, url : String, sha256 : String
  record Binary, action : String, source : Source?
  record Library, name : String, version : String, files : Array(String), binaries : Hash(String, Binary), source : Source? = nil

  class DownloadFailure < Exception
    getter retryable : Bool
    getter retry_after : String?

    def initialize(message : String, @retryable : Bool = false, @retry_after : String? = nil)
      super(message)
    end
  end

  def self.path(*parts : String) : String
    File.join(ROOT, *parts)
  end

  def self.read_libraries : Array(Library)
    YAML.parse(File.read(path("libs.yml"))).as_a.map do |entry|
      row = entry.as_h
      name = row["name"].as_s
      version = row["version"].as_s
      files = row["files"].as_a.map(&.as_s)
      source = if source_row = row["source"]?
                 source_data = source_row.as_h
                 Source.new(source_data["url"].as_s, source_data["sha256"].as_s)
               end
      binaries = {} of String => Binary
      row["binaries"].as_a.each do |item|
        binary = item.as_h
        platform = binary["platform"].as_s
        action = binary["action"].as_s
        binary_source = nil.as(Source?)
        case action
        when "fetch"
          binary_source = Source.new(binary["url"].as_s, binary["sha256"].as_s)
        when "build"
          raise "#{name} for #{platform}: only Linux GMP supports build" unless name == "gmp" && platform.ends_with?("-linux-musl") && source
        when "noop"
        else
          raise "#{name} for #{platform}: unknown action #{action}"
        end
        raise "#{name} for #{platform}: #{action} cannot have a URL" if action != "fetch" && (binary.has_key?("url") || binary.has_key?("sha256"))
        binaries[platform] = Binary.new(action, binary_source)
      end
      Library.new(name, version, files, binaries, source)
    end
  end

  def self.digest(path : String) : String
    File.open(path) { |file| Digest::SHA256.hexdigest(file) }
  end

  def self.retry_delay(attempt : Int32, retry_after : String? = nil) : Float64
    if retry_after && (seconds = retry_after.to_f64?)
      return seconds.clamp(0.0, 60.0)
    end
    Math.min(2.0 ** (attempt - 1), 30.0) + Random.rand
  end

  def self.download_once(url : String, temporary : String) : Nil
    current = URI.parse(url)
    6.times do
      raise DownloadFailure.new("Only HTTP(S) download URLs are supported: #{current}") unless {"http", "https"}.includes?(current.scheme)
      headers = HTTP::Headers{"Accept-Encoding" => "identity"}
      headers["Authorization"] = "Bearer QQ==" if current.host == "ghcr.io"
      client = HTTP::Client.new(current)
      client.connect_timeout = 20.seconds
      client.read_timeout = 90.seconds
      begin
        redirect = nil.as(String?)
        client.get(current.request_target, headers) do |response|
          case response.status_code
          when 200
            File.open(temporary, "w") { |file| IO.copy(response.body_io, file) }
          when 301, 302, 303, 307, 308
            redirect = response.headers["Location"]?
            raise DownloadFailure.new("Redirect lacks Location: #{current}") unless redirect
          else
            retryable = {408, 425, 429}.includes?(response.status_code) || response.status_code >= 500
            raise DownloadFailure.new("HTTP #{response.status_code} from #{current}", retryable, response.headers["Retry-After"]?)
          end
        end
        if location = redirect
          current = current.resolve(location)
        else
          return
        end
      ensure
        client.close
      end
    end
    raise DownloadFailure.new("Too many redirects for #{url}")
  end

  def self.download(source : Source, destination : String) : Nil
    expected = source.sha256.downcase
    raise "Invalid SHA256 for #{source.url}" unless expected.matches?(/\A[0-9a-f]{64}\z/)
    if File.file?(destination)
      return if digest(destination) == expected
      STDERR.puts "Invalid cached SHA256: #{destination}; downloading again"
      File.delete(destination)
    end
    FileUtils.mkdir_p(File.dirname(destination))
    endpoints = [source.url]
    if source.url.starts_with?(ALPINE_MIRROR)
      endpoints << source.url.sub(ALPINE_MIRROR, ALPINE_OFFICIAL)
    elsif source.url.starts_with?(GMP_SOURCE_MIRROR)
      endpoints << source.url.sub(GMP_SOURCE_MIRROR, GMP_SOURCE_BACKUP)
    end
    errors = [] of String
    endpoints.each do |url|
      RETRIES.times do |index|
        temporary = "#{destination}.part.#{Process.pid}"
        retry_after = nil.as(String?)
        begin
          STDERR.puts "Downloading #{url} (attempt #{index + 1}/#{RETRIES})"
          download_once(url, temporary)
          actual = digest(temporary)
          raise DownloadFailure.new("SHA256 mismatch for #{url}: expected #{expected}, got #{actual}", true) unless actual == expected
          File.rename(temporary, destination)
          return
        rescue ex : DownloadFailure
          errors << ex.message.to_s
          retry_after = ex.retry_after
          break unless ex.retryable
        rescue ex : IO::Error | Socket::Error | OpenSSL::Error
          errors << "#{ex.class}: #{ex.message}"
        ensure
          File.delete(temporary) if File.exists?(temporary)
        end
        if index < RETRIES - 1
          delay = retry_delay(index + 1, retry_after)
          STDERR.puts "Retrying in #{delay.round(1)}s: #{errors.last}"
          sleep delay.seconds
        end
      end
    end
    raise "Unable to download #{destination}: #{errors.last?}"
  end

  def self.run(command : String, args : Array(String), chdir : String = ROOT, env : Hash(String, String)? = nil) : Nil
    STDERR.puts "#{command} #{args.join(' ')}"
    status = Process.run(command, args, chdir: chdir, env: env, output: STDOUT, error: STDERR)
    raise "#{command} failed (#{status.exit_code})" unless status.success?
  end

  def self.fetch(library : Library, platform : String) : Nil
    source = library.binaries[platform].source || raise "#{library.name} for #{platform}: missing download source"
    archive_dir = path("downloads", platform, "archives")
    basename = File.basename(URI.parse(source.url).path.not_nil!)
    raise "Unsafe archive name: #{basename}" if basename.empty? || basename == "." || basename == ".."
    archive = File.join(archive_dir, basename)
    download(source, archive)

    output_dir = path("prebuilt_libs", platform)
    marker = path("tmp", ".extract-#{platform}-#{library.name}-#{library.version}.yml")
    signature = Digest::SHA256.hexdigest(([source.sha256] + library.files).join("\n"))
    if File.file?(marker)
      begin
        cache = YAML.parse(File.read(marker)).as_h
        if cache["signature"].as_s == signature
          outputs = cache["outputs"].as_h
          if outputs.all? { |file, hash| File.file?(File.join(output_dir, file.as_s)) && digest(File.join(output_dir, file.as_s)) == hash.as_s }
            return
          end
        end
      rescue YAML::ParseException | KeyError | TypeCastError
        # A broken marker must not hide missing or damaged output.
      end
    end

    staging = path("tmp", "extract-#{platform}-#{library.name}-#{Process.pid}")
    FileUtils.rm_rf(staging)
    FileUtils.mkdir_p(staging)
    begin
      run("tar", ["-xf", archive, "-C", staging])
      selected = Dir.glob("#{staging}/**/*").select do |file|
        library.files.includes?(File.basename(file)) && File.file?(file)
      end
      raise "#{library.name} for #{platform}: none of #{library.files.join(", ")} found" if selected.empty?
      FileUtils.mkdir_p(output_dir)
      FileUtils.mkdir_p(File.join(output_dir, "pkgconfig"))
      hashes = {} of String => String
      selected.each do |file|
        basename = File.basename(file)
        relative = basename.ends_with?(".pc") ? File.join("pkgconfig", basename) : basename
        destination = File.join(output_dir, relative)
        File.copy(file, destination)
        File.chmod(destination, 0o644)
        hashes[relative] = digest(destination)
      end
      FileUtils.mkdir_p(File.dirname(marker))
      File.write(marker, {"signature" => signature, "outputs" => hashes}.to_yaml)
    ensure
      FileUtils.rm_rf(staging)
    end
  end

  def self.package(platforms : Array(String), libraries : Array(Library), force : Bool = false) : Nil
    root = path("prebuilt_libs")
    files = platforms.flat_map do |platform|
      allowed = libraries.select { |library| (binary = library.binaries[platform]?) && binary.action != "noop" }.flat_map(&.files).to_set
      allowed << "gmp.pc" if libraries.any? { |library| library.name == "gmp" && library.binaries[platform]?.try(&.action) == "build" }
      Dir.glob(File.join(root, platform, "**", "*")).select { |file| File.file?(file) && allowed.includes?(File.basename(file)) }
    end.sort
    raise "No libraries to package" if files.empty?
    signature = files.map { |file| "#{file.sub(ROOT + "/", "")}:#{digest(file)}" }.join("\n")
    signature_hash = Digest::SHA256.hexdigest(signature)
    archive = path("pkg", "libs-#{VERSION}.tar.xz")
    marker = path("tmp", ".package.yml")
    if !force && File.file?(archive) && File.file?(marker)
      begin
        cache = YAML.parse(File.read(marker)).as_h
        return if cache["signature"].as_s == signature_hash && cache["archive_sha256"].as_s == digest(archive)
      rescue YAML::ParseException | KeyError | TypeCastError
        # Rebuild an archive whose marker is incomplete or corrupt.
      end
    end

    staging_root = path("pkg", "libs-#{VERSION}")
    FileUtils.rm_rf(staging_root)
    files.each do |file|
      relative = file.sub(ROOT + "/", "")
      destination = File.join(staging_root, relative)
      FileUtils.mkdir_p(File.dirname(destination))
      File.copy(file, destination)
    end
    temporary = "#{archive}.part"
    begin
      run("tar", ["-cJf", temporary, "-C", path("pkg"), File.basename(staging_root)])
      File.rename(temporary, archive)
      FileUtils.mkdir_p(File.dirname(marker))
      File.write(marker, {"signature" => signature_hash, "archive_sha256" => digest(archive)}.to_yaml)
    ensure
      File.delete(temporary) if File.exists?(temporary)
    end
  end

  def self.gmp_cache_signature(library : Library, platform : String) : String
    source = library.source || raise "GMP source is missing from libs.yml"
    "#{library.version}:#{source.url}:#{source.sha256}:#{platform}:zig-cc-O3-fno-lto-static-pic-v1"
  end

  def self.build_gmp(library : Library, platform : String, force : Bool = false) : Nil
    source = library.source || raise "GMP source is missing from libs.yml"
    version = library.version
    source_archive = path("downloads", "sources", "gmp-#{version}.tar.xz")
    source_dir = path("tmp", "gmp-#{version}")
    build_dir = path("tmp", "gmp-build-#{platform}")
    cache_dir = path("tmp", "zig-cache")
    output_dir = path("prebuilt_libs", platform)
    gmp_library = File.join(output_dir, "libgmp.a")
    gmp_pkgconfig = File.join(output_dir, "pkgconfig", "gmp.pc")
    built_cache = path("downloads", "built", platform, "gmp-#{version}")
    cached_library = File.join(built_cache, "libgmp.a")
    cached_pkgconfig = File.join(built_cache, "gmp.pc")
    marker = File.join(built_cache, "manifest.yml")
    signature = gmp_cache_signature(library, platform)
    if !force && File.file?(marker) && File.file?(cached_library) && File.file?(cached_pkgconfig)
      begin
        cache = YAML.parse(File.read(marker)).as_h
        if cache["signature"].as_s == signature &&
           cache["library_sha256"].as_s == digest(cached_library) &&
           cache["pkgconfig_sha256"].as_s == digest(cached_pkgconfig)
          FileUtils.mkdir_p(File.join(output_dir, "pkgconfig"))
          unless File.file?(gmp_library) && digest(gmp_library) == cache["library_sha256"].as_s
            File.copy(cached_library, gmp_library)
            File.chmod(gmp_library, 0o644)
          end
          unless File.file?(gmp_pkgconfig) && digest(gmp_pkgconfig) == cache["pkgconfig_sha256"].as_s
            File.copy(cached_pkgconfig, gmp_pkgconfig)
            File.chmod(gmp_pkgconfig, 0o644)
          end
          STDERR.puts "Using cached GMP #{version} for #{platform}"
          return
        end
      rescue YAML::ParseException | KeyError | TypeCastError
        # Rebuild when the cache manifest is incomplete or corrupt.
      end
    end

    FileUtils.mkdir_p(cache_dir)
    download(source, source_archive)
    FileUtils.rm_rf(source_dir)
    run("tar", ["-xf", source_archive, "-C", path("tmp")])
    FileUtils.rm_rf(build_dir)
    FileUtils.mkdir_p(build_dir)
    env = {
      "ZIG_GLOBAL_CACHE_DIR" => cache_dir,
      "CC"                   => "zig cc -target #{platform}",
      "CC_FOR_BUILD"         => "cc",
      "CFLAGS"               => "-O3 -fno-lto",
      "AR"                   => "llvm-ar",
      "RANLIB"               => "llvm-ranlib",
    }
    run(File.join(source_dir, "configure"), ["--host=#{platform}", "--build=x86_64-pc-linux-gnu", "--disable-shared", "--enable-static", "--disable-cxx", "--with-pic"], build_dir, env)
    run("make", ["-j#{System.cpu_count}"], build_dir, {"ZIG_GLOBAL_CACHE_DIR" => cache_dir})
    run("llvm-strip", ["-g", File.join(build_dir, ".libs", "libgmp.a")])
    FileUtils.mkdir_p(built_cache)
    File.copy(File.join(build_dir, ".libs", "libgmp.a"), cached_library)
    File.chmod(cached_library, 0o644)
    File.copy(File.join(build_dir, "gmp.pc"), cached_pkgconfig)
    File.chmod(cached_pkgconfig, 0o644)
    File.write(marker, {
      "signature"        => signature,
      "library_sha256"   => digest(cached_library),
      "pkgconfig_sha256" => digest(cached_pkgconfig),
    }.to_yaml)
    FileUtils.mkdir_p(File.join(output_dir, "pkgconfig"))
    File.copy(cached_library, gmp_library)
    File.chmod(gmp_library, 0o644)
    File.copy(cached_pkgconfig, gmp_pkgconfig)
    File.chmod(gmp_pkgconfig, 0o644)
  end

  def self.clean : Nil
    ["**/*~", "**/*.bak", "**/core"].each do |pattern|
      Dir.glob(File.join(ROOT, pattern)).each do |file|
        FileUtils.rm_rf(file) unless File.directory?(file)
      end
    end
    FileUtils.rm_rf(path("prebuilt_libs"))
    FileUtils.rm_rf(path("tmp"))
  end

  def self.clobber_package : Nil
    FileUtils.rm_rf(path("pkg"))
    marker = path("tmp", ".package.yml")
    File.delete(marker) if File.exists?(marker)
  end

  def self.clobber : Nil
    clean
    clobber_package
    FileUtils.rm_rf(path("downloads"))
  end

  def self.main(args : Array(String)) : Nil
    Dir.cd(ROOT)
    FileUtils.mkdir_p(path("tmp"))
    Croupier::TaskManager.state_file = path("tmp", ".croupier")
    libraries = read_libraries
    platforms = libraries.flat_map(&.binaries.keys).uniq
    tasks = [] of String
    libraries.each do |library|
      library.binaries.each_key do |platform|
        id = "fetch:#{platform}:#{library.name}"
        tasks << id
        Croupier::Task.new(id: id, always_run: true) do
          case library.binaries[platform].action
          when "build" then build_gmp(library, platform)
          when "fetch" then fetch(library, platform)
          when "noop"  then STDERR.puts "Skipping #{library.name} for #{platform}"
          end
          [] of String
        end
      end
    end
    platforms.each do |platform|
      id = "fetch:#{platform}"
      tasks << id
      inputs = libraries.select(&.binaries.has_key?(platform)).map { |library| "#{id}:#{library.name}" }
      Croupier::Task.new(id: id, inputs: inputs, always_run: true) { [] of String }
    end
    tasks << "fetch:all"
    Croupier::Task.new(id: "fetch:all", inputs: platforms.map { |platform| "fetch:#{platform}" }, always_run: true) { [] of String }
    ["aarch64-linux-musl", "x86_64-linux-musl"].each do |platform|
      id = "gmp:build:#{platform}"
      tasks << id
      Croupier::Task.new(id: id, always_run: true) do
        build_gmp(libraries.find { |library| library.name == "gmp" }.not_nil!, platform, force: true)
        [] of String
      end
    end
    tasks.concat(["package", "repackage", "clobber_package", "clean", "clobber"])

    target = args.first? || "help"
    if {"help", "-h", "--help", "-T", "--tasks"}.includes?(target)
      puts "Usage: bin/tasks <task>"
      puts tasks.sort.join("\n")
      return
    end
    raise "Unknown task: #{target}" unless tasks.includes?(target)
    case target
    when "clean"           then clean
    when "clobber"         then clobber
    when "clobber_package" then clobber_package
    when "package", "repackage"
      Croupier::TaskManager.run_tasks(["fetch:all"])
      package(platforms, libraries, force: target == "repackage")
    else
      Croupier::TaskManager.run_tasks([target])
    end
  end
end
