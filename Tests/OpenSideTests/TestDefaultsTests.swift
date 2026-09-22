import XCTest

/// 시험이 쓰고 버리는 UserDefaults 저장소.
///
/// `removePersistentDomain` 은 값만 비우고 `~/Library/Preferences` 의 plist 파일은 남깁니다.
/// 그래서 시험이 저장소 이름을 매번 새로 지으면 돌릴 때마다 파일이 하나씩 쌓입니다.
///
/// 이름에 프로세스 번호를 붙입니다. `swift test --parallel` 은 시험마다 프로세스를 따로
/// 띄우므로, 이름이 같으면 서로의 설정을 덮어씁니다.
///
/// 파일은 시험이 다 끝난 뒤에 치웁니다. 시험 도중에 지우면 cfprefsd 가 아직 들고 있던
/// 값을 그 뒤에 써서 파일이 되살아납니다. 그래도 남는 것이 있으므로, 치울 때 끝난
/// 프로세스가 남긴 파일도 같이 거둡니다.
enum TestDefaults {

    static let prefix = "OpenSideTests."

    private static let lock = NSLock()
    private static var names: Set<String> = []

    /// 이 프로세스만 쓰는 저장소 이름.
    static func name(_ label: String) -> String {
        "\(prefix)\(label).\(getpid())"
    }

    /// 저장소를 열고, 남아 있던 값을 비웁니다.
    static func open(_ name: String) throws -> UserDefaults {
        register(name)
        let store = try XCTUnwrap(UserDefaults(suiteName: name), "\(name) 저장소를 못 열었다")
        store.removePersistentDomain(forName: name)
        return store
    }

    /// 값을 비웁니다. 파일은 시험이 다 끝난 뒤에 치웁니다.
    static func clear(_ name: String) {
        register(name)
        let store = UserDefaults(suiteName: name)
        store?.removePersistentDomain(forName: name)
        store?.synchronize()
        UserDefaults.standard.removeSuite(named: name)
    }

    /// 값과 파일을 모두 치웁니다.
    static func remove(_ name: String) {
        clear(name)
        removeFile(name)
    }

    /// 이 프로세스가 연 저장소의 파일과, 끝난 프로세스가 남긴 파일을 치웁니다.
    static func sweep() {
        lock.lock(); let mine = names; lock.unlock()
        mine.forEach(removeFile)
        removeWhatDeadProcessesLeft()
    }

    /// 그 저장소가 쓰는 파일 위치.
    static func path(of name: String) -> String {
        directory + "/\(name).plist"
    }

    static var directory: String { NSHomeDirectory() + "/Library/Preferences" }

    /// 돌고 있는 프로세스의 파일은 건드리지 않습니다. 병렬로 도는 다른 시험의 것입니다.
    private static func removeWhatDeadProcessesLeft() {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: directory)) ?? []
        for file in files where file.hasPrefix(prefix) && file.hasSuffix(".plist") {
            guard let owner = pid(inFileNamed: file), !isRunning(owner) else { continue }
            try? FileManager.default.removeItem(atPath: directory + "/" + file)
        }
    }

    /// 이름 끝에 붙인 프로세스 번호. 없으면 우리가 지은 이름이 아닙니다.
    static func pid(inFileNamed file: String) -> pid_t? {
        let stem = file.dropLast(".plist".count)
        guard let tail = stem.split(separator: ".").last else { return nil }
        return pid_t(tail)
    }

    private static func isRunning(_ owner: pid_t) -> Bool {
        if owner == getpid() { return true }
        // 살아 있으면 0, 없으면 ESRCH. 남의 것이면 EPERM 이고, 그때는 살아 있는 것입니다.
        return kill(owner, 0) == 0 || errno != ESRCH
    }

    private static func removeFile(_ name: String) {
        try? FileManager.default.removeItem(atPath: path(of: name))
    }

    private static func register(_ name: String) {
        lock.lock(); names.insert(name); lock.unlock()
        _ = sweeper
    }

    /// 시험 묶음이 끝나는 것을 듣고 있다가 치웁니다. 처음 저장소를 열 때 붙습니다.
    private static let sweeper: Sweeper = {
        let observer = Sweeper()
        XCTestObservationCenter.shared.addTestObserver(observer)
        return observer
    }()

    private final class Sweeper: NSObject, XCTestObservation {
        func testBundleDidFinish(_ testBundle: Bundle) {
            TestDefaults.sweep()
        }
    }
}

