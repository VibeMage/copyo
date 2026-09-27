import AppKit
import os

/// 后台加载的公共骨架：卡片缩略图、预览大图、来源 App 图标、文件类型图标四处共用
/// （design-spec 7.5.18 对 7.5.5 的拍板：「`NSWorkspace.icon` 移出 view body，异步 + 缓存」；
/// 读 externalStorage 与解码同理）。
///
/// 缓存本身归各自的调用方，这里只管三件事：
/// - **去重**：同一 key 已经在排队或在跑，后来的请求搭同一趟车，不再读第二遍盘、解第二遍码；
/// - **限流**：同时在后台跑的不超过 `maxConcurrent` 个，其余按先来后到排队；
/// - **撤销**：请求方（卡片的 `.task`、预热）被取消时撤回兴趣。一个 key 没人要了、又还没开跑，就直接从队里拿掉；
///   已经开跑的不打断——读盘解码是一段同步调用，停不下来，跑完的结果照样交给 `commit` 进缓存，下次用得上。
///
/// 全部状态只在主线程上动，不需要锁（唯一的例外是每个请求方的「已取消」标记，见 `CancellationFlag`）。
/// 真正的活（`work`）在 `BackgroundWork` 的队列上跑，所以 `work` 只能捕获 Sendable 的值
/// （持久化 ID、ModelContainer、字符串），产出也必须是 Sendable。
@MainActor
final class BackgroundLoadQueue<Key: Hashable & Sendable, Output: Sendable> {
    @MainActor
    private final class Job {
        /// 每个请求方一枚「已取消」标记。开跑前在主线程上同步查一遍：一个都没剩下就不跑
        var requesters: [CancellationFlag] = []
        /// 已经拿到并发名额、开始干活了：从这一刻起不再撤销
        var started = false
        /// 没人要了、在开跑之前被撤掉
        var abandoned = false
        var task: Task<Output?, Never>?

        var isWanted: Bool { requesters.contains { !$0.isSet } }
    }

    private struct Waiter {
        let job: Job
        let continuation: CheckedContinuation<Bool, Never>
    }

    private let maxConcurrent: Int
    private var running = 0
    private var waiters: [Waiter] = []
    private var jobs: [Key: Job] = [:]

    init(maxConcurrent: Int) {
        self.maxConcurrent = maxConcurrent
    }

    /// 取 `key` 的结果。已经在途就搭车，否则排队；返回 nil 表示在开跑之前就被撤掉了（或者进来时就已经被取消）。
    ///
    /// `work` 在后台跑；`commit` 回到主线程收尾（写缓存），每一趟只调一次，而且是在所有搭车的请求方拿到结果之前。
    /// 搭车的请求方传进来的 `work` / `commit` 不用：同一个 key 的活与收尾本来就是同一件事。
    func load(_ key: Key,
              work: @escaping @Sendable () -> Output,
              commit: @escaping @MainActor (Output) -> Void) async -> Output? {
        // 进来时就已经被取消（预热的 task group 刚排上就被撤、卡片刚上屏就离屏）：不开新车、也不搭车，什么都不跑
        guard !Task.isCancelled else { return nil }
        let job = jobs[key] ?? start(key, work: work, commit: commit)
        let cancelled = CancellationFlag()
        job.requesters.append(cancelled)
        return await withTaskCancellationHandler {
            await job.task?.value ?? nil
        } onCancel: {
            // 取消回调在取消方所在的线程上同步执行：标记当场记下，作业开跑前一定看得到；
            // 已经在排队的，再跳回主线程把它从队里拿掉、让出排队位置
            cancelled.set()
            Task { @MainActor in self.dropInterest(in: job, key: key) }
        }
    }

    /// 不再让新的请求搭已有的车（`removeAll` 用）。已经在途的、还在排队的都照常跑完，结果照样交给各自的请求方，
    /// `commit` 也照调；写不写回缓存由调用方在 `commit` 里自己定。ThumbnailCache 用的是请求发起时记下的代际，
    /// 所以清空之后才开跑的那些也算旧的，一律不写回（缺图的重试登记除外）。
    func detachAll() {
        jobs.removeAll()
    }

    private func start(_ key: Key,
                       work: @escaping @Sendable () -> Output,
                       commit: @escaping @MainActor (Output) -> Void) -> Job {
        let job = Job()
        jobs[key] = job
        job.task = Task {
            defer {
                // 撤掉或 detachAll 之后，同一个 key 可能已经换了一趟新的车，别把它从表里摘掉
                if jobs[key] === job { jobs[key] = nil }
            }
            guard await acquireSlot(for: job) else { return nil }
            defer { releaseSlot() }
            job.started = true
            let output = await BackgroundWork.run(work)
            commit(output)
            return output
        }
        return job
    }

    private func acquireSlot(for job: Job) async -> Bool {
        if abandonIfUnwanted(job) { return false }
        if running < maxConcurrent {
            running += 1
            return true
        }
        let granted = await withCheckedContinuation { continuation in
            waiters.append(Waiter(job: job, continuation: continuation))
        }
        guard granted else { return false }
        // 名额已经让给它、它还没醒过来的那一瞬间请求方都走了：名额还回去
        if abandonIfUnwanted(job) {
            releaseSlot()
            return false
        }
        return true
    }

    /// 开跑前的最后一道关：请求方全都取消了就撤掉。
    /// 不能只靠 `dropInterest`——它要异步跳回主线程，可能排在作业自己那一跳后面，等它到了作业已经开跑
    private func abandonIfUnwanted(_ job: Job) -> Bool {
        if !job.abandoned && !job.isWanted { job.abandoned = true }
        return job.abandoned
    }

