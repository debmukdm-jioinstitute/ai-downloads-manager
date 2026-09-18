import XCTest
@testable import AIDownloadsManager

final class ExpiryContextClassifierTests: XCTestCase {

    /// The single most important behavior in this feature: a flight date is
    /// an EVENT, not an EXPIRY. Getting this backwards is exactly the mistake
    /// the product spec calls out as unacceptable.
    func testFlightDateIsClassifiedAsEventNotExpiry() {
        let drafts = ExpiryContextClassifier.classify(filename: "eticket.pdf", text: "Flight Date: 20 September 2026", ocrText: nil)
        XCTAssertEqual(drafts.first?.eventType, .eventDate)
        XCTAssertNotEqual(drafts.first?.eventType, .expiry)
    }

    func testPassportValidUntilIsClassifiedAsExpiry() {
        let drafts = ExpiryContextClassifier.classify(filename: "passport_scan.pdf", text: "Passport valid until: 12 March 2027", ocrText: nil)
        XCTAssertEqual(drafts.first?.eventType, .expiry)
        XCTAssertEqual(drafts.first?.category, "Identity")
        XCTAssertTrue(drafts.first?.isExplicit ?? false)
    }

    func testPaymentDueIsClassifiedAsDeadlineNotExpiry() {
        let drafts = ExpiryContextClassifier.classify(filename: "invoice.pdf", text: "Payment due: 30 September 2026", ocrText: nil)
        XCTAssertEqual(drafts.first?.eventType, .dueDate)
        XCTAssertNotEqual(drafts.first?.eventType, .expiry)
    }

    func testPolicyPeriodProducesStartAndEndWithDifferentRoles() {
        let drafts = ExpiryContextClassifier.classify(filename: "insurance_policy.pdf", text: "Policy Period: 01/04/2026 to 31/03/2027", ocrText: nil)
        XCTAssertEqual(drafts.count, 2)
        XCTAssertEqual(drafts[0].eventType, .validFrom)
        XCTAssertTrue([.expiry, .endDate].contains(drafts[1].eventType))
        XCTAssertEqual(drafts[0].category, "Insurance")
    }

    func testDerivedExpiryIsMarkedNotExplicit() {
        let drafts = ExpiryContextClassifier.classify(filename: "warranty.pdf", text: "Issued 15 September 2026. Valid for 12 months from the date of issue.", ocrText: nil)
        guard let derived = drafts.first(where: { $0.isDerived }) else {
            return XCTFail("Expected a derived expiry date")
        }
        XCTAssertFalse(derived.isExplicit)
        XCTAssertEqual(derived.eventType, .expiry)
    }

    func testAmbiguousContextGetsLowConfidenceNotAssertedExpiry() {
        let drafts = ExpiryContextClassifier.classify(filename: "notes.txt", text: "Some random note mentioning 12 March 2027 in passing.", ocrText: nil)
        XCTAssertEqual(drafts.first?.eventType, .eventDate)
        XCTAssertLessThan(drafts.first?.confidence ?? 1.0, ExpiryRecord.reviewConfidenceThreshold)
    }
}
