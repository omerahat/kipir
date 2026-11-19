import XCTest
#if SWIFT_PACKAGE
@testable import KipirCore
#endif

/// Natural-break, working-hours and reliability tests (scheduler workstream).
final class NaturalBreakTests: XCTestCase {
    typealias Clock = BreakSchedulerTests.Clock
}
