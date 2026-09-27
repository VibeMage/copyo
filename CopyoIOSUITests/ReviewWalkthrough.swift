import XCTest

/// App 审核附件用的演示录像：`scripts/record-review-video.sh` 一边 `simctl io recordVideo`
/// 一边跑这一条。它**不是**回归测试——每步之间故意停一下，好让看录像的人跟得上。
///
/// 走的是审核备注「HOW TO TEST」里的真实路径：全新安装 → 引导 → 在 Safari 里复制文字和图片 →
/// 回到 Copyo 点系统的「允许粘贴」→ 新卡片高亮出现；再从 Safari 的分享菜单存一个链接；
/// 然后轻点复制、长按菜单新建 Pinboard、搜索、设置页。
/// 网页是 `scripts/review-video/index.html`，由脚本在本机起服务，地址经 `REVIEW_PAGE_URL` 传进来。
final class ReviewWalkthrough: XCTestCase {
    private let copyo = XCUIApplication()
    private let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    override func setUp() {
        continueAfterFailure = false
    }

    func testReviewWalkthrough() throws {
        let page = URL(string: ProcessInfo.processInfo.environment["REVIEW_PAGE_URL"] ?? "http://127.0.0.1:8779/")!

        // 从主屏幕点图标启动，录像里能看到这是装在设备上的 App
        XCUIDevice.shared.press(.home)
        pause(1.5)
        // 新装的 App 排在主屏幕后面几页
        let icon = springboard.icons["Copyo"]
        for _ in 0..<4 where !(icon.exists && icon.isHittable) {
            springboard.swipeLeft()
            pause(1)
        }
        try require(icon, "home screen icon")
        pause(1)
        icon.tap()

        // 引导三页
        for _ in 0..<2 {
            try require(copyo.buttons["Continue"], "onboarding Continue")
            pause(2.5)
            copyo.buttons["Continue"].tap()
        }
        try require(copyo.buttons["Get Started"], "onboarding Get Started")
        pause(3)
        copyo.buttons["Get Started"].tap()
        pause(2.5)

        // 1. Safari 里复制一段文字 → 回到 Copyo → 允许粘贴
        XCUIDevice.shared.system.open(page)
        try copyOnPage("Copy meeting point", timeout: 20)
        returnToCopyoAndAllowPaste()
        try require(card(containing: "Tram 28"), "text card")
        pause(3)

        // 2. Safari 里复制图片 → 回到 Copyo。
        //    网页上放了复制按钮，不走长按图片的菜单：模拟器里长按图片时常不出菜单
        safari.activate()
        pause(1)
        safari.webViews.firstMatch.swipeUp()
        pause(1.5)
        try copyOnPage("Copy photo")
        returnToCopyoAndAllowPaste()
        try require(imageCard, "image card")
        pause(3.5)

        // 两次「允许粘贴」之后历史页顶部会出「不想每次都点允许粘贴？」提示，给它一点镜头再关掉
        let dismissTip = copyo.buttons["Dismiss"].firstMatch
        if dismissTip.waitForExistence(timeout: 2) {
            pause(3)
            dismissTip.tap()
            pause(1.5)
        }

        // 3. Safari 里打开链接，用「更多 › 分享」把这页存进 Copyo。
        //    不走长按链接的菜单：那里的网页预览会一直加载，测试要干等一分钟，「分享」还在菜单折叠线以下
        safari.activate()
        pause(1)
        safari.webViews.firstMatch.swipeDown()
        pause(1)
        let link = safari.webViews.links["Lisbon on Wikipedia"]
        try require(link, "web page link")
        link.tap()
        pause(4)
        let more = safari.buttons["MoreMenuButton"]
        try require(more, "Safari More button")
        more.tap()
        pause(1.5)
        try tapMenuItem(in: safari, "Share", "Share…")
        pause(1.5)
        try tapShareTarget("Copyo")
        let save = safari.buttons["Save"]
        try require(save, "share extension Save", timeout: 10)
        pause(3)
        save.tap()
        pause(2)
        copyo.activate()
        try require(card(containing: "wikipedia"), "link card")
        pause(3)

        // 4. 轻点卡片 = 复制
        card(containing: "Tram 28").tap()
        pause(2.5)

        // 5. 长按图片卡 → Pin to… → New Pinboard…
        imageCard.press(forDuration: 1.2)
        pause(2)
        try tapMenuItem(in: copyo, "Pin to…")
        pause(1.2)
        try tapMenuItem(in: copyo, "New Pinboard…")
        let nameField = copyo.alerts.textFields.firstMatch
        try require(nameField, "new pinboard name field")
        nameField.typeText("Lisbon")
        pause(1)
        copyo.alerts.buttons["Create"].tap()
        pause(2.5)

        // 6. Pinboard 标签
        copyo.tabBars.buttons["Pinboard"].tap()
        pause(2)
        let board = copyo.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS 'Lisbon'")).firstMatch
        if board.waitForExistence(timeout: 3) {
            board.tap()
            pause(3)
            copyo.navigationBars.buttons.firstMatch.tap()
            pause(1.5)
        }

        // 7. 搜索
        copyo.tabBars.buttons["History"].tap()
        pause(1.5)
        let search = copyo.searchFields.firstMatch
        if !search.waitForExistence(timeout: 2) {
            copyo.swipeDown()
        }
        try require(search, "search field")
        search.tap()
        pause(1)
        search.typeText("tram")
        pause(3)
        closeSearch(search)
        pause(1.5)

        // 8. 设置
        copyo.tabBars.buttons["Settings"].tap()
        pause(2.5)
        // 设置行的标签是「标题, 副标题」合起来的，按前缀找
        let quickSave = copyo.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Quick Save'")).firstMatch
        if quickSave.waitForExistence(timeout: 2) {
            quickSave.tap()
            pause(3.5)
            copyo.navigationBars.buttons.firstMatch.tap()
            pause(1.5)
        }
        copyo.swipeUp()
        pause(2.5)
        copyo.swipeUp()
        pause(2.5)
        copyo.tabBars.buttons["History"].tap()
        pause(3)
    }

