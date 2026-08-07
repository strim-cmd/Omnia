import Foundation
import XCTest
import OmniaDomain
@testable import OmniaInfrastructure

/// A Codable document used to exercise the store. It mirrors the shape a
/// serializer DTO will take: plain stored data with no business meaning.
private struct StoredDocument: Codable, Equatable, Sendable {
    var title: String
    var count: Int
    var tags: [String]
}

final class JSONDocumentStoreTests: XCTestCase {

    private var directoryURL: URL!

    override func setUp() {
        super.setUp()
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("JSONDocumentStoreTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directoryURL)
        directoryURL = nil
        super.tearDown()
    }

    private func makeStore() -> JSONDocumentStore {
        JSONDocumentStore(directoryURL: directoryURL)
    }

    // MARK: - Save / Load round-trip

    func testSaveThenLoad_RoundTripsTheDocument() throws {
        let store = makeStore()
        let document = StoredDocument(title: "Workspace", count: 3, tags: ["a", "b"])

        try store.save(document, key: "workspace-1")
        let loaded: StoredDocument? = try store.load(key: "workspace-1")

        XCTAssertEqual(loaded, document)
    }

    func testSave_ReplacesExistingDocumentWithSameKey() throws {
        let store = makeStore()
        try store.save(StoredDocument(title: "old", count: 1, tags: []), key: "key")
        try store.save(StoredDocument(title: "new", count: 2, tags: ["x"]), key: "key")

        let loaded: StoredDocument? = try store.load(key: "key")

        XCTAssertEqual(loaded?.title, "new")
        XCTAssertEqual(loaded?.count, 2)
        XCTAssertEqual(loaded?.tags, ["x"])
    }

    // MARK: - Load absent

    func testLoad_AbsentKeyReturnsNil() throws {
        let store = makeStore()

        let loaded: StoredDocument? = try store.load(key: "absent")

        XCTAssertNil(loaded)
    }

    func testLoad_DifferentKeysAreIsolated() throws {
        let store = makeStore()
        try store.save(StoredDocument(title: "one", count: 1, tags: []), key: "one")

        let loaded: StoredDocument? = try store.load(key: "two")

        XCTAssertNil(loaded)
    }

    // MARK: - Delete

    func testDelete_RemovesTheDocument() throws {
        let store = makeStore()
        try store.save(StoredDocument(title: "gone", count: 1, tags: []), key: "key")

        try store.delete(key: "key")

        let loaded: StoredDocument? = try store.load(key: "key")
        XCTAssertNil(loaded)
        XCTAssertEqual(try store.allKeys(), [])
    }

    func testDelete_AbsentKeyIsNotAnError() throws {
        let store = makeStore()

        try store.delete(key: "never-stored")

        XCTAssertEqual(try store.allKeys(), [])
    }

    func testDelete_IsIdempotent() throws {
        let store = makeStore()
        try store.save(StoredDocument(title: "gone", count: 1, tags: []), key: "key")

        try store.delete(key: "key")
        try store.delete(key: "key")

        let loaded: StoredDocument? = try store.load(key: "key")
        XCTAssertNil(loaded)
    }

    // MARK: - List

    func testAllKeys_ReturnsEveryStoredKey() throws {
        let store = makeStore()
        try store.save(StoredDocument(title: "a", count: 1, tags: []), key: "alpha")
        try store.save(StoredDocument(title: "b", count: 2, tags: []), key: "beta")
        try store.save(StoredDocument(title: "c", count: 3, tags: []), key: "gamma")

        let keys = try store.allKeys()

        XCTAssertEqual(Set(keys), Set(["alpha", "beta", "gamma"]))
    }

    func testAllKeys_EmptyStoreReturnsEmpty() throws {
        let store = makeStore()

        let keys = try store.allKeys()

        XCTAssertTrue(keys.isEmpty)
    }

    // MARK: - Storage-error translation

    func testSave_WhenDirectoryCannotBeReached_ThrowsStorageUnavailable() {
        let blockingFileURL = directoryURL.appendingPathComponent("blocking-file")
        try? Data("not a directory".utf8).write(to: blockingFileURL)
        let store = JSONDocumentStore(directoryURL: blockingFileURL)

        XCTAssertThrowsError(try store.save(StoredDocument(title: "x", count: 1, tags: []), key: "key")) { error in
            XCTAssertEqual(error as? RepositoryError, .storageUnavailable)
        }
    }

    func testLoad_WhenDocumentIsCorrupt_ThrowsStorageUnavailable() throws {
        let store = makeStore()
        let corruptURL = directoryURL.appendingPathComponent("corrupt").appendingPathExtension("json")
        try Data("{ not valid json".utf8).write(to: corruptURL)

        XCTAssertThrowsError(try store.load(key: "corrupt") as StoredDocument?) { error in
            XCTAssertEqual(error as? RepositoryError, .storageUnavailable)
        }
    }
}