final class TestDefaultsTests: XCTestCase {

    /// 이름은 프로세스마다 달라야 한다. 병렬로 돌 때 서로의 설정을 덮어쓰면 안 된다.
    func testTheNameCarriesTheProcessItBelongsTo() {
        let name = TestDefaults.name("NameCheck")
        XCTAssertTrue(name.hasSuffix(".\(getpid())"), "이름에 프로세스 번호가 없다: \(name)")
        XCTAssertEqual(TestDefaults.pid(inFileNamed: name + ".plist"), getpid())
    }

    /// 치우면 파일이 사라져야 한다.
    ///
    /// cfprefsd 가 값을 언제 파일로 내려쓸지는 우리가 정하지 못합니다. 그 시점에 기대면
    /// 시험이 돌 때마다 결과가 달라지므로, 파일을 직접 두고 치워지는지만 봅니다.
    func testRemovingDeletesTheFile() throws {
        let name = TestDefaults.name("CleanupCheck")
        let path = TestDefaults.path(of: name)
        FileManager.default.createFile(atPath: path, contents: Data("x".utf8))
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))

        TestDefaults.remove(name)
        XCTAssertFalse(FileManager.default.fileExists(atPath: path), "치운 뒤에도 파일이 남았다")
    }

    /// 비우면 값이 남지 않아야 한다.
    func testClearingLeavesNoValue() throws {
        let name = TestDefaults.name("CleanupCheck")
        let store = try TestDefaults.open(name)
        store.set("something", forKey: "key")
        store.synchronize()

        TestDefaults.clear(name)
        XCTAssertNil(UserDefaults(suiteName: name)?.string(forKey: "key"), "값이 남았다")
    }

    /// 열 때 지난 값이 남아 있으면 안 된다. 같은 이름을 다시 써도 깨끗해야 한다.
    func testOpeningStartsEmpty() throws {
        let name = TestDefaults.name("CleanupCheck")
        let first = try TestDefaults.open(name)
        first.set("stale", forKey: "key")
        first.synchronize()

        let second = try TestDefaults.open(name)
        XCTAssertNil(second.string(forKey: "key"), "지난 값이 남아 있다")
    }

    /// 마지막 치우기는 그동안 연 저장소를 모두 대상으로 해야 한다.
    func testTheSweepCoversEverySuiteOpened() throws {
        let name = TestDefaults.name("SweepCheck")
        _ = try TestDefaults.open(name)
        FileManager.default.createFile(atPath: TestDefaults.path(of: name), contents: Data("x".utf8))

        TestDefaults.sweep()
        XCTAssertFalse(FileManager.default.fileExists(atPath: TestDefaults.path(of: name)),
                       "연 적이 있는 저장소인데 치워지지 않았다")
    }

    /// 지난 실행이 남긴 파일도 거둬야 한다. 그러지 않으면 실행마다 하나씩 쌓인다.
    func testTheSweepCollectsWhatAnEndedRunLeft() throws {
        // 이미 끝난 프로세스의 번호. 0 과 1 은 살아 있으므로 쓰지 않는다.
        let dead = TestDefaults.prefix + "Stale.999999"
        let path = TestDefaults.path(of: dead)
        FileManager.default.createFile(atPath: path, contents: Data("x".utf8))

        TestDefaults.sweep()
        XCTAssertFalse(FileManager.default.fileExists(atPath: path),
                       "끝난 실행이 남긴 파일이 그대로다")
    }

    /// 돌고 있는 프로세스의 파일은 건드리면 안 된다. 병렬로 도는 다른 시험의 것이다.
    func testTheSweepLeavesALiveProcessAlone() throws {
        let live = TestDefaults.prefix + "Live.\(getppid())"
        let path = TestDefaults.path(of: live)
        FileManager.default.createFile(atPath: path, contents: Data("x".utf8))
        defer { try? FileManager.default.removeItem(atPath: path) }

        TestDefaults.sweep()
        XCTAssertTrue(FileManager.default.fileExists(atPath: path),
                      "돌고 있는 프로세스의 파일을 지웠다")
    }
}