    // MARK: - 小工具

    private func pause(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }

    /// 等元素出现，等不到就带着现场的元素树失败，方便改脚本
    private func require(_ element: XCUIElement, _ what: String, timeout: TimeInterval = 8) throws {
        guard element.waitForExistence(timeout: timeout) else {
            let app = [copyo, safari, springboard].first { $0.state == .runningForeground } ?? copyo
            print("---- \(what) not found; foreground tree ----\n\(app.debugDescription)")
            throw StepMissing(what: what)
        }
    }

    /// 点网页上的复制按钮，等它的无障碍名字变成「Copied」确认复制成功。
    /// 第一次打开 Safari 会冒一个功能提示气泡，第一下点在气泡上只是把它关掉，所以没成功就再点一次
    private func copyOnPage(_ label: String, timeout: TimeInterval = 8) throws {
        let button = safari.webViews.buttons[label]
        try require(button, "web page button \(label)", timeout: timeout)
        pause(2)
        button.tap()
        if !safari.webViews.buttons["Copied"].waitForExistence(timeout: 2) {
            button.tap()
        }
        try require(safari.webViews.buttons["Copied"], "copied confirmation", timeout: 2)
        pause(1)
    }

    /// 收起搜索。iOS 26 起搜索栏右边是个「✕」而不是「取消」，名字随系统版本变，挨个试；
    /// 都找不到就点搜索框右侧紧挨着的位置——✕ 就在那儿
    private func closeSearch(_ search: XCUIElement) {
        for label in ["Cancel", "Close"] {
            let button = copyo.buttons[label].firstMatch
            if button.exists && button.isHittable {
                button.tap()
                return
            }
        }
        search.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5)).withOffset(CGVector(dx: 24, dy: 0)).tap()
    }

    /// 回到 Copyo，点系统的「允许粘贴」。这个框是 SpringBoard 画的，Copyo 的主线程此时正卡在读取上，
    /// 所以只能从 SpringBoard 那边找按钮
    private func returnToCopyoAndAllowPaste() {
        copyo.activate()
        let allow = springboard.buttons["Allow Paste"]
        if allow.waitForExistence(timeout: 8) {
            pause(2)
            allow.tap()
        } else if copyo.buttons["Allow Paste"].waitForExistence(timeout: 2) {
            pause(2)
            copyo.buttons["Allow Paste"].tap()
        }
    }

    /// 图片卡片的标签以「Image, 来源, 时间」开头（`ClipCard.accessibilityDescription`）。
    /// 带上逗号，免得撞上筛选条里的「Images」
    private var imageCard: XCUIElement {
        copyo.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Image,'")).firstMatch
    }

    /// 历史卡片是一个合成的无障碍元素，标签里有正文
    private func card(containing text: String) -> XCUIElement {
        copyo.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
    }

    /// 上下文菜单项在不同系统版本里挂在不同的容器下，按名字挨个找
    private func tapMenuItem(in app: XCUIApplication, _ labels: String...) throws {
        for _ in 0..<10 {
            for label in labels {
                for query in [app.collectionViews.buttons, app.menuItems, app.scrollViews.buttons, app.buttons] {
                    let item = query[label].firstMatch
                    if item.exists && item.isHittable {
                        item.tap()
                        return
                    }
                }
            }
            pause(0.5)
        }
        print("---- menu item \(labels) not found ----\n\(app.debugDescription)")
        throw StepMissing(what: "menu item \(labels)")
    }

    /// 分享面板第一排是 App 图标；新装的扩展可能排在后面，找不到就往左划
    private func tapShareTarget(_ name: String) throws {
        for _ in 0..<4 {
            for query in [safari.cells, safari.buttons, safari.otherElements] {
                let target = query[name].firstMatch
                if target.exists && target.isHittable {
                    pause(1)
                    target.tap()
                    return
                }
            }
            let row = safari.collectionViews.firstMatch
            if row.exists { row.swipeLeft() }
            pause(0.8)
        }
        let more = safari.cells["More"].firstMatch
        if more.exists {
            more.tap()
            pause(1)
            let target = safari.cells[name].firstMatch
            if target.waitForExistence(timeout: 3) {
                target.tap()
                return
            }
        }
        print("---- share target \(name) not found ----\n\(safari.debugDescription)")
        throw StepMissing(what: "share target \(name)")
    }
}

/// 某一步等的元素没出现。抛出去让这条测试失败，脚本据此判定这段录像没走完
private struct StepMissing: Error, CustomStringConvertible {
    let what: String
    var description: String { "missing \(what)" }
}
