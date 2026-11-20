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
        // Break 1 (rotation 1, all focus) opens with the classic four movements, one per body area.
        let short = ExerciseCatalog.sequence(long: false, duration: 120, rotation: 1)
        XCTAssertEqual(short.map(\.id), [.shoulders, .chest, .wrists, .calves])
        XCTAssertEqual(short.map(\.duration), [30, 30, 30, 30])
        let long = ExerciseCatalog.sequence(long: true, duration: 300, rotation: 1)
        XCTAssertEqual(long.last?.id, .walk)
        XCTAssertEqual(long.map(\.duration), [30, 30, 30, 30, 180])
    }
    func testCatalogIsDeterministicAndCoversEveryMovementKey() {
        for focus in ExerciseFocus.allCases { for long in [false, true] { for r in 0..<12 {
            let a = ExerciseCatalog.sequence(long: long, duration: 180, focus: focus, rotation: r)
            let b = ExerciseCatalog.sequence(long: long, duration: 180, focus: focus, rotation: r)
            XCTAssertEqual(a.map(\.id), b.map(\.id)); XCTAssertEqual(a.map(\.duration), b.map(\.duration))
        } } }
        XCTAssertEqual(Set(ExerciseCatalog.rotating).union([.walk]), Set(ExerciseDefinition.Movement.allCases))
        XCTAssertGreaterThanOrEqual(ExerciseCatalog.rotating.count + 1, 9)
    }
    func testRotationVariesAndNeverRepeatsFirstOrAdjacentMovement() {
        for focus in ExerciseFocus.allCases { for long in [false, true] { for duration in [60.0, 120, 300] {
            var firsts = Set<ExerciseDefinition.Movement>()
            for r in 2...60 {
                let now = ExerciseCatalog.sequence(long: long, duration: duration, focus: focus, rotation: r)
                let before = ExerciseCatalog.sequence(long: long, duration: duration, focus: focus, rotation: r - 1)
                XCTAssertNotEqual(now.first?.id, before.first?.id, "\(focus) long \(long) \(duration) r\(r)")
                XCTAssertEqual(Set(now.map(\.id)).count, now.count)
                for (x, y) in zip(now, now.dropFirst()) { XCTAssertNotEqual(x.id, y.id) }
                firsts.insert(now[0].id)
            }
            XCTAssertGreaterThanOrEqual(firsts.count, 2)
            if focus == .all { XCTAssertGreaterThanOrEqual(firsts.count, 8) }
        } } }
    }
    func testAllFocusBalancesAreasAndMovementsAcrossRotations() {
        var counts: [ExerciseDefinition.Movement: Int] = [:]
        for r in 1...50 {
            let seq = ExerciseCatalog.sequence(long: false, duration: 120, rotation: r)
            XCTAssertGreaterThanOrEqual(Set(seq.map(\.area)).count, 3)
            seq.forEach { counts[$0.id, default: 0] += 1 }
        }
        XCTAssertEqual(Set(counts.keys), Set(ExerciseCatalog.rotating))
        XCTAssertLessThanOrEqual(counts.values.max()! - counts.values.min()!, 12)
    }
    func testDurationsSumToTotalAndStayPositive() {
        for total in [10.0, 45, 120, 300, 3600] { for long in [false, true] { for focus in ExerciseFocus.allCases { for r in [0, 1, 7] {
            let seq = ExerciseCatalog.sequence(long: long, duration: total, focus: focus, rotation: r)
            XCTAssertFalse(seq.isEmpty)
            XCTAssertEqual(seq.map(\.duration).reduce(0, +), total, accuracy: 1e-9)
            XCTAssertTrue(seq.allSatisfy { $0.duration > 0 })
            XCTAssertEqual(seq.last?.id == .walk, long)
        } } } }
        XCTAssertEqual(ExerciseCatalog.sequence(long: false, duration: 10).count, 1)
        XCTAssertEqual(ExerciseCatalog.sequence(long: false, duration: 3600).count, ExerciseCatalog.rotating.count)
        XCTAssertEqual(ExerciseCatalog.sequence(long: true, duration: 3600).last?.duration ?? 0, 2160, accuracy: 1e-9)
    }
    func testInvalidDurationsNeverCrashOrReturnEmpty() {
        for bad in [Double.nan, .infinity, 0, -5] { for rotation in [-3, 0, 1_000_000, Int.max] {
            XCTAssertFalse(ExerciseCatalog.sequence(long: true, duration: bad, focus: .hands, rotation: rotation).isEmpty)
        } }
    }
    func testFocusPrefersItsAreaAndFallsBackToGeneralCatalog() {
        let neck = ExerciseCatalog.sequence(long: false, duration: 90, focus: .neckShoulders, rotation: 1)
        XCTAssertEqual(neck.count, 3); XCTAssertTrue(neck.allSatisfy { $0.area == .neckShoulders })
        let back = ExerciseCatalog.sequence(long: false, duration: 90, focus: .back, rotation: 2)
        XCTAssertTrue(back.allSatisfy { $0.area == .back })
        // Hands has two movements: both appear first, the rest comes from other areas.
        for r in 1...4 {
            let hands = ExerciseCatalog.sequence(long: false, duration: 120, focus: .hands, rotation: r)
            XCTAssertEqual(hands.count, 4)
            XCTAssertEqual(Set(hands.prefix(2).map(\.id)), [.wrists, .fingers])
            XCTAssertEqual(hands.filter { $0.area == .hands }.count, 2)
        }
        let one = ExerciseCatalog.sequence(long: false, duration: 10, focus: .hands, rotation: 1)
        XCTAssertEqual(one.count, 1); XCTAssertEqual(one[0].area, .hands)
        let longHands = ExerciseCatalog.sequence(long: true, duration: 300, focus: .hands, rotation: 3)
        XCTAssertEqual(longHands.last?.id, .walk); XCTAssertEqual(longHands.count, 5)
    }
    func testDisplayRemainingUsesBreakBudgetOnlyForLastOrCappedMovement() {
        var s = ExerciseSequenceController(long: false, duration: 120, rotation: 1)
        XCTAssertEqual(s.displayRemaining(breakRemaining: 120), 30)
        s.advance(10); XCTAssertEqual(s.displayRemaining(breakRemaining: 110), 20)
        XCTAssertEqual(s.displayRemaining(breakRemaining: 12), 12)
        XCTAssertEqual(s.displayRemaining(breakRemaining: -4), 0)
        XCTAssertEqual(s.displayRemaining(breakRemaining: .nan), 20)
        s.navigate(3); XCTAssertEqual(s.displayRemaining(breakRemaining: 95), 95)
        XCTAssertEqual(s.displayRemaining(breakRemaining: 0), 0)
    }
    func testLoopPeriodFitsDurationWithEvenCyclesAndHandlesBadInput() {
        for movement in ExerciseDefinition.Movement.allCases {
            let period = ExerciseDefinition.loopPeriod(duration: 30, base: movement.basePeriod)
            let cycles = 30 / period
            XCTAssertEqual(cycles.rounded(), cycles, accuracy: 1e-9)
            XCTAssertEqual(Int(cycles) % 2, 0, "\(movement)")
        }
        XCTAssertEqual(ExerciseDefinition.loopPeriod(duration: 12, base: 5), 6, accuracy: 1e-9)
        XCTAssertGreaterThan(ExerciseDefinition.loopPeriod(duration: .nan, base: 5), 0)
        XCTAssertGreaterThan(ExerciseDefinition.loopPeriod(duration: 0, base: 0), 0)
    }
    func testVisualResyncOnlyAfterRealDrift() {
        XCTAssertFalse(exerciseVisualNeedsResync(visual: 10.4, accepted: 10))
        XCTAssertTrue(exerciseVisualNeedsResync(visual: 15, accepted: 10))
        XCTAssertTrue(exerciseVisualNeedsResync(visual: .nan, accepted: 10))
    }
    func testEveryMovementHasLocalizedNameAndInstructionInBothLanguages() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        for language in ["tr", "en"] {
            let text = try String(contentsOf: root.appendingPathComponent("Kipir/Resources/\(language).lproj/Localizable.strings"), encoding: .utf8)
            for movement in ExerciseDefinition.Movement.allCases {
                let definition = ExerciseDefinition(id: movement, duration: 30)
                for key in [definition.nameKey, definition.instructionKey] {
                    XCTAssertTrue(text.contains("\"\(key)\" = \""), "\(language) missing \(key)")
                }
            }
        }
    }
    func testCheckpointRestoreRebuildsIdenticalSequenceAfterFocusChange() {
        let c = Clock(); var settings = Settings(); settings.longEvery = 1; settings.exerciseFocus = "hands"
        let e = c.engine(settings); e.perform(.startBreak)
        var changed = settings; changed.exerciseFocus = "back"; e.updateSettings(changed)
        c.step(e, seconds: 40, input: false)
        let restored = c.engine(changed, checkpoint: e.checkpoint)
        XCTAssertEqual(restored.exercises?.exercises.map(\.id), e.exercises?.exercises.map(\.id))
        XCTAssertEqual(restored.exercises?.exercises.map(\.duration), e.exercises?.exercises.map(\.duration))
        XCTAssertEqual(restored.exercises?.index, e.exercises?.index)
        XCTAssertEqual(e.exercises?.exercises.prefix(2).map(\.id), [.wrists, .fingers])
        // The next break uses the incremented rotation and the new focus.
        e.perform(.skip); e.perform(.startBreak)
        XCTAssertEqual(e.checkpoint.exerciseRotation, 2)
        XCTAssertTrue(e.exercises!.exercises.prefix(3).allSatisfy { $0.area == .back })
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
    func testExerciseKeepsPlayingDuringMeetingAndNavigationRestartsSelection() {
        let c = Clock(); let e = c.engine(); e.perform(.startBreak)
        c.step(e, seconds: 8)
        let remaining = e.remaining
        e.perform(.toggleMeeting); c.step(e, seconds: 20)
        // Meeting mode silences interruptions only; the guided break keeps running and stays visible.
        XCTAssertEqual(e.status, .onBreak)
        XCTAssertEqual(e.remaining, remaining - 20)
        XCTAssertEqual(e.exercises?.elapsed, 28)
        e.perform(.toggleMeeting)
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
    func testPoseBlendHoldsEachPoseAndFadesBriefly() {
        XCTAssertEqual(exercisePoseBlend(phase: 0), 0)
        XCTAssertEqual(exercisePoseBlend(phase: 0.2), 0)
        XCTAssertEqual(exercisePoseBlend(phase: 0.5), 1)
        XCTAssertEqual(exercisePoseBlend(phase: 0.7), 1)
        XCTAssertEqual(exercisePoseBlend(phase: 0.44), 0.5, accuracy: 0.01)
        XCTAssertEqual(exercisePoseBlend(phase: 0.94), 0.5, accuracy: 0.01)
        XCTAssertEqual(exercisePoseBlend(phase: 3.2), exercisePoseBlend(phase: 0.2), accuracy: 1e-9)
        XCTAssertEqual(exercisePoseBlend(phase: .nan), 0)
        XCTAssertEqual(exercisePoseBlend(phase: -0.3), exercisePoseBlend(phase: 0.7), accuracy: 1e-9)
    }
    func testEveryMovementHasBothPoseImagesInTheAssetCatalog() throws {
        let catalog = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Kipir/Resources/Assets.xcassets")
        for movement in ExerciseDefinition.Movement.allCases {
            for pose in ["start", "end"] {
                let name = "exercise-\(movement.rawValue)-\(pose)"
                let png = catalog.appendingPathComponent("\(name).imageset/\(name).png")
                XCTAssertTrue(FileManager.default.fileExists(atPath: png.path), name)
            }
        }
    }
}
