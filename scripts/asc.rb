#!/usr/bin/env ruby
# App Store Connect 的几个日常操作，走官方 REST API。
#
# 用法:
#   ./scripts/asc.rb builds [IOS|MAC_OS]   最近的构建与处理状态（只读）
#   ./scripts/asc.rb version [IOS|MAC_OS]  待发布的版本：状态、发布方式、选中的构建（只读）
#   ./scripts/asc.rb attach <构建号>       把 iOS 待提交版本的构建换成这一个（只改草稿，不提交审核）
#
# 凭据与 build-appstore-ios.sh 上传用的是同一把 App Store Connect API 密钥：
#   ~/.appstoreconnect/copyo.env                      ASC_KEY_ID / ASC_ISSUER_ID（仓库是公开的，不进仓库）
#   ~/.appstoreconnect/private_keys/AuthKey_<ID>.p8   密钥本体，只在本进程里拿来签名，从不打印
#
# 为什么不用 `altool --build-status`：它要上传时返回的 delivery ID，Transporter / Organizer
# 传上去的构建拿不到这个号，查不了。
#
# 用系统自带的 Ruby + OpenSSL 签 ES256，不依赖任何第三方 gem（本机的 Python 没有 jwt / cryptography）。
# **提交审核故意不做成子命令**：那是以维护者名义对外的一步，每次都在 ASC 里由人确认。
require "openssl"
require "json"
require "net/http"
require "uri"
require "base64"

APP_ID = "6813955206"

module ASC
  module_function

  def credentials
    env_file = File.expand_path("~/.appstoreconnect/copyo.env")
    if (ENV["ASC_KEY_ID"].to_s.empty? || ENV["ASC_ISSUER_ID"].to_s.empty?) && File.exist?(env_file)
      File.readlines(env_file).each do |line|
        ENV[$1] = $2 if line =~ /^\s*export\s+(ASC_KEY_ID|ASC_ISSUER_ID)=(\S+)/
      end
    end
    key_id = ENV["ASC_KEY_ID"].to_s
    issuer = ENV["ASC_ISSUER_ID"].to_s
    abort "缺 ASC_KEY_ID / ASC_ISSUER_ID（见 #{env_file}）" if key_id.empty? || issuer.empty?
    key_path = File.expand_path("~/.appstoreconnect/private_keys/AuthKey_#{key_id}.p8")
    abort "找不到密钥文件 #{key_path}" unless File.exist?(key_path)
    [key_id, issuer, key_path]
  end

  def b64url(data)
    Base64.urlsafe_encode64(data).delete("=")
  end

  # JWS 的 ES256 签名是 r ‖ s 各 32 字节，OpenSSL 给的是 DER 编码的 ECDSA 签名，要拆开重排
  def es256(key, input)
    der = key.dsa_sign_asn1(OpenSSL::Digest::SHA256.digest(input))
    r, s = OpenSSL::ASN1.decode(der).value.map { |i| i.value.to_s(2).rjust(32, "\x00".b)[-32, 32] }
    r + s
  end

  def token
    @token ||= begin
      key_id, issuer, key_path = credentials
      now = Time.now.to_i
      header = b64url({ alg: "ES256", kid: key_id, typ: "JWT" }.to_json)
      payload = b64url({ iss: issuer, iat: now, exp: now + 600, aud: "appstoreconnect-v1" }.to_json)
      input = "#{header}.#{payload}"
      "#{input}.#{b64url(es256(OpenSSL::PKey::EC.new(File.read(key_path)), input))}"
    end
  end

  def request(method, path, params: nil, body: nil)
    uri = URI("https://api.appstoreconnect.apple.com#{path}")
    uri.query = URI.encode_www_form(params) if params
    klass = { get: Net::HTTP::Get, post: Net::HTTP::Post, patch: Net::HTTP::Patch, delete: Net::HTTP::Delete }
    req = klass.fetch(method).new(uri)
    req["Authorization"] = "Bearer #{token}"
    if body
      req["Content-Type"] = "application/json"
      req.body = body.to_json
    end
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(req) }
    abort "App Store Connect 返回 #{res.code}：#{res.body.to_s[0, 600]}" unless res.is_a?(Net::HTTPSuccess)
    res.body.to_s.empty? ? {} : JSON.parse(res.body)
  end

  def builds(platform, limit: 10)
    body = request(:get, "/v1/builds", params: {
      "filter[app]" => APP_ID,
      "filter[preReleaseVersion.platform]" => platform,
      "sort" => "-uploadedDate",
      "limit" => limit.to_s,
      "fields[builds]" => "version,uploadedDate,processingState,expired,preReleaseVersion",
      "include" => "preReleaseVersion",
      "fields[preReleaseVersions]" => "version"
    })
    versions = (body["included"] || []).to_h { |v| [v["id"], v.dig("attributes", "version")] }
    body["data"].map do |b|
      b["attributes"].merge("id" => b["id"],
                            "short" => versions[b.dig("relationships", "preReleaseVersion", "data", "id")])
    end
  end

  # 还没发布的那个版本（准备提交 / 等待审核 / 审核中 / 被拒……），发布过的不算
  def pending_version(platform)
    body = request(:get, "/v1/apps/#{APP_ID}/appStoreVersions", params: {
      "filter[platform]" => platform,
      "filter[appStoreState]" => "PREPARE_FOR_SUBMISSION,DEVELOPER_REJECTED,REJECTED,METADATA_REJECTED," \
                                 "WAITING_FOR_REVIEW,IN_REVIEW,PENDING_DEVELOPER_RELEASE",
      "include" => "build",
      "fields[builds]" => "version"
    })
    v = body["data"].first or abort "#{platform} 上没有待发布的版本"
    build = (body["included"] || []).find { |i| i["type"] == "builds" }
    v["attributes"].merge("id" => v["id"], "build" => build&.dig("attributes", "version"))
  end
