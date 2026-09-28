#!/usr/bin/env ruby
# App Store Connect 的几个日常操作，走官方 REST API。
#
# 用法:
#   ./scripts/asc.rb builds [IOS|MAC_OS]   最近的构建与处理状态（只读）
#   ./scripts/asc.rb version [IOS|MAC_OS]  待发布的版本：状态、发布方式、选中的构建（只读）
#   ./scripts/asc.rb attach <构建号>       把 iOS 待提交版本的构建换成这一个（只改草稿，不提交审核）
#   ./scripts/asc.rb review-attachment <文件>  给 iOS 待提交版本的「App 审核信息」传一个附件（演示视频），
#                                          同名的旧附件先删掉
#   ./scripts/asc.rb mac-media <目录> [--dry-run]  把 Mac 待提交版本的商店截图与预览视频换成 <目录> 里的
#                                          （NN-名称-{zh,en}.png、preview/{zh,en}-preview.mp4）：先传新的、
#                                          等处理完，再删旧的并按文件名排序；海报帧设为 00:00:01:00
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
require "digest"

APP_ID = "6813955206"

module ASC
  module_function

  # 接口返回非 2xx、分片上传失败、素材处理失败时抛出，status 是 HTTP 状态码（没有时为 nil）；
  # 命令行入口统一转成 abort，被别的脚本 require 时由调用方决定怎么处理
  class Error < StandardError
    attr_reader :status

    def initialize(message, status = nil)
      super(message)
      @status = status
    end
  end

  # 网络层的瞬时错误，和 429 / 5xx 一样可以重试
  TRANSIENT = [SocketError, Timeout::Error, EOFError, IOError, SystemCallError, OpenSSL::SSL::SSLError].freeze

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

  # 令牌 10 分钟过期；传素材、等视频转码会超过这个时长，所以 9 分钟后重签
  def token
    @token = nil if @token_at && Time.now.to_i - @token_at > 540
    @token ||= begin
      key_id, issuer, key_path = credentials
      now = @token_at = Time.now.to_i
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
    raise Error.new("App Store Connect 返回 #{res.code}：#{res.body.to_s[0, 600]}", res.code.to_i) unless res.is_a?(Net::HTTPSuccess)
    res.body.to_s.empty? ? {} : JSON.parse(res.body)
  end

  # 网络瞬时错误、429 与 5xx 按 2、4、8 秒退避重试，最多 tries 次；其余错误原样抛出。只给幂等的请求用
  def with_retry(tries: 4)
    attempt = 0
    begin
      yield
    rescue Error, *TRANSIENT => e
      raise if e.is_a?(Error) && !(e.status == 429 || e.status.to_i >= 500)
      attempt += 1
      raise if attempt >= tries
      sleep 2**attempt
      retry
    end
  end

  # 幂等的 GET，按 with_retry 的规则重试
  def get(path, params: nil)
    with_retry { request(:get, path, params: params) }
  end

  # 删一条资源；已经不在了（404）也算删掉
  def delete(type, id)
    with_retry { request(:delete, "/v1/#{type}/#{id}") }
  rescue Error => e
    raise unless e.status == 404
  end

  def builds(platform, limit: 10)
    body = get("/v1/builds", params: {
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
    body = get("/v1/apps/#{APP_ID}/appStoreVersions", params: {
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

  # 素材上传的三步：先登记文件拿到分片上传地址，按分片 PUT 上去，最后带 MD5 标记「传完了」。
  # 返回新建资源的 id；状态由调用方按各自的字段轮询。登记（POST）不重试，免得网络抖动时登记出两份；
  # 分片与确认可以重试。登记之后任何一步失败（包括 Ctrl-C），都先删掉这条占位再把错误往上抛。
  def upload(type, path, relationships, attributes = {})
    created = request(:post, "/v1/#{type}", body: { data: {
      type: type,
      attributes: { fileName: File.basename(path), fileSize: File.size(path) }.merge(attributes),
      relationships: relationships
    } })["data"]
    begin
      File.open(path, "rb") do |file|
        created.dig("attributes", "uploadOperations").each do |op|
          file.seek(op["offset"])
          chunk = file.read(op["length"])
          uri = URI(op["url"])
          with_retry do
            req = Net::HTTPGenericRequest.new(op["method"], true, true, uri)
            (op["requestHeaders"] || []).each { |h| req[h["name"]] = h["value"] }
            req.body = chunk
            res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(req) }
            raise Error.new("分片上传失败 #{res.code}：#{res.body.to_s[0, 300]}", res.code.to_i) unless res.is_a?(Net::HTTPSuccess)
          end
        end
      end
      checksum = Digest::MD5.file(path).hexdigest
      begin
        with_retry do
          request(:patch, "/v1/#{type}/#{created['id']}", body: { data: {
            type: type, id: created["id"], attributes: { sourceFileChecksum: checksum, uploaded: true }
          } })
        end
      rescue Error, *TRANSIENT
        # 确认请求可能已经生效、只是响应丢了，这时重发会被拒。回查一下：MD5 对得上、已经过了等待上传这一步，就算成功
        attrs = get("/v1/#{type}/#{created['id']}")["data"]["attributes"]
        state = (attrs["videoDeliveryState"] || attrs["assetDeliveryState"] || {})["state"]
        raise unless attrs["sourceFileChecksum"] == checksum && %w[UPLOAD_COMPLETE PROCESSING COMPLETE].include?(state)
      end
    rescue Exception # rubocop:disable Lint/RescueException -- Ctrl-C 也要先清掉占位
      begin
        delete(type, created["id"])
      rescue Exception # rubocop:disable Lint/RescueException
        warn "清理未传完的 #{type}/#{created['id']} 失败，请到 ASC 手动删"
      end
      raise
    end
    created["id"]
  end

  # 等素材处理完：截图看 assetDeliveryState，视频看 videoDeliveryState。FAILED 时带上 Apple 给的原因。
  def wait_delivery(type, id, field, timeout: 1800)
    deadline = Time.now + timeout
    loop do
      attrs = get("/v1/#{type}/#{id}")["data"]["attributes"]
      state = attrs.dig(field, "state")
      return attrs if state == "COMPLETE"
      if state == "FAILED"
        raise Error, "#{attrs['fileName']} 处理失败：#{(attrs.dig(field, 'errors') || []).map { |e| e['description'] }.join('；')}"
      end
      raise Error, "#{attrs['fileName']} 等了 #{timeout} 秒仍是 #{state}" if Time.now > deadline
      sleep 5
    end
  end
end

# 被别的脚本 `require` 时只提供 ASC 模块，不跑命令分发
return unless __FILE__ == $PROGRAM_NAME

command = ARGV.shift
begin
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
when "review-attachment"
  path = ARGV[0] or abort "用法：#{$PROGRAM_NAME} review-attachment <文件>"
  abort "找不到 #{path}" unless File.file?(path)
  version = ASC.pending_version("IOS")
  unless %w[PREPARE_FOR_SUBMISSION DEVELOPER_REJECTED REJECTED METADATA_REJECTED].include?(version["appStoreState"])
    abort "版本 #{version['versionString']} 当前是 #{version['appStoreState']}，审核信息改不了"
  end
  detail = ASC.request(:get, "/v1/appStoreVersions/#{version['id']}/appStoreReviewDetail")["data"]
  name = File.basename(path)
  ASC.request(:get, "/v1/appStoreReviewDetails/#{detail['id']}/appStoreReviewAttachments")["data"].each do |old|
    next unless old.dig("attributes", "fileName") == name
    ASC.request(:delete, "/v1/appStoreReviewAttachments/#{old['id']}")
    puts "删掉旧的 #{name}"
  end
  created_id = ASC.upload("appStoreReviewAttachments", path,
                          { appStoreReviewDetail: { data: { type: "appStoreReviewDetails", id: detail["id"] } } })
  state = nil
  30.times do
    state = ASC.request(:get, "/v1/appStoreReviewAttachments/#{created_id}")["data"].dig("attributes", "assetDeliveryState", "state")
    break unless %w[AWAITING_UPLOAD UPLOAD_COMPLETE].include?(state)
    sleep 2
  end
  puts "#{name}（#{(File.size(path) / 1_048_576.0).round(1)} MB）已传到 #{version['versionString']} 的审核信息 · #{state}"
when "mac-media"
  dry = ARGV.delete("--dry-run")
  dir = ARGV[0] or abort "用法：#{$PROGRAM_NAME} mac-media <素材目录> [--dry-run]"
  locales = { "zh" => "zh-Hans", "en" => "en-US" }
  md5 = ->(path) { Digest::MD5.file(path).hexdigest }
  checksum = ->(resource) { resource.dig("attributes", "sourceFileChecksum") }
  done = ->(resource) {
    (resource.dig("attributes", "videoDeliveryState") || resource.dig("attributes", "assetDeliveryState") || {})["state"] == "COMPLETE"
  }
  plan = locales.to_h do |lang, locale|
    shots = Dir[File.join(dir, "[0-9][0-9]-*-#{lang}.png")].sort
    preview = File.join(dir, "preview", "#{lang}-preview.mp4")
    abort "#{locale}：截图要 1–10 张（#{dir}/NN-名称-#{lang}.png），找到 #{shots.size} 张" unless (1..10).cover?(shots.size)
    abort "#{locale}：找不到预览视频 #{preview}" unless File.file?(preview)
    shots.each do |png|
      width, height = File.binread(png, 8, 16).unpack("NN")
      abort "#{png} 是 #{width}×#{height}，Mac 截图用 2560×1600" unless [width, height] == [2560, 1600]
    end
    abort "#{locale}：有两张截图内容相同" unless shots.map(&md5).uniq.size == shots.size
    [locale, { shots: shots, preview: preview }]
  end
  version = ASC.pending_version("MAC_OS")
  unless %w[PREPARE_FOR_SUBMISSION DEVELOPER_REJECTED REJECTED METADATA_REJECTED].include?(version["appStoreState"])
    abort "Mac #{version['versionString']} 当前是 #{version['appStoreState']}，素材改不了（审核中要先撤回）"
  end
  localizations = ASC.get("/v1/appStoreVersions/#{version['id']}/appStoreVersionLocalizations")["data"]
  list_shots = ->(set) { ASC.get("/v1/appScreenshotSets/#{set}/appScreenshots")["data"] }
  list_previews = ->(set) { ASC.get("/v1/appPreviewSets/#{set}/appPreviews")["data"] }
  targets = plan.map do |locale, files|
    loc = localizations.find { |l| l.dig("attributes", "locale") == locale } or abort "版本页没有 #{locale} 本地化"
    shot_set = ASC.get("/v1/appStoreVersionLocalizations/#{loc['id']}/appScreenshotSets")["data"]
                  .find { |set| set.dig("attributes", "screenshotDisplayType") == "APP_DESKTOP" }
    preview_set = ASC.get("/v1/appStoreVersionLocalizations/#{loc['id']}/appPreviewSets")["data"]
                     .find { |set| set.dig("attributes", "previewType") == "DESKTOP" }
    abort "#{locale} 缺 APP_DESKTOP 截图集或 DESKTOP 预览集，先在 ASC 里建好" unless shot_set && preview_set
    remote_shots = list_shots.(shot_set["id"])
    remote_previews = list_previews.(preview_set["id"])
    t = files.merge(locale: locale, shot_set: shot_set["id"], preview_set: preview_set["id"],
                    snapshot: (remote_shots + remote_previews).map { |r| r["id"] })

    # 远端条目分三类：
    # - 残留：没有 MD5 的空占位（登记了没传完，或登记的响应丢了），以及 MD5 与本地相同但还没处理完的——第一段开头删掉，不占上限；
    # - 复用：MD5 与某个本地文件相同且已处理完的，逐张复用（上次运行传好的，或线上本来就是同一张图），只传缺的那几张；
    # - 其余都是旧素材，新的传好、处理完以后（第二段）才删。所以第一段失败时，版本页上已处理完的图一张都不会少。
    want = t[:shots].map(&md5)
    stale = remote_shots.select { |shot| checksum.(shot).nil? || (want.include?(checksum.(shot)) && !done.(shot)) }
    t[:reuse] = want.map { |sum| remote_shots.find { |shot| checksum.(shot) == sum && done.(shot) }&.dig("id") }
    t[:old_shots] = remote_shots.map { |shot| shot["id"] } - stale.map { |shot| shot["id"] } - t[:reuse].compact
    want_preview = md5.(t[:preview])
    stale_previews = remote_previews.select { |pv| checksum.(pv).nil? || (checksum.(pv) == want_preview && !done.(pv)) }
    t[:new_preview] = remote_previews.find { |pv| checksum.(pv) == want_preview && done.(pv) }&.dig("id")
    t[:old_previews] = remote_previews.map { |pv| pv["id"] } - stale_previews.map { |pv| pv["id"] } - [t[:new_preview]]
    t[:stale] = stale.map { |shot| ["appScreenshots", shot["id"]] } + stale_previews.map { |pv| ["appPreviews", pv["id"]] }

    shots_to_send = t[:reuse].count(nil)
    previews_to_send = t[:new_preview] ? 0 : 1
    if t[:old_shots].size + shots_to_send > 10 || t[:old_previews].size + previews_to_send > 3
      abort "#{locale}：旧素材 #{t[:old_shots].size} 张截图 / #{t[:old_previews].size} 段视频，先传后删会超出 ASC 上限（10 / 3）"
    end
    notes = []
    notes << "复用已传好的 #{t[:reuse].compact.size} 张截图" unless t[:reuse].compact.empty?
    notes << "复用已传好的视频" if t[:new_preview]
    notes << "先删 #{t[:stale].size} 条没传完的残留" unless t[:stale].empty?
    puts "#{locale}：删旧 #{t[:old_shots].size} 张截图 + #{t[:old_previews].size} 段视频 → " \
         "#{t[:shots].map { |f| File.basename(f) }.join(' ')} + #{File.basename(t[:preview])}" \
         "#{notes.empty? ? '' : "（#{notes.join('；')}）"}"
    t
  end
  puts "Mac #{version['versionString']}（#{version['appStoreState']}）"
  exit if dry

  # 第一段：删残留、传新的、等 Apple 处理完。旧素材此时一张不动。
  # 任何失败（包括 Ctrl-C）都把规划之后新出现在两个集合里的条目删掉——这样连「登记成功、响应丢了」的占位也清得掉
  created = []
  begin
    targets.each do |t|
      t[:stale].each { |type, id| ASC.delete(type, id) }
      t[:new_shots] = t[:shots].zip(t[:reuse]).map do |png, reused|
        reused || ASC.upload("appScreenshots", png, { appScreenshotSet: { data: { type: "appScreenshotSets", id: t[:shot_set] } } })
                     .tap { |id| created << ["appScreenshots", id] }
      end
      t[:new_preview] ||= ASC.upload("appPreviews", t[:preview],
                                     { appPreviewSet: { data: { type: "appPreviewSets", id: t[:preview_set] } } },
                                     { mimeType: "video/mp4" }).tap { |id| created << ["appPreviews", id] }
      puts "#{t[:locale]}：已上传，等 Apple 处理"
    end
    # 复用的都已处理完，只等本次新传的
    created.each do |type, id|
      ASC.wait_delivery(type, id, type == "appPreviews" ? "videoDeliveryState" : "assetDeliveryState")
    end
  rescue Exception => e # rubocop:disable Lint/RescueException -- Ctrl-C 也要先清理
    leftovers = created.dup
    targets.each do |t|
      fresh = list_shots.(t[:shot_set]).map { |r| ["appScreenshots", r["id"]] } +
              list_previews.(t[:preview_set]).map { |r| ["appPreviews", r["id"]] }
      leftovers |= fresh.reject { |_, id| t[:snapshot].include?(id) }
    rescue StandardError
      nil # 列不出来就只按本次记下的删
    end
    left = leftovers.reject do |type, id|
      ASC.delete(type, id)
      true
    rescue Exception # rubocop:disable Lint/RescueException
      false
    end
    abort "#{e.class}：#{e.message}\n" + (left.empty? ? "本次新传的已清理，旧素材还在版本页上" :
          "这几条新传的没清理掉，请到 ASC 删掉，或直接重跑本命令（会把它们当残留删掉）：" \
          "#{left.map { |type, id| "#{type}/#{id}" }.join(' ')}")
  end

  # 第二段：删旧、排序、设海报帧。都可以重试；真失败了重跑本命令，会复用已传好的新素材把这一段补完
  begin
    targets.each do |t|
      t[:old_shots].each { |id| ASC.delete("appScreenshots", id) }
      t[:old_previews].each { |id| ASC.delete("appPreviews", id) }
      ASC.with_retry do
        ASC.request(:patch, "/v1/appScreenshotSets/#{t[:shot_set]}/relationships/appScreenshots",
                    body: { data: t[:new_shots].map { |id| { type: "appScreenshots", id: id } } })
      end
      # 视频转码后海报时间码会被重置成 00:00:05:01，处理完再设回第 1 秒（面板完整浮起的那一帧）
      ASC.with_retry do
        ASC.request(:patch, "/v1/appPreviews/#{t[:new_preview]}", body: { data: {
          type: "appPreviews", id: t[:new_preview], attributes: { previewFrameTimeCode: "00:00:01:00" }
        } })
      end
    end
  rescue Exception => e # rubocop:disable Lint/RescueException
    abort "#{e.class}：#{e.message}\n新素材都已传好、处理完；重跑本命令会直接复用它们，补完删旧、排序和海报帧"
  end

  begin
    targets.each do |t|
      shots = list_shots.(t[:shot_set])
      previews = list_previews.(t[:preview_set])
      unless shots.map(&checksum) == t[:shots].map(&md5)
        abort "#{t[:locale]}：远端截图与本地的顺序或内容对不上：#{shots.map { |shot| shot.dig('attributes', 'fileName') }.join(' ')}"
      end
      unless previews.map(&checksum) == [md5.(t[:preview])] &&
             previews[0].dig("attributes", "previewFrameTimeCode") == "00:00:01:00"
        abort "#{t[:locale]}：远端视频与本地对不上，或海报帧不是 00:00:01:00"
      end
      puts "#{t[:locale]}：#{shots.map { |shot| shot.dig('attributes', 'fileName') }.join(' ')} · " \
           "#{previews[0].dig('attributes', 'fileName')} @#{previews[0].dig('attributes', 'previewFrameTimeCode')}"
    end
  rescue ASC::Error, *ASC::TRANSIENT => e
    abort "替换已经做完，只是最后核对时没读到远端（#{e.class}：#{e.message}）；稍后用 --dry-run 再看一眼即可"
  end
else
  abort "用法：#{$PROGRAM_NAME} builds [IOS|MAC_OS] | version [IOS|MAC_OS] | attach <构建号> | " \
        "review-attachment <文件> | mac-media <素材目录> [--dry-run]"
end
rescue ASC::Error => e
  abort e.message
rescue *ASC::TRANSIENT => e
  abort "网络出错（#{e.class}）：#{e.message}"
end
