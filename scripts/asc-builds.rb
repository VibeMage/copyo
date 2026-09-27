#!/usr/bin/env ruby
# 列出 App Store Connect 上最近的构建及其处理状态（只读）。
#
# 用法:
#   ./scripts/asc-builds.rb            # iOS
#   ./scripts/asc-builds.rb MAC_OS     # macOS
#
# 凭据与 build-appstore-ios.sh 上传用的是同一把 App Store Connect API 密钥：
#   ~/.appstoreconnect/copyo.env                      ASC_KEY_ID / ASC_ISSUER_ID（仓库是公开的，不进仓库）
#   ~/.appstoreconnect/private_keys/AuthKey_<ID>.p8   密钥本体，只在本进程里拿来签名，从不打印
#
# 为什么不用 `altool --build-status`：它要上传时返回的 delivery ID，Transporter / Organizer
# 传上去的构建拿不到这个号，查不了。
#
# 用系统自带的 Ruby + OpenSSL 签 ES256，不依赖任何第三方 gem（本机的 Python 没有 jwt / cryptography）。
require "openssl"
require "json"
require "net/http"
require "uri"
require "base64"

APP_ID = "6813955206"
platform = (ARGV[0] || "IOS").upcase

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

def b64url(data)
  Base64.urlsafe_encode64(data).delete("=")
end

# JWS 的 ES256 签名是 r ‖ s 各 32 字节，OpenSSL 给的是 DER 编码的 ECDSA 签名，要拆开重排
def es256(key, input)
  der = key.dsa_sign_asn1(OpenSSL::Digest::SHA256.digest(input))
  r, s = OpenSSL::ASN1.decode(der).value.map { |i| i.value.to_s(2).rjust(32, "\x00".b)[-32, 32] }
  r + s
end

now = Time.now.to_i
header = b64url({ alg: "ES256", kid: key_id, typ: "JWT" }.to_json)
payload = b64url({ iss: issuer, iat: now, exp: now + 600, aud: "appstoreconnect-v1" }.to_json)
signing_input = "#{header}.#{payload}"
token = "#{signing_input}.#{b64url(es256(OpenSSL::PKey::EC.new(File.read(key_path)), signing_input))}"

query = URI.encode_www_form(
  "filter[app]" => APP_ID,
  "filter[preReleaseVersion.platform]" => platform,
  "sort" => "-uploadedDate",
  "limit" => "10",
  "fields[builds]" => "version,uploadedDate,processingState,expired,preReleaseVersion",
  "include" => "preReleaseVersion",
  "fields[preReleaseVersions]" => "version"
)
uri = URI("https://api.appstoreconnect.apple.com/v1/builds?#{query}")
req = Net::HTTP::Get.new(uri)
req["Authorization"] = "Bearer #{token}"
res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(req) }
abort "App Store Connect 返回 #{res.code}：#{res.body[0, 400]}" unless res.is_a?(Net::HTTPSuccess)

body = JSON.parse(res.body)
versions = (body["included"] || []).to_h { |v| [v["id"], v.dig("attributes", "version")] }
puts format("%-10s %-6s %-12s %-26s %s", "版本", "构建", "处理状态", "上传时间", "")
body["data"].each do |b|
  a = b["attributes"]
  short = versions[b.dig("relationships", "preReleaseVersion", "data", "id")] || "?"
  puts format("%-10s %-6s %-12s %-26s %s", short, a["version"], a["processingState"], a["uploadedDate"],
              a["expired"] ? "已过期" : "")
end