end

# 被别的脚本 `require` 时只提供 ASC 模块，不跑命令分发
return unless __FILE__ == $PROGRAM_NAME

command = ARGV.shift
case command
when "builds"
  platform = (ARGV[0] || "IOS").upcase
  puts format("%-8s %-6s %-12s %s", "版本", "构建", "处理状态", "上传时间")
  ASC.builds(platform).each do |b|
    puts format("%-8s %-6s %-12s %s%s", b["short"], b["version"], b["processingState"], b["uploadedDate"],
                b["expired"] ? "  已过期" : "")
  end
when "version"
  v = ASC.pending_version((ARGV[0] || "IOS").upcase)
  puts "版本 #{v['versionString']} · 状态 #{v['appStoreState']} · 发布方式 #{v['releaseType']} · 构建 #{v['build'] || '（未选）'}"
when "attach"
  number = ARGV[0] or abort "用法：#{$PROGRAM_NAME} attach <构建号>"
  version = ASC.pending_version("IOS")
  unless %w[PREPARE_FOR_SUBMISSION DEVELOPER_REJECTED REJECTED METADATA_REJECTED].include?(version["appStoreState"])
    abort "版本 #{version['versionString']} 当前是 #{version['appStoreState']}，不能换构建（审核中要先撤回）"
  end
  build = ASC.builds("IOS", limit: 50).find { |b| b["version"] == number && b["short"] == version["versionString"] }
  abort "找不到 #{version['versionString']} (#{number}) 的构建" unless build
  abort "构建 #{number} 还在处理（#{build['processingState']}），等它变成 VALID 再换" unless build["processingState"] == "VALID"
  ASC.request(:patch, "/v1/appStoreVersions/#{version['id']}/relationships/build",
              body: { data: { type: "builds", id: build["id"] } })
  after = ASC.pending_version("IOS")
  puts "版本 #{after['versionString']} 的构建：#{version['build'] || '（未选）'} → #{after['build']}"
else
  abort "用法：#{$PROGRAM_NAME} builds [IOS|MAC_OS] | version [IOS|MAC_OS] | attach <构建号>"
end
