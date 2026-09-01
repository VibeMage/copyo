import AppKit
import SwiftUI

/// 单张剪贴板卡片：彩色头部（来源应用）+ 内容预览 + 底部信息。
struct CardView: View {
    let item: ClipItem
    let isSelected: Bool

    static let cardWidth: CGFloat = 224
    static let cardHeight: CGFloat = 268

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(spacing: 0) {
            header
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
            footer
        }
        .frame(width: Self.cardWidth, height: Self.cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.1),
                        lineWidth: isSelected ? 3 : 1)
        )
        .shadow(color: .black.opacity(isSelected ? 0.3 : 0.18), radius: 6, y: 2)
    }

    // MARK: - 头部

    private var headerColor: Color {
        switch item.kind {
        case .color:
            if let color = Color(hexString: item.plainText ?? "") {
                return color
            }
        default:
            break
        }
        return Color(nsColor: AppIconProvider.headerColor(forBundleID: item.sourceAppBundleID))
    }

    private var header: some View {
        ZStack {
            headerColor
            HStack(alignment: .center, spacing: 8) {
                Text(item.sourceAppName ?? String(localized: "Unknown Source"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                Spacer(minLength: 4)
                Image(nsImage: AppIconProvider.icon(forBundleID: item.sourceAppBundleID))
                    .resizable()
                    .frame(width: 24, height: 24)
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            }
            .padding(.horizontal, 10)
        }
        .frame(height: 42)
    }

    // MARK: - 内容

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case .text, .richText:
            textContent
        case .link:
            linkContent
        case .color:
            colorContent
        case .image:
            imageContent
        case .file:
            fileContent
        }
    }

    private var textContent: some View {
        Group {
            if item.kind == .richText,
               let rtf = item.rtfData,
               let attributed = NSAttributedString(rtf: rtf, documentAttributes: nil) {
                Text(AttributedString(attributed))
            } else {
                Text(String((item.plainText ?? "").prefix(400)))
                    .font(.system(size: 12))
                    .foregroundStyle(Color(nsColor: .textColor))
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(10)
        .clipped()
    }

    private var linkContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "link.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(.blue)
            if let url = URL(string: item.plainText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""),
               let host = url.host {
                Text(host)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }
            Text(item.plainText ?? "")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(10)
    }

    private var colorContent: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hexString: item.plainText ?? "") ?? .gray)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text(item.plainText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
        }
        .padding(10)
    }

    private var imageContent: some View {
        Group {
            if let thumbnail = ThumbnailCache.thumbnail(for: item) {
                Image(nsImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 30))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: Self.cardWidth, height: Self.cardHeight - 42 - 26)
        .clipped()
    }

    private var fileContent: some View {
        VStack(spacing: 8) {
            if let firstPath = item.filePaths.first {
                Image(nsImage: NSWorkspace.shared.icon(forFile: firstPath))
                    .resizable()
                    .frame(width: 56, height: 56)
                if item.filePaths.count == 1 {
                    Text((firstPath as NSString).lastPathComponent)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                } else {
                    Text("\(item.filePaths.count) files")
                        .font(.system(size: 12, weight: .medium))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(10)
    }

    // MARK: - 底部信息

    private var footerText: String {
        switch item.kind {
        case .image:
            return item.kind.label
        case .file:
            return String(localized: "\(item.kind.label) · \(item.filePaths.count) files")
        default:
            return String(localized: "\(item.kind.label) · \(item.charCount) characters")
        }
    }

    private var footer: some View {
        HStack {
            Text(footerText)
            Spacer()
            Text(Self.relativeFormatter.localizedString(for: item.createdAt, relativeTo: Date()))
        }
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

extension Color {
    /// 解析 "#RRGGBB" / "#RRGGBBAA"
    init?(hexString: String) {
        let trimmed = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("#") else { return nil }
        let hex = String(trimmed.dropFirst())
        guard hex.count == 6 || hex.count == 8,
              let value = UInt64(hex, radix: 16) else { return nil }
        let r, g, b, a: Double
        if hex.count == 6 {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        } else {
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
