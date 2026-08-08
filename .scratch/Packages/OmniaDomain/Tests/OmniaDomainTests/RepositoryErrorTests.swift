import XCTest
@testable import OmniaDomain

final class RepositoryErrorTests: XCTestCase {

    func testStorageUnavailable_IsEqualAcrossInstances() {
        XCTAssertEqual(
            RepositoryError.storageUnavailable,
            RepositoryError.storageUnavailable
        )
    }

    func testSendability_ShareAcrossConcurrencyDomain() async {
        let error = RepositoryError.storageUnavailable
        let returned = await Task.detached {
            error
        }.value
        XCTAssertEqual(returned, RepositoryError.storageUnavailable)
    }
}
