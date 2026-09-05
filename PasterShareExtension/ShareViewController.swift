import SwiftData
import SwiftUI
import UIKit

/// 采集通道 B 的入口：系统分享面板里的「保存到 Paster」。
///
/// 类名被 `Info.plist` 的 `NSExtensionPrincipalClass` 引用，改名要同步改 plist。
/// 界面本体是 SwiftUI 的 `ShareView`（在 PasterShared 里，主应用的 `-demoScreen share` 用同一份），
/// 这里只负责三件事：把 SwiftUI 挂上去、把 `extensionContext` 的收尾接上、让背景透出宿主界面。
final class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        let root = ShareRootView(
            items: items,
            onCancel: { [weak self] in self?.cancel() },
            onFinish: { [weak self] in self?.complete() }
        )

        let host = UIHostingController(rootView: root)
        host.view.backgroundColor = .clear
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 系统给的容器视图默认是不透明的，设计 06 要求宿主界面透出来再加暗
        view.superview?.backgroundColor = .clear
    }

    private func cancel() {
        extensionContext?.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain,
                                                           code: NSUserCancelledError))
    }

    private func complete() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}

/// 扩展这一侧的状态壳：读附件、开共享库、把两者喂给 `ShareView`。
private struct ShareRootView: View {
    let items: [NSExtensionItem]
    let onCancel: () -> Void
    let onFinish: () -> Void

    @State private var payload: SharePayload?
    @State private var loadErrorMessage: String?
    @State private var boards: [ShareBoardOption] = []
    @State private var session: ShareSession?
    @State private var sessionError: Error?

    var body: some View {
        ShareView(payload: payload,
                  loadErrorMessage: loadErrorMessage,
                  boards: boards,
                  onCancel: onCancel,
                  onSave: save)
            .task { await prepare() }
    }

    private func prepare() async {
        // 先开库：Pinboard 列表要在面板出现时就是对的，晚一步用户已经在看菜单了
        do {
            let session = try ShareSession()
            self.session = session
            boards = session.boards()
        } catch {
            sessionError = error
            // 开库失败也要立刻上屏。只把错误存着、等用户点了「保存」才弹的话，
            // 面板看起来完全正常，Pinboard 行还会退化成「还没有 Pinboard」——
            // 用户会以为自己真的一个板都没有。
            loadErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        switch await ShareAttachmentLoader.load(from: items) {
        case .payload(let loaded):
            payload = loaded
        case .empty:
            if loadErrorMessage == nil {
                loadErrorMessage = String(localized: "Paster couldn't read what you shared.")
            }
        case .timedOut:
            if loadErrorMessage == nil {
                loadErrorMessage = String(localized: "Timed out reading what you shared.")
            }
        }
    }

    private func save(_ payload: SharePayload, to board: ShareBoardOption?) async throws {
        if let sessionError { throw sessionError }
        guard let session else { throw ClipIngest.IngestError.storeUnavailable }
        try session.save(payload, to: board)
        onFinish()
    }
}

/// 扩展进程自己的那份共享库句柄。主应用有 `AppModel`，这里只需要一个容器加一个上下文。
@MainActor
private final class ShareSession {
    /// 容器要一直被持有：ModelContext 不持有它，容器一释放上下文就废了
    private let container: ModelContainer
    private let context: ModelContext

    init() throws {
        let container = try ClipIngest.makeContainer()
        self.container = container
        self.context = ModelContext(container)
    }

    func boards() -> [ShareBoardOption] {
        ClipIngest.boardOptions(in: context)
    }

    func save(_ payload: SharePayload, to board: ShareBoardOption?) throws {
        try ClipIngest.save(payload, pinboardID: board?.id, in: context)
    }
}
