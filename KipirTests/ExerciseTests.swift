import XCTest
#if SWIFT_PACKAGE
@testable import KipirCore
#endif

/// Exercise catalog, rotation and playback tests (exercise workstream).
final class ExerciseTests: XCTestCase {
    typealias Clock = BreakSchedulerTests.Clock
    func testVisualClockFreezesAndResumesWithoutJump() {
        var clock = ExerciseVisualClock(offset: 7.25, anchor: 100, running: true)
        XCTAssertEqual(clock.time(at: 102.5), 9.75, accuracy: 0.0001)
        clock.setRunning(false, at: 102.5)
        XCTAssertEqual(clock.time(at: 300), 9.75, accuracy: 0.0001)
        clock.setRunning(true, at: 300)
        XCTAssertEqual(clock.time(at: 300), 9.75, accuracy: 0.0001)
        XCTAssertEqual(clock.time(at: 300.5), 10.25, accuracy: 0.0001)
    }
    func testExerciseCatalogOrderAndDurations() {
        let short = ExerciseCatalog.sequence(long: false, duration: 120)
        XCTAssertEqual(short.map(\.id), [.shoulders, .chest, .wrists, .calves])
        XCTAssertEqual(short.map(\.duration), [30, 30, 30, 30])
        let long = ExerciseCatalog.sequence(long: true, duration: 300)
        XCTAssertEqual(long.last?.id, .walk)
        XCTAssertEqual(long.map(\.duration), [30, 30, 30, 30, 180])
    }
    func testExerciseAdvanceAndNavigation() {
        var sequence = ExerciseSequenceController(long: false, duration: 120)
        sequence.advance(31); XCTAssertEqual(sequence.index, 1); XCTAssertEqual(sequence.remaining, 29)
        sequence.navigate(1); XCTAssertEqual(sequence.index, 2); XCTAssertEqual(sequence.remaining, 30)
        sequence.navigate(-1); XCTAssertEqual(sequence.index, 1)
        sequence.advance(.nan); XCTAssertEqual(sequence.remaining, 30)
        sequence.advance(1000); XCTAssertEqual(sequence.index, 3); XCTAssertEqual(sequence.remaining, 0)
    }
    func testExerciseIntegrationAFKPauseSleepAndCompletion() {
        let c = Clock(); let e = c.engine(); e.perform(.startBreak)
        c.step(e, seconds: 35, input: false)
        XCTAssertEqual(e.exercises?.index, 1); XCTAssertEqual(e.exercises?.remaining, 25)
        e.perform(.togglePause); c.step(e, seconds: 40, input: false)
        XCTAssertEqual(e.exercises?.remaining, 25)
        e.perform(.togglePause); e.setSuspended(true); c.step(e, seconds: 100)
        e.setSuspended(false); XCTAssertEqual(e.exercises?.remaining, 25)
        e.navigateExercise(1); XCTAssertEqual(e.remaining, 85)
        c.step(e, seconds: 85, input: false)
        XCTAssertNil(e.exercises); XCTAssertEqual(e.today.breaks, 1)
        c.step(e); XCTAssertEqual(e.today.breaks, 1)
    }
    func testExerciseMeetingFreezesAndNavigationRestartsSelection() {
        let c = Clock(); let e = c.engine(); e.perform(.startBreak)
        c.step(e, seconds: 8)
        let remaining = e.remaining
        let elapsed = e.exercises?.elapsed
        e.perform(.toggleMeeting); c.step(e, seconds: 20)
        XCTAssertEqual(e.remaining, remaining)
        XCTAssertEqual(e.exercises?.elapsed, elapsed)
        e.perform(.toggleMeeting); c.step(e, seconds: 2)
        XCTAssertEqual(e.exercises?.elapsed, 10)
        e.navigateExercise(1)
        XCTAssertEqual(e.exercises?.current.id, .chest)
        XCTAssertEqual(e.exercises?.elapsed, 0)
    }
    func testManualFinishDoesNotCreditCompletedBreak() {
        let c = Clock(); let e = c.engine(); e.perform(.startBreak)
        e.navigateExercise(1); e.perform(.skip)
        XCTAssertNil(e.exercises); XCTAssertEqual(e.today.breaks, 0); XCTAssertEqual(e.activeWork, 0)
    }
    func testExerciseRestoreUsesConfirmedBreakElapsed() {
        let c = Clock(); let e = c.engine(); e.perform(.startBreak); c.step(e, seconds: 35)
        let restored = c.engine(checkpoint: e.checkpoint)
        XCTAssertEqual(restored.exercises?.index, 1); XCTAssertEqual(restored.exercises?.remaining, 25)
    }
    func testLongGuideWalksAndCompletesWhileAFK() {
        let c = Clock(); var settings = Settings(); settings.longEvery = 1
        let e = c.engine(settings); e.perform(.startBreak)
        c.step(e, seconds: 120, input: false); XCTAssertEqual(e.today.breaks, 1)
        e.perform(.startBreak); c.step(e, seconds: 120, input: false)
        XCTAssertEqual(e.exercises?.current.id, .walk); XCTAssertEqual(e.remaining, 180)
        c.step(e, seconds: 180, input: false)
        XCTAssertEqual(e.today.breaks, 2); XCTAssertNil(e.exercises)
        c.step(e, seconds: 10, input: false); XCTAssertEqual(e.today.breaks, 2)
    }
}
