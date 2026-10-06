require "yaml"

module HaversackTasks
  # 一份下载资源的地址和校验值
  record(DownloadSource, url : String, sha256 : String) do
    include YAML::Serializable
  end

  # 将 YAML 中的平台数组转换成按平台索引的 Hash
  module PlatformMap
    def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : Hash(String, PlatformConfig)
      Array(PlatformConfig).new(ctx, node).to_h { |config| {config.platform, config} }
    end

    def self.to_yaml(platform_configs : Hash(String, PlatformConfig), yaml : YAML::Nodes::Builder) : Nil
      platform_configs.values.to_yaml(yaml)
    end
  end

  # 一个库在某个平台上的配置
  record(
    PlatformConfig,
    platform : String,
    download_source : DownloadSource,
    action : String = "fetch"
  ) do
    include YAML::Serializable
  end

  # 一个库的完整配置，包含各个平台
  record(
    Library,
    alpine_package : String?,
    homebrew_formula : String?,
    alpine_version : String?,
    homebrew_version : String?,
    files : Array(String),
    platform_configs : Hash(String, PlatformConfig)
  ) do
    include YAML::Serializable

    @[YAML::Field(converter: HaversackTasks::PlatformMap)]
    @platform_configs : Hash(String, PlatformConfig)

    protected def after_initialize
      raise "libs.yml: alpine_package and alpine_version must be set together" unless alpine_package.nil? == alpine_version.nil?
      raise "libs.yml: homebrew_formula and homebrew_version must be set together" unless homebrew_formula.nil? == homebrew_version.nil?
      raise "libs.yml: missing package name" unless alpine_package || homebrew_formula

      validate_platforms
    end

    private def validate_platforms : Nil
      platform_configs.each_key { |platform| HaversackTasks.package_name(self, platform) }
    end
  end

  def self.package_name(library : Library, platform : String) : String
    if platform.ends_with?("-linux-musl")
      library.alpine_package || raise "Missing alpine_package for #{platform}"
    else
      library.homebrew_formula || raise "Missing homebrew_formula for #{platform}"
    end
  end

  def self.package_version(library : Library, platform : String) : String
    if platform.ends_with?("-linux-musl")
      library.alpine_version || raise "Missing alpine_version for #{platform}"
    else
      library.homebrew_version || raise "Missing homebrew_version for #{platform}"
    end
  end

  def self.library_task_name(library : Library, platform : String) : String
    action = library.platform_configs[platform].action
    action == "fetch" ? "fetch:#{platform}:#{package_name(library, platform)}" : action
  end

  def self.read_libraries : Array(Library)
    File.open(path("libs.yml")) { |file| Array(Library).from_yaml(file) }
  end
end
