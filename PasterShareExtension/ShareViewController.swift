import UIKit

/// 分享扩展入口。真正的「保存到 Paster」流程由后续实现，
/// 这里先立即结束请求，避免占用分享面板。
final class ShareViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        extensionContext?.completeRequest(returningItems: nil)
    }
}
