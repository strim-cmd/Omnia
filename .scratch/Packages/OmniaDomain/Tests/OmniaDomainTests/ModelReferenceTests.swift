import XCTest
@testable import OmniaDomain

final class ModelReferenceTests: XCTestCase {

    func testCreation_ExposesTheModelName() {
        let model = ModelReference(name: "gpt-4o")
        XCTAssertEqual(model.name, "gpt-4o")
    }

    func testEquality_SameNameIsEqual() {
        let a = ModelReference(name: "gpt-4o")
        let b = ModelReference(name: "gpt-4o")
        XCTAssertEqual(a, b)
    }

    func testEquality_DifferentNamesAreNotEqual() {
        let a = ModelReference(name: "gpt-4o")
        let b = ModelReference(name: "gpt-4o-mini")
        XCTAssertNotEqual(a, b)
    }

    func testHashability_EqualReferencesHashEqually() {
        let a = ModelReference(name: "gpt-4o")
        let b = ModelReference(name: "gpt-4o")
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testHashability_SetMembership() {
        let gpt4o = ModelReference(name: "gpt-4o")
        let mini = ModelReference(name: "gpt-4o-mini")
        let set: Set<ModelReference> = [gpt4o, mini, ModelReference(name: "gpt-4o")]
        XCTAssertEqual(set.count, 2)
        XCTAssertTrue(set.contains(gpt4o))
        XCTAssertTrue(set.contains(mini))
    }

    func testImmutability_NameNeverChangesAfterCreation() {
        let model = ModelReference(name: "gpt-4o")
        XCTAssertEqual(model.name, "gpt-4o")
        XCTAssertEqual(model.name, "gpt-4o")
    }
}
