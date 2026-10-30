import XCTest
#if SWIFT_PACKAGE
@testable import KipirCore
#endif

final class BreakSchedulerTests: XCTestCase {
    final class Clock {
        var time: Double = 0
        var idle: Double = 0
        var date = Date(timeIntervalSince1970: 1_800_014_400)
        func engine(_ settings: Settings = Settings(), checkpoint: Checkpoint? = nil) -> BreakScheduler {
            BreakScheduler(settings: settings, checkpoint: checkpoint,
                           now: { self.time }, date: { self.date }, idle: { self.idle })
        }
        func step(_ engine: BreakScheduler, seconds: Int = 1, input: Bool = true) {
            for _ in 0..<seconds {
                time += 1; date += 1; idle = input ? 0 : idle + 1; engine.tick()
            }
        }
    }
    func testActiveTimeAccumulates() {
        let c = Clock(); let e = c.engine(); c.step(e, seconds: 20)
        XCTAssertEqual(e.activeWork, 20, accuracy: 0.001)
        XCTAssertEqual(e.today.activeSeconds, 20)
    }
    func testAFKDoesNotCreditThresholdAndResumes() {
        let c = Clock(); let e = c.engine(); c.step(e, seconds: 20)
        c.step(e, seconds: 600, input: false)
        XCTAssertEqual(e.activeWork, 20); XCTAssertEqual(e.status, .idle)
        c.step(e); XCTAssertEqual(e.activeWork, 21)
        XCTAssertEqual(e.status, .working)
    }
    func testShortInputGapIsConfirmedOnlyOnReturn() {
        let c = Clock(); let e = c.engine(); c.step(e, seconds: 30, input: false)
        XCTAssertEqual(e.activeWork, 0)
        c.step(e); XCTAssertEqual(e.activeWork, 31)
    }
    func testOneReminderPerDueEpisodeAndDeniedFallback() {
        let c = Clock(); var s = Settings(); s.work = 60
        let e = c.engine(s); c.step(e, seconds: 60)
        let id = e.reminderID; XCTAssertNotNil(id); XCTAssertEqual(e.status, .due)
        c.step(e, seconds: 30); XCTAssertEqual(e.reminderID, id)
        XCTAssertFalse(NotificationPolicy.shouldDeliver(enabled: true, authorized: false, due: id, sent: nil))
        XCTAssertTrue(NotificationPolicy.shouldDeliver(enabled: true, authorized: true, due: id, sent: nil))
        XCTAssertFalse(NotificationPolicy.shouldDeliver(enabled: true, authorized: true, due: id, sent: id))
        XCTAssertEqual(e.status, .due)
    }
    func testShortAndLongBreakCycle() {
        let c = Clock(); var s = Settings(); s.shortBreak = 10; s.longBreak = 20
        let e = c.engine(s)
        for n in 1...3 {
            e.perform(.startBreak); XCTAssertFalse(e.isLongBreak)
            c.step(e, seconds: 10); XCTAssertEqual(e.today.breaks, n)
        }
        XCTAssertTrue(e.nextBreakIsLong)
        e.perform(.startBreak); XCTAssertTrue(e.isLongBreak)
        c.step(e, seconds: 20); XCTAssertFalse(e.nextBreakIsLong)
        XCTAssertEqual(e.today.breaks, 4); XCTAssertEqual(e.activeWork, 0)
    }
    func testSkipDoesNotAdvanceCycle() {
        let c = Clock(); var s = Settings(); s.work = 60
        let e = c.engine(s); c.step(e, seconds: 60); e.perform(.skip)
        XCTAssertEqual(e.activeWork, 0); XCTAssertEqual(e.today.breaks, 0)
        XCTAssertFalse(e.nextBreakIsLong); XCTAssertNil(e.reminderID)
    }
    func testSnoozeUsesActiveTimeAndInvalidatesOldReminder() {
        let c = Clock(); var s = Settings(); s.work = 60; s.snooze = 60
        let e = c.engine(s); c.step(e, seconds: 60); let old = e.reminderID
        e.perform(.snooze); c.step(e, seconds: 120, input: false)
        XCTAssertNil(e.reminderID); XCTAssertEqual(e.activeWork, 60)
        c.step(e, seconds: 60); XCTAssertEqual(e.status, .due)
        XCTAssertNotEqual(old, e.reminderID)
    }
    func testPauseAndMeetingPreserveStateWithoutStatistics() {
        let c = Clock(); let e = c.engine(); c.step(e, seconds: 20)
        e.perform(.togglePause); c.step(e, seconds: 100)
        XCTAssertEqual(e.status, .paused); XCTAssertEqual(e.activeWork, 20)
        e.perform(.toggleMeeting); e.perform(.togglePause)
        c.step(e, seconds: 100); XCTAssertEqual(e.status, .meeting)
        e.perform(.toggleMeeting); c.step(e); XCTAssertEqual(e.activeWork, 21)
    }
    func testBreakFreezesDuringPauseAndSleep() {
        let c = Clock(); let e = c.engine(); e.perform(.startBreak)
        c.step(e, seconds: 10); let remaining = e.remaining
        e.perform(.togglePause); c.step(e, seconds: 20); XCTAssertEqual(e.remaining, remaining)
        e.perform(.togglePause); e.setSuspended(true); c.step(e, seconds: 100)
        e.setSuspended(false); XCTAssertEqual(e.remaining, remaining)
        c.step(e); XCTAssertEqual(e.remaining, remaining - 1)
    }
    func testUnknownGapsAndInvalidSamplesFailClosed() {
        let c = Clock(); let e = c.engine(); c.step(e, seconds: 20)
        c.time += 500; c.date += 500; e.tick(); XCTAssertEqual(e.activeWork, 20)
        c.idle = .nan; c.time += 1; e.tick(); XCTAssertEqual(e.activeWork, 20)
        c.idle = 0; c.step(e); XCTAssertEqual(e.activeWork, 20)
        c.step(e); XCTAssertEqual(e.activeWork, 21)
    }
    func testSettingsValidationAndLiveUpdate() {
        var s = Settings(); s.work = .nan; s.afk = -1; s.longEvery = 0
        s = s.validated(); XCTAssertEqual(s.work, 2700); XCTAssertEqual(s.afk, 90); XCTAssertEqual(s.longEvery, 3)
        let c = Clock(); let e = c.engine(); c.step(e, seconds: 100)
        s.work = 60; e.updateSettings(s); XCTAssertEqual(e.status, .due)
    }
    func testDayBoundaryRetainsSessionAndResetsDaily() {
        let c = Clock(); let e = c.engine(); c.step(e, seconds: 20)
        c.date += 86400; c.time += 1; e.tick()
        XCTAssertEqual(e.activeWork, 20); XCTAssertEqual(e.today.activeSeconds, 0)
        c.step(e); XCTAssertEqual(e.today.activeSeconds, 1)
    }
    func testRestartDoesNotCreditOfflineTimeAndPreservesDue() {
        let c = Clock(); var s = Settings(); s.work = 60
        let e = c.engine(s); c.step(e, seconds: 60)
        let saved = e.checkpoint
        c.time += 900; c.date += 900
        let restored = c.engine(s, checkpoint: saved)
        XCTAssertEqual(restored.activeWork, 60); XCTAssertEqual(restored.status, .due)
        XCTAssertNotNil(restored.reminderID)
    }
    func testPersistenceAndCorruptRecovery() {
        let suite = "KipirTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = LocalStore(defaults: defaults)
        let c = Clock(); let e = c.engine(); c.step(e, seconds: 20)
        store.save(e.checkpoint); XCTAssertEqual(store.loadCheckpoint()?.activeWork, 20)
        defaults.set(Data("invalid".utf8), forKey: "checkpoint")
        XCTAssertNil(store.loadCheckpoint())
        var s = Settings(); s.work = 3600; store.save(s)
        XCTAssertEqual(store.loadSettings().work, 3600)
    }
    func testInvalidCheckpointAndReset() {
        let c = Clock(); let e = c.engine(); c.step(e, seconds: 20)
        var saved = e.checkpoint; saved.activeWork = -10
        let restored = c.engine(checkpoint: saved); XCTAssertEqual(restored.activeWork, 0)
        e.perform(.reset); XCTAssertEqual(e.activeWork, 0); XCTAssertEqual(e.today.activeSeconds, 20)
    }
    func testFractionalIdleNeverOvercreditsConfirmedSpan() {
        let c = Clock(); let e = c.engine()
        c.time = 1; c.idle = 0.9; e.tick()
        c.time = 2; c.idle = 1.2; e.tick()
        XCTAssertEqual(e.activeWork, 0.8, accuracy: 0.0001)
        c.time = 3; c.idle = 0; e.tick()
        XCTAssertEqual(e.activeWork, 3, accuracy: 0.0001)
    }
    func testDueIdentitySurvivesPauseMeetingAndRestart() {
        let c = Clock(); var s = Settings(); s.work = 60
        let e = c.engine(s); c.step(e, seconds: 60); let id = e.reminderID
        e.perform(.togglePause); XCTAssertNil(e.reminderID)
        e.perform(.togglePause); XCTAssertEqual(e.reminderID, id)
        e.perform(.toggleMeeting); e.perform(.toggleMeeting)
        XCTAssertEqual(e.reminderID, id)
        let restored = c.engine(s, checkpoint: e.checkpoint)
        XCTAssertEqual(restored.reminderID, id)
    }
    func testSleepDoesNotCreditWorkOnWake() {
        let c = Clock(); let e = c.engine(); c.step(e, seconds: 20)
        e.setSuspended(true); c.step(e, seconds: 900); e.setSuspended(false)
        XCTAssertEqual(e.activeWork, 20)
        c.step(e); XCTAssertEqual(e.activeWork, 21)
    }
    func testBreakCheckpointResumesRemainingTime() {
        let c = Clock(); let e = c.engine(); e.perform(.startBreak); c.step(e, seconds: 10)
        let saved = e.checkpoint; c.time += 3600; c.date += 3600
        let restored = c.engine(checkpoint: saved)
        XCTAssertEqual(restored.remaining, 110); XCTAssertEqual(restored.today.breaks, 0)
        c.step(restored); XCTAssertEqual(restored.remaining, 109)
    }
    func testBackwardAndNonfiniteMonotonicClock() {
        let c = Clock(); let e = c.engine(); c.step(e, seconds: 20)
        c.time = 10; e.tick(); XCTAssertEqual(e.activeWork, 20)
        c.time = .infinity; e.tick(); XCTAssertEqual(e.activeWork, 20)
        c.time = 30; e.tick(); XCTAssertEqual(e.activeWork, 20)
        c.step(e); XCTAssertEqual(e.activeWork, 21)
    }

