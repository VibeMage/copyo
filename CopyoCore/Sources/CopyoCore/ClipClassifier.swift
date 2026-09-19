import Foundation

/// 文本内容分类：判断复制来的文本属于哪种条目类型。
public enum ClipClassifier {
    public static func classify(text: String, hasRTF: Bool) -> ClipKind {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.range(of: "^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$", options: .regularExpression) != nil {
            return .color
        }
        if !trimmed.contains(where: \.isWhitespace),
           let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return .link
        }
        return hasRTF ? .richText : .text
    }

    // MARK: - 代码 / 命令识别

    /// 界面据此把内容改用等宽字体显示。判断刻意保守：
    /// 宁可把一段代码当成普通文本（只是字体不同），也不要把中英文散文渲染成等宽。
    ///
    /// 做法是「强信号一条即可、弱信号需要两条」，而不是给每种语言写语法规则——
    /// 剪贴板里的内容大多是片段，本来就语法不完整。
    public static func looksLikeCode(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        // 剪贴板里可能是几十 KB 的源文件，判断只看开头够用
        let head = String(trimmed.prefix(4_000))
        let rawLines = head.split(separator: "\n", omittingEmptySubsequences: false).prefix(40).map(String.init)
        let lines = rawLines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !lines.isEmpty else { return false }

        if lines.contains(where: isShellCommandLine) { return true }
        if lines.contains(where: isDeclarationLine) { return true }
        if isStructuredData(head, lines: lines) { return true }

        var weakSignals = 0
        if head.contains(" && ") || head.contains(" || ") { weakSignals += 1 }
        if head.range(of: "(^|\\s)--[A-Za-z][A-Za-z0-9-]+", options: .regularExpression) != nil { weakSignals += 1 }
        if lines.filter({ $0.hasSuffix(";") }).count >= 2 { weakSignals += 1 }
        if head.range(of: "(^|\\s)(=>|->|::|\\+=|!==|===)(\\s|$)", options: .regularExpression) != nil { weakSignals += 1 }
        // 连续缩进的行是代码块的典型形状；单行内容不参与这条
        if rawLines.count >= 3 {
            let indented = rawLines.filter { $0.hasPrefix("    ") || $0.hasPrefix("\t") }.count
            if Double(indented) / Double(rawLines.count) >= 0.4 { weakSignals += 1 }
        }
        return weakSignals >= 2
    }

    /// 行首出现就几乎不可能是自然语言的命令
    private static let unambiguousCommands: Set<String> = [
        "git", "npm", "npx", "pnpm", "yarn", "bun", "brew", "xcodebuild", "xcrun", "swiftc",
        "curl", "wget", "ssh", "scp", "rsync", "docker", "docker-compose", "kubectl", "helm",
        "gradle", "adb", "cargo", "rustc", "pip", "pip3", "python3", "ruby", "bundle",
        "sudo", "chmod", "chown", "codesign", "launchctl", "plutil", "systemctl", "apt-get",
        "unzip", "xargs", "pbcopy", "pbpaste", "simctl", "gh", "tsc", "eslint",
    ]

    /// 同时也是常见英文单词的命令：必须带上像路径 / 参数 / 子命令的第二个词才算数
    private static let ambiguousCommands: Set<String> = [
        "cd", "ls", "cat", "grep", "rg", "find", "rm", "cp", "mv", "mkdir", "touch", "echo",
        "open", "make", "go", "node", "python", "swift", "tar", "sed", "awk", "kill", "which",
        "pod", "ping", "top", "less", "head", "tail", "diff", "man",
    ]

    private static let commandSubcommands: Set<String> = [
        "build", "test", "run", "install", "uninstall", "clean", "start", "stop", "init", "update", "upgrade",
    ]

    private static func isShellCommandLine(_ line: String) -> Bool {
        // 复制命令时常把提示符一起带上
        var body = line
        for prompt in ["$ ", "% ", "> ", "❯ ", "# "] where body.hasPrefix(prompt) {
            body = String(body.dropFirst(prompt.count))
            break
        }
        let tokens = body.split(separator: " ").map(String.init)
        guard let command = tokens.first?.lowercased() else { return false }

        if unambiguousCommands.contains(command) { return true }
        guard ambiguousCommands.contains(command), tokens.count >= 2 else { return false }

        let argument = tokens[1]
        if argument.hasPrefix("-") || argument.hasPrefix("/") || argument.hasPrefix("~")
            || argument.hasPrefix("./") || argument.contains("/") || argument == "*" {
            return true
        }
        if commandSubcommands.contains(argument.lowercased()) { return true }
        // 形如 main.go / Package.swift 的文件名
        return argument.range(of: "^[A-Za-z0-9_.-]+\\.[A-Za-z0-9]{1,5}$", options: .regularExpression) != nil
    }

    /// 行首的声明语句：函数、类型、导入、带等号的变量绑定
    private static func isDeclarationLine(_ line: String) -> Bool {
        let patterns = [
            "^(public |private |internal |fileprivate |open |static |final |export |default |async )*(func|fn|def|class|struct|enum|protocol|interface|extension|impl|trait|namespace|module)\\s+[A-Za-z_]",
            "^(import|from|package|using|require|#include|#import|#!|@interface|@implementation)\\b",
            "^(let|var|const|val|my)\\s+[A-Za-z_$][A-Za-z0-9_$]*\\s*(:\\s*[A-Za-z_\\[][^=]*)?=",
            "^(if|while|for|switch|catch)\\s*\\(",
            "^(if|guard)\\s+(let|var)\\s+[A-Za-z_]",
            "^</?[a-zA-Z][a-zA-Z0-9-]*(\\s|>|/>)",
            "^<\\?(xml|php)",
        ]
        return patterns.contains { line.range(of: $0, options: .regularExpression) != nil }
    }

    /// JSON / 对象字面量：以括号开头结尾，且里面有键值对
    private static func isStructuredData(_ head: String, lines: [String]) -> Bool {
        guard let first = lines.first, let last = lines.last else { return false }
        let bracketed = (first.hasPrefix("{") && last.hasSuffix("}")) || (first.hasPrefix("[") && last.hasSuffix("]"))
        guard bracketed else { return false }
        return head.range(of: "\"[^\"]+\"\\s*:", options: .regularExpression) != nil
            || head.range(of: "[A-Za-z_][A-Za-z0-9_]*\\s*:\\s*", options: .regularExpression) != nil
    }
}
