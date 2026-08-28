import AppKit
import SwiftUI

/// 按空格键弹出的大图预览（类似 Quick Look）。
struct PreviewOverlay: View {
    let item: ClipItem
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onClose() }
            VStack(spacing: 0) {
                previewContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                footerBar
            }
            .frame(width: 680, height: 320)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.primary.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 18, y: 6)
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        switch item.kind {
        case .image:
            if let data = item.imageData, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(12)
            }
        case .color:
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hexString: item.plainText ?? "") ?? .gray)
                .padding(16)
        case .file:
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(item.filePaths, id: \.self) { path in
                        HStack(spacing: 8) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                                .resizable()
                                .frame(width: 20, height: 20)
                            Text(path)
                                .font(.system(size: 12, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
            }
        default:
            ScrollView {
                Group {
                    if item.kind == .richText,
                       let rtf = item.rtfData,
                       let attributed = NSAttributedString(rtf: rtf, documentAttributes: nil) {
                        Text(AttributedString(attributed))
                    } else {
                        Text(item.plainText ?? "")
                            .font(.system(size: 13))
                    }
                }
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(14)
            }
        }
    }

    private var footerBar: some View {
        HStack {
            Text(item.sourceAppName ?? "未知来源")
            Spacer()
            Text("\(item.kind.label)\(item.kind == .image || item.kind == .file ? "" : " · \(item.charCount) 字符")")
            Spacer()
            Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .frame(height: 30)
        .background(Color.primary.opacity(0.05))
    }
}