    func testCurrentBreakDurationAndProgressSurviveSettingsChange() {
        let c = Clock(); let e = c.engine(); e.perform(.startBreak); c.step(e, seconds: 30)
        XCTAssertEqual(e.progress, 0.25, accuracy: 0.0001)
        var s = e.settings; s.shortBreak = 60; e.updateSettings(s)
        XCTAssertEqual(e.remaining, 90)
        XCTAssertEqual(e.progress, 0.25, accuracy: 0.0001)
        let restored = c.engine(s, checkpoint: e.checkpoint)
        XCTAssertEqual(restored.progress, 0.25, accuracy: 0.0001)
    }
    func testSnoozeTargetSurvivesWorkSettingsChange() {
        let c = Clock(); var s = Settings(); s.work = 60; s.snooze = 120
        let e = c.engine(s); c.step(e, seconds: 60); e.perform(.snooze)
        s.work = 3600; e.updateSettings(s)
        XCTAssertEqual(e.remaining, 120)
    }
    func testLongGapReturnBetweenPollsDoesNotConfirmAFK() {
        let c = Clock(); let e = c.engine(); c.step(e, seconds: 10)
        c.step(e, seconds: 89, input: false)
        c.time += 2; c.date += 2; c.idle = 0.5; e.tick()
        XCTAssertEqual(e.activeWork, 11.5, accuracy: 0.0001)
    }

    func testOverdueActiveUseStillCountsInDailyStatistics() {
        let c = Clock(); var s = Settings(); s.work = 60
        let e = c.engine(s); c.step(e, seconds: 60); let id = e.reminderID
        c.step(e, seconds: 20)
        XCTAssertEqual(e.today.activeSeconds, 80)
        XCTAssertEqual(e.activeWork, 80)
        XCTAssertEqual(e.reminderID, id)
        XCTAssertEqual(e.remaining, 0)
    }

    func testOverdueShortInputGapIsConfirmedOnReturn() {
        let c = Clock(); var s = Settings(); s.work = 60
        let e = c.engine(s); c.step(e, seconds: 60); let id = e.reminderID
        c.step(e, seconds: 30, input: false)
        XCTAssertEqual(e.today.activeSeconds, 60)
        c.step(e)
        XCTAssertEqual(e.today.activeSeconds, 91)
        XCTAssertEqual(e.activeWork, 91)
        XCTAssertEqual(e.reminderID, id)
    }

}