    private func releaseSlot() {
        running -= 1
        guard !waiters.isEmpty else { return }
        let next = waiters.removeFirst()
        running += 1
        next.continuation.resume(returning: true)
    }

    /// 某个请求方被取消。没人要了、还没开跑的直接撤掉，让出排队位置；已经开跑的让它跑完
    private func dropInterest(in job: Job, key: Key) {
        guard !job.isWanted, !job.started, !job.abandoned else { return }
        job.abandoned = true
        if jobs[key] === job { jobs[key] = nil }
        if let index = waiters.firstIndex(where: { $0.job === job }) {
            waiters.remove(at: index).continuation.resume(returning: false)
        }
    }
}

/// 一个请求方的「已取消」。取消回调可能在任何线程上同步触发，用锁记下；读在主线程上
private final class CancellationFlag: Sendable {
    private let state = OSAllocatedUnfairLock(initialState: false)

    var isSet: Bool { state.withLock { $0 } }

    func set() {
        state.withLock { $0 = true }
    }
}

/// 真正干活的地方：一条并发的 GCD 队列。读盘、解码、LaunchServices 查询都是会阻塞的同步调用，
/// 放在 GCD 上而不是 Swift 并发的协作线程池里，不去占那几条本该一直能跑的线程；
/// 同时跑几个由各个 `BackgroundLoadQueue` 的上限管。
enum BackgroundWork {
    private static let queue = DispatchQueue(label: "dev.vibemage.Copyo.background-load",
                                             qos: .userInitiated,
                                             attributes: .concurrent)

    static func run<Output: Sendable>(_ work: @escaping @Sendable () -> Output) async -> Output {
        await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: work()) }
        }
    }
}

/// NSImage 不是 Sendable。后台线程上取出来的图标交给主线程之后，后台那边不再留引用、也不再碰它——
/// 所有权是整体移交的，用这个盒子把「移交」标出来。只许这样用：装进去以后，造它的那一侧不能再持有这张图。
struct TransferredImage: @unchecked Sendable {
    let image: NSImage
}

/// `NSWorkspace.icon` 给的图标只带惰性的 `NSISIconImageRep`：真正的 IconServices 栅格化要等第一次画它时才做。
/// 只把 LaunchServices 查询与 `NSWorkspace.icon` 挪到后台（7.5.5）还不够——栅格化才是大头，
/// 照样会落在主线程上卡片第一次画图标的那一帧。实测十个 App 图标冷缓存下主线程首帧合计 60–120ms，
/// 后台先按显示尺寸画过一次之后降到 8–19ms。
///
/// 所以后台取到图标之后、交给主线程之前，按实际显示的尺寸与屏幕像素密度各先栅格化一次，结果留在图标自己的 rep 里。
/// 交出去的仍是原来那个多表示 NSImage，1x 屏与别的尺寸的观感都不变，主线程第一次画时只是取现成的。
enum IconPrerender {
    /// 缓存里的图标都已经预渲染过的像素密度：各次加载所用那一组的交集。还没加载过时为 nil
    @MainActor private static var covered: Set<CGFloat>?
    @MainActor private static var refreshers: [@MainActor ([CGFloat]) -> Void] = []
    @MainActor private static var screenObserver: NSObjectProtocol?

    /// 主线程上读：现在接着的各块屏幕的像素密度（去重），交给这一次加载去预渲染。
    /// 面板会出现在哪块屏上事先不知道，已接的每档都备一份；之后才接上的屏见 `onNewScales`
    @MainActor
    static func currentScales() -> [CGFloat] {
        let scales = connectedScales()
        covered = covered.map { $0.intersection(scales) } ?? Set(scales)
        return scales
    }

    /// 图标缓存在第一次加载时登记「按新的一组像素密度重取」。菜单栏 App 一开好几天，期间接上或换成像素密度不同的屏
    /// （Retina 笔记本插上 1x 外接屏）后，缓存里的图标只备了加载当时那几档，新屏上第一次画每个图标，
    /// 栅格化又会落回主线程（实测 153 个 App 图标只备 2x、按 1x 画，主线程合计约 1.5s；两档都备时 16ms）。
    /// 所以屏幕参数一变、出现了还没备过的一档，就让各缓存在后台按新的一组重取一份，回主线程换掉旧的
    @MainActor
    static func onNewScales(_ refresh: @escaping @MainActor ([CGFloat]) -> Void) {
        refreshers.append(refresh)
        guard screenObserver == nil else { return }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { screensChanged() }
        }
    }

    /// 分辨率、排列变了也会来这条通知；只有出现了缓存还没备过的一档才重取
    @MainActor
    private static func screensChanged() {
        let scales = connectedScales()
        guard let covered, !Set(scales).isSubset(of: covered) else { return }
        self.covered = Set(scales)
        for refresh in refreshers { refresh(scales) }
    }

    @MainActor
    private static func connectedScales() -> [CGFloat] {
        let scales = Set(NSScreen.screens.map(\.backingScaleFactor))
        return scales.isEmpty ? [2] : scales.sorted()
    }

    /// 后台线程上调，而且只能在图标交给主线程之前调（见 `TransferredImage`）
    static func warm(_ image: NSImage, pointSizes: [CGFloat], scales: [CGFloat]) {
        for size in pointSizes {
            for scale in scales {
                var rect = NSRect(x: 0, y: 0, width: size, height: size)
                _ = image.cgImage(forProposedRect: &rect, context: nil,
                                  hints: [.ctm: AffineTransform(scale: scale)])
            }
        }
    }
}
