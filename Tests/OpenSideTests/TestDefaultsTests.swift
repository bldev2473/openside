import XCTest

/// Ephemeral UserDefaults store for tests.
///
/// `removePersistentDomain` only clears the in-memory values and leaves the plist file in `~/Library/Preferences`.
/// Consequently, generating unique store names for each test creates accumulated files on every test run.
///
/// Appends the PID to the suite name. Since `swift test --parallel` launches separate processes per test,
/// identical names would cause tests to overwrite each other's preferences.
///
/// Files are cleaned up after all tests complete. If deleted mid-test, cfprefsd writes cached values back,
/// recreating the file. Since remnants can still occur, cleanup also sweeps files left by terminated processes.
enum TestDefaults {

    static let prefix = "OpenSideTests."

    private static let lock = NSLock()
    private static var names: Set<String> = []

    /// Suite name dedicated to this process.
    static func name(_ label: String) -> String {
        "\(prefix)\(label).\(getpid())"
    }

    /// Opens the store and clears any preexisting values.
    static func open(_ name: String) throws -> UserDefaults {
        register(name)
        let store = try XCTUnwrap(UserDefaults(suiteName: name), "Failed to open \(name) store")
        store.removePersistentDomain(forName: name)
        return store
    }

    /// Clears values. Files are removed after all tests finish.
    static func clear(_ name: String) {
        register(name)
        let store = UserDefaults(suiteName: name)
        store?.removePersistentDomain(forName: name)
        store?.synchronize()
        UserDefaults.standard.removeSuite(named: name)
    }

    /// Removes both values and file.
    static func remove(_ name: String) {
        clear(name)
        removeFile(name)
    }

    /// Removes files of stores opened by this process, as well as files left by terminated processes.
    static func sweep() {
        lock.lock(); let mine = names; lock.unlock()
        mine.forEach(removeFile)
        removeWhatDeadProcessesLeft()
    }

    /// File path used by the store.
    static func path(of name: String) -> String {
        directory + "/\(name).plist"
    }

    static var directory: String { NSHomeDirectory() + "/Library/Preferences" }

    /// Does not touch files of running processes, as they belong to concurrent test runners.
    private static func removeWhatDeadProcessesLeft() {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: directory)) ?? []
        for file in files where file.hasPrefix(prefix) && file.hasSuffix(".plist") {
            guard let owner = pid(inFileNamed: file), !isRunning(owner) else { continue }
            try? FileManager.default.removeItem(atPath: directory + "/" + file)
        }
    }

    /// Process ID appended to the end of the filename. Returns nil if not conforming to our naming scheme.
    static func pid(inFileNamed file: String) -> pid_t? {
        let stem = file.dropLast(".plist".count)
        guard let tail = stem.split(separator: ".").last else { return nil }
        return pid_t(tail)
    }

    private static func isRunning(_ owner: pid_t) -> Bool {
        if owner == getpid() { return true }
        // 0 if alive, ESRCH if not found. EPERM means owned by another user and therefore alive.
        return kill(owner, 0) == 0 || errno != ESRCH
    }

    private static func removeFile(_ name: String) {
        try? FileManager.default.removeItem(atPath: path(of: name))
    }

    private static func register(_ name: String) {
        lock.lock(); names.insert(name); lock.unlock()
        _ = sweeper
    }

    /// Listens for test bundle completion and sweeps files. Attached when a store is first opened.
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

    /// Names must be process-specific to prevent overwriting settings when running in parallel.
    func testTheNameCarriesTheProcessItBelongsTo() {
        let name = TestDefaults.name("NameCheck")
        XCTAssertTrue(name.hasSuffix(".\(getpid())"), "Name is missing process ID: \(name)")
        XCTAssertEqual(TestDefaults.pid(inFileNamed: name + ".plist"), getpid())
    }

    /// Removing the store should delete the file.
    ///
    /// We cannot control when cfprefsd flushes values to disk. Relying on its timing makes
    /// test outcomes flaky, so we manually create a file and verify its deletion.
    func testRemovingDeletesTheFile() throws {
        let name = TestDefaults.name("CleanupCheck")
        let path = TestDefaults.path(of: name)
        FileManager.default.createFile(atPath: path, contents: Data("x".utf8))
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))

        TestDefaults.remove(name)
        XCTAssertFalse(FileManager.default.fileExists(atPath: path), "File remained after removal")
    }

    /// Clearing should leave no values behind.
    func testClearingLeavesNoValue() throws {
        let name = TestDefaults.name("CleanupCheck")
        let store = try TestDefaults.open(name)
        store.set("something", forKey: "key")
        store.synchronize()

        TestDefaults.clear(name)
        XCTAssertNil(UserDefaults(suiteName: name)?.string(forKey: "key"), "Value remained after clearing")
    }

    /// Opening should start empty with no stale values, even when reusing the same suite name.
    func testOpeningStartsEmpty() throws {
        let name = TestDefaults.name("CleanupCheck")
        let first = try TestDefaults.open(name)
        first.set("stale", forKey: "key")
        first.synchronize()

        let second = try TestDefaults.open(name)
        XCTAssertNil(second.string(forKey: "key"), "Stale value remained")
    }

    /// Final sweep must cover every suite opened during the run.
    func testTheSweepCoversEverySuiteOpened() throws {
        let name = TestDefaults.name("SweepCheck")
        _ = try TestDefaults.open(name)
        FileManager.default.createFile(atPath: TestDefaults.path(of: name), contents: Data("x".utf8))

        TestDefaults.sweep()
        XCTAssertFalse(FileManager.default.fileExists(atPath: TestDefaults.path(of: name)),
                       "Opened store was not cleaned up during sweep")
    }

    /// Sweep must collect files left behind by terminated runs to prevent accumulation.
    func testTheSweepCollectsWhatAnEndedRunLeft() throws {
        // PID of an already terminated process. 0 and 1 are alive, so they are not used.
        let dead = TestDefaults.prefix + "Stale.999999"
        let path = TestDefaults.path(of: dead)
        FileManager.default.createFile(atPath: path, contents: Data("x".utf8))

        TestDefaults.sweep()
        XCTAssertFalse(FileManager.default.fileExists(atPath: path),
                       "File left by terminated run was not cleaned up")
    }

    /// Files of currently running processes must not be touched, as they belong to concurrent tests.
    func testTheSweepLeavesALiveProcessAlone() throws {
        let live = TestDefaults.prefix + "Live.\(getppid())"
        let path = TestDefaults.path(of: live)
        FileManager.default.createFile(atPath: path, contents: Data("x".utf8))
        defer { try? FileManager.default.removeItem(atPath: path) }

        TestDefaults.sweep()
        XCTAssertTrue(FileManager.default.fileExists(atPath: path),
                      "File belonging to a running process was deleted")
    }
}
