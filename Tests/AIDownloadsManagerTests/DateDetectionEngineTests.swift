import XCTest
@testable import AIDownloadsManager

final class DateDetectionEngineTests: XCTestCase {

    private func iso(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    func testAllSpecFormatsParseToTheSameDate() {
        let expected = "2027-03-31"
        let samples = [
            "31/03/2027", "31-03-2027", "31.03.2027",
            "March 31, 2027", "31 March 2027", "Mar 31 2027",
            "2027-03-31", "Valid through 31 March 2027", "Valid until 31 March 2027",
            "Expires 31/03/27", "Expiry: 03/31/2027"
        ]
        for sample in samples {
            let candidates = DateDetectionEngine.detectDates(in: sample)
            XCTAssertFalse(candidates.isEmpty, "No date found in: \(sample)")
            XCTAssertEqual(candidates.first.map { iso($0.date) }, expected, "Wrong date for: \(sample)")
        }
    }

    /// Regression test for the exact bug found during development: NSDataDetector
    /// silently resolved "valid until <date>" phrases to *today's date* instead of
    /// the stated date. This must never regress back to that behavior.
    func testValidUntilPhraseDoesNotResolveToToday() {
        let candidates = DateDetectionEngine.detectDates(in: "Passport valid until: 12 March 2027")
        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(iso(candidates[0].date), "2027-03-12")
        XCTAssertNotEqual(candidates[0].date, Calendar.current.startOfDay(for: Date()))
    }

    /// Regression test: a "X to Y" range must yield BOTH dates, not collapse
    /// to just the start (losing the expiry/end date, the one that matters most).
    func testPolicyPeriodYieldsBothStartAndEndDates() {
        let candidates = DateDetectionEngine.detectDates(in: "Policy Period: 01/04/2026 to 31/03/2027")
        XCTAssertEqual(candidates.count, 2)
        XCTAssertEqual(iso(candidates[0].date), "2026-04-01")
        XCTAssertEqual(iso(candidates[1].date), "2027-03-31")
    }

    func testUSStyleMonthFirstWhenSecondComponentExceedsTwelve() {
        // 03/31/2027: second component (31) can't be a month, so it must be MM/DD.
        let candidates = DateDetectionEngine.detectDates(in: "Expiry: 03/31/2027")
        XCTAssertEqual(candidates.first.map { iso($0.date) }, "2027-03-31")
    }

    func testTwoDigitYearExpansion() {
        let candidates = DateDetectionEngine.detectDates(in: "Expires 31/03/27")
        XCTAssertEqual(candidates.first.map { iso($0.date) }, "2027-03-31")
    }

    func testValidityDurationPhrase() {
        let result = DateDetectionEngine.detectValidityDuration(in: "Valid for 12 months from the date of issue.")
        XCTAssertEqual(result?.months, 12)
    }

    func testNoFalsePositiveOnPlainText() {
        let candidates = DateDetectionEngine.detectDates(in: "This is just a normal sentence with no dates in it.")
        XCTAssertTrue(candidates.isEmpty)
    }

    /// Regression test: `Calendar.date(from:)` silently rolls invalid
    /// day-in-month combinations forward (verified: Feb 30 2027 -> Mar 2
    /// 2027) instead of rejecting them. An OCR misread or typo must never
    /// become a confidently-wrong expiry date.
    func testInvalidCalendarDatesAreRejectedNotNormalized() {
        XCTAssertTrue(DateDetectionEngine.detectDates(in: "Expires 30/02/2027").isEmpty, "Feb 30 is not a real date")
        XCTAssertTrue(DateDetectionEngine.detectDates(in: "Expires 31/04/2027").isEmpty, "April 31 is not a real date")
    }
}
