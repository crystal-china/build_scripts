require "http/client"
require "uri"

module HaversackTasks
  GMP_SOURCE_MIRROR = "https://ftp.gnu.org/gnu/gmp/"
  GMP_SOURCE_BACKUP = "https://gmplib.org/download/gmp/"
  ALPINE_MIRROR     = "https://mirrors.tuna.tsinghua.edu.cn/alpine/"
  ALPINE_OFFICIAL   = "https://dl-cdn.alpinelinux.org/alpine/"
  RETRIES           = 6

  class DownloadFailure < Exception
    getter retryable : Bool
    getter retry_delay : Time::Span?

    def initialize(message : String, @retryable : Bool = false, @retry_delay : Time::Span? = nil)
      super(message)
    end
  end

  # 发起一次 HTTP(S) 下载到临时文件，并处理最多 5 次重定向。
  def self.download_once(url : String, temporary_file : String) : Nil
    current = URI.parse(url)

    6.times do
      raise DownloadFailure.new("Only HTTP(S) download URLs are supported: #{current}") unless current.scheme.in?({"http", "https"})

      headers = HTTP::Headers{"Accept-Encoding" => "identity"}
      headers["Authorization"] = "Bearer QQ==" if current.host == "ghcr.io"
      client = HTTP::Client.new(current)
      client.connect_timeout = 20.seconds
      client.read_timeout = 90.seconds

      begin
        redirect : String? = nil

        client.get(current.request_target, headers) do |response|
          case response.status_code
          when 200
            File.open(temporary_file, "w") { |file| IO.copy(response.body_io, file) }
          when 301, 302, 303, 307, 308
            redirect = response.headers["Location"]?

            raise DownloadFailure.new("Redirect lacks Location: #{current}") unless redirect
          else
            retryable = response.status_code.in?({408, 425, 429}) || response.status_code >= 500
            retry_delay = parse_retry_after_header(response.headers["Retry-After"]?)

            raise DownloadFailure.new("HTTP #{response.status_code} from #{current}", retryable, retry_delay)
          end
        end

        if (location = redirect)
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

  # 校验缓存、选择备用地址、重试、校验 SHA256，并把文件保存到最终位置。
  def self.download(source : DownloadSource, destination : String) : Nil
    expected = source.sha256.downcase

    raise "Invalid SHA256 for #{source.url}" unless expected.matches?(/\A[0-9a-f]{64}\z/)

    if File.file?(destination)
      return if matches_digest?(destination, expected)

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

    last_error = ""
    temporary_file = "#{destination}.part.#{Process.pid}"

    endpoints.each do |url|
      RETRIES.times do |index|
        server_delay : Time::Span? = nil

        begin
          STDERR.puts "Downloading #{url} (attempt #{index + 1}/#{RETRIES})"

          download_once(url, temporary_file)

          actual = digest(temporary_file)

          raise DownloadFailure.new("SHA256 mismatch for #{url}: expected #{expected}, got #{actual}", true) unless actual == expected

          File.rename(temporary_file, destination)

          return
        rescue ex : DownloadFailure
          last_error = ex.message.to_s
          server_delay = ex.retry_delay

          break unless ex.retryable
        rescue ex : IO::Error | Socket::Error | OpenSSL::Error
          last_error = "#{ex.class}: #{ex.message}"
        ensure
          File.delete(temporary_file) if File.exists?(temporary_file)
        end

        if index < RETRIES - 1
          delay = retry_delay(index + 1, server_delay)

          STDERR.puts "Retrying in #{delay.total_seconds.round(1)}s: #{last_error}"

          sleep delay
        end
      end
    end

    raise "Unable to download #{destination}: #{last_error}"
  end

  # Retry-After 可以是秒数或 HTTP 日期；无效值返回 nil，等待时间限制在 0–60 秒。
  private def self.parse_retry_after_header(retry_header : String?, now : Time = Time.utc) : Time::Span?
    return unless retry_header

    retry_header = retry_header.strip

    if (seconds = retry_header.to_f64?)
      return unless seconds.finite?

      return seconds.clamp(0.0, 60.0).seconds
    end

    HTTP.parse_time(retry_header).try { |date| (date - now).clamp(0.seconds, 60.seconds) }
  end

  private def self.retry_delay(attempt : Int32, server_delay : Time::Span? = nil) : Time::Span
    server_delay || (Math.min(2.0 ** (attempt - 1), 30.0) + Random.rand).seconds
  end
end
