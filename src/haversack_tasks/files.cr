require "digest/sha256"
require "file_utils"
require "yaml"

# 方法               用途
# ━━━━━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# path               拼接项目内的路径
# ─────────────────  ──────────────────────────────────────
# digest             计算文件的 SHA256
# ─────────────────  ──────────────────────────────────────
# matches_digest?    检查文件是否存在且校验值正确
# ─────────────────  ──────────────────────────────────────
# valid_cache?       读取 YAML 缓存标记，损坏时返回 false
# ─────────────────  ──────────────────────────────────────
# install_file       复制文件，并设置为可读写的权限
# ─────────────────  ──────────────────────────────────────
# run                执行外部命令，失败时抛出异常

module HaversackTasks
  def self.path(*parts : String) : String
    File.join(ROOT, *parts)
  end

  def self.digest(path : String) : String
    File.open(path) { |file| Digest::SHA256.hexdigest(file) }
  end

  def self.matches_digest?(file : String, sha256 : String) : Bool
    File.file?(file) && digest(file) == sha256
  end

  # An invalid manifest must never hide missing or damaged files.
  def self.valid_cache?(marker : String, &block : Hash(YAML::Any, YAML::Any) -> Bool) : Bool
    return false unless File.file?(marker)

    yield YAML.parse(File.read(marker)).as_h
  rescue YAML::ParseException | KeyError | TypeCastError
    false
  end

  def self.install_file(source : String, destination : String, sha256 : String? = nil) : Nil
    return if sha256 && matches_digest?(destination, sha256)

    FileUtils.mkdir_p(File.dirname(destination))
    File.copy(source, destination)
    File.chmod(destination, 0o644)
  end

  def self.run(command : String, args : Array(String), chdir : String = ROOT, env : Hash(String, String)? = nil) : Nil
    STDERR.puts "#{command} #{args.join(' ')}"

    status = Process.run(
      command,
      args,
      chdir: chdir,
      env: env,
      output: STDOUT,
      error: STDERR
    )

    raise "#{command} failed (#{status.exit_code})" unless status.success?
  end
end
