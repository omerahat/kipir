import XCTest
#if SWIFT_PACKAGE
@testable import KipirCore
#endif

final class BreakSchedulerTests: XCTestCase {
    final class Clock {
        var time: Double = 0
        var idle: Double = 0
        var date = Date(timeIntervalSince1970: 1_800_014_400)
        var calendar = Calendar.current
        func engine(_ settings: Settings = Settings(), checkpoint: Checkpoint? = nil) -> BreakScheduler {
            BreakScheduler(settings: settings, checkpoint: checkpoint,
                           now: { self.time }, date: { self.date }, idle: { self.idle }, calendar: calendar)
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
        // Natural break disabled: a 600 s no-input span is exactly the 0.2 default threshold (DECISIONS 018) and
        // would reset the interval; this test isolates the AFK-only 0.1 behavior.
        var s = Settings(); s.naturalBreak = 0
        let c = Clock(); let e = c.engine(s); c.step(e, seconds: 20)
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
    func testPauseFreezesButMeetingKeepsCounting() {
        let c = Clock(); let e = c.engine(); c.step(e, seconds: 20)
        e.perform(.togglePause); c.step(e, seconds: 100)
        XCTAssertEqual(e.status, .paused); XCTAssertEqual(e.activeWork, 20)
        // Paused + meeting stays frozen: meeting mode never resumes a manual pause.
        e.perform(.toggleMeeting); c.step(e, seconds: 10)
        XCTAssertEqual(e.status, .paused); XCTAssertEqual(e.activeWork, 20)
        // Resume while in a meeting: work, statistics and the countdown run normally (pre-release Fix 3).
        e.perform(.togglePause); c.step(e, seconds: 100)
        XCTAssertEqual(e.status, .meeting); XCTAssertEqual(e.activeWork, 120); XCTAssertEqual(e.today.activeSeconds, 120)
        XCTAssertEqual(e.remaining, 2700 - 120)
        e.perform(.toggleMeeting); c.step(e); XCTAssertEqual(e.activeWork, 121)
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
        // Natural break disabled: this models sleep as 900 s of suspended monotonic time, which DECISIONS 018
        // counts as verified away time. Real sleep stops uptime (see NaturalBreakTests sleep tests).
        var s = Settings(); s.naturalBreak = 0
        let c = Clock(); let e = c.engine(s); c.step(e, seconds: 20)
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

    func testMenuBarFormattingRoundsUpAndRepresentsEveryOverride() {
        func label(_ status: WorkStatus, _ seconds: Double) -> MenuBarStatusFormatter {
            MenuBarStatusFormatter(status: status, remaining: seconds)
        }
        XCTAssertEqual(label(.working, 1380).minutes, 23)
        XCTAssertEqual(label(.working, 14401).minutes, 241)
        XCTAssertEqual(label(.working, 60.01).minutes, 2)
        XCTAssertEqual(label(.working, 0.01).minutes, 1)
        XCTAssertEqual(label(.working, .nan).minutes, 0)
        XCTAssertEqual(label(.working, .infinity).minutes, 0)
        XCTAssertEqual(label(.working, -1).minutes, 0)
        XCTAssertEqual(label(.due, 0).textKey, "menubar.due")
        // Every other state keeps the minute countdown; only the icon in its fixed slot changes (Fix 2).
        for status in [WorkStatus.working, .idle, .paused, .meeting, .onBreak, .suspended, .offHours] {
            XCTAssertEqual(label(status, 61).textKey, "menubar.minutes", "\(status)")
            XCTAssertTrue(label(status, 61).showsText, "\(status)")
        }
        XCTAssertEqual(label(.onBreak, 61).symbol, "figure.walk.motion")
        XCTAssertEqual(label(.paused, 61).symbol, "pause.fill")
        XCTAssertEqual(label(.idle, 61).symbol, "moon")
        XCTAssertEqual(label(.meeting, 61).symbol, "person.2")
        XCTAssertEqual(label(.suspended, 61).symbol, "powersleep")
        let table = ["menubar.minutes": "%d min", "menubar.due": "Break"]
        XCTAssertEqual(label(.paused, 61).text { table[$0] ?? $0 }, "2 min")
        XCTAssertEqual(label(.due, 0).text { table[$0] ?? $0 }, "Break")
    }

    func testNotificationTestRequiresExplicitAuthorizationAndEnabledSetting() {
        XCTAssertEqual(NotificationPolicy.testBlock(enabled: false, permission: .authorized), "notification.test.disabled")
        XCTAssertEqual(NotificationPolicy.testBlock(enabled: true, permission: .denied), "permission.denied")
        XCTAssertEqual(NotificationPolicy.testBlock(enabled: true, permission: .unknown), "permission.unknown")
        XCTAssertNil(NotificationPolicy.testBlock(enabled: true, permission: .authorized))
    }

    func testPresetsAreDerivedAndPreserveUnrelatedPreferences() {
        var s = Settings(); s.notifications = false; s.sound = true; s.appearance = "dark"
        XCTAssertEqual(TimingPreset.match(s), .balanced)
        TimingPreset.quick.apply(to: &s)
        XCTAssertEqual([s.work, s.shortBreak, s.longBreak, s.afk, s.snooze], [1500, 60, 300, 90, 300])
        XCTAssertEqual(s.longEvery, 3); XCTAssertFalse(s.notifications); XCTAssertTrue(s.sound)
        XCTAssertEqual(s.appearance, "dark"); XCTAssertEqual(TimingPreset.match(s), .quick)
        s.work = 1800; XCTAssertNil(TimingPreset.match(s))
        s.work = 1500; XCTAssertEqual(TimingPreset.match(s), .quick)
        TimingPreset.balanced.apply(to: &s)
        XCTAssertEqual([s.work, s.shortBreak, s.longBreak, s.afk, s.snooze], [2700, 120, 300, 90, 600])
    }
    func testPresetChangesPreserveBreakBudgetStatisticsAndSnoozeTarget() {
        let c = Clock(); let e = c.engine(); c.step(e, seconds: 20)
        e.perform(.startBreak); c.step(e, seconds: 10)
        var s = e.settings; TimingPreset.quick.apply(to: &s); e.updateSettings(s)
        XCTAssertEqual(e.remaining, 110); XCTAssertEqual(e.checkpoint.breakDuration, 120)
        XCTAssertEqual(e.today.activeSeconds, 20)
        c.step(e, seconds: 110); XCTAssertEqual(e.today.breaks, 1)
        c.step(e, seconds: 1500); e.perform(.snooze)
        let target = e.checkpoint.target
        TimingPreset.balanced.apply(to: &s); e.updateSettings(s)
        XCTAssertEqual(e.checkpoint.target, target)
        XCTAssertEqual(e.checkpoint.completedShorts, 1)
    }

    func testTimedMeetingKeepsCountingAndExpiresAtDeadline() {
        let c = Clock(); let e = c.engine(); c.step(e, seconds: 20)
        let start = c.date; e.setMeeting(true, duration: 900)
        XCTAssertEqual(e.checkpoint.meetingDeadline, start + 900)
        XCTAssertEqual(e.status, .meeting)
        c.step(e, seconds: 899)
        XCTAssertTrue(e.meeting); XCTAssertEqual(e.activeWork, 919)
        c.step(e); XCTAssertFalse(e.meeting); XCTAssertNil(e.checkpoint.meetingDeadline)
        XCTAssertEqual(e.activeWork, 920); XCTAssertEqual(e.today.activeSeconds, 920)
        c.step(e); XCTAssertEqual(e.activeWork, 921)
    }
    func testMeetingEarlyEndIndefiniteAndReplacementAreExplicit() {
        let c = Clock(); let e = c.engine()
        e.setMeeting(true, duration: 900); c.step(e, seconds: 10)
        e.setMeeting(true, duration: 1800)
        XCTAssertEqual(e.checkpoint.meetingDeadline, c.date + 1800)
        e.setMeeting(true); XCTAssertTrue(e.meeting); XCTAssertNil(e.checkpoint.meetingDeadline)
        e.setMeeting(true, duration: 3600); e.setMeeting(false); e.setMeeting(false)
        XCTAssertFalse(e.meeting); XCTAssertNil(e.checkpoint.meetingDeadline)
        e.setMeeting(true, duration: .nan); XCTAssertFalse(e.meeting)
        e.setMeeting(true, duration: -1); XCTAssertFalse(e.meeting)
        e.setMeeting(true, duration: 3601); XCTAssertFalse(e.meeting)
    }
    func testMeetingExpiresOnWakeWithoutSleepCredit() {
        // Natural break off: this isolates sleep crediting (a 2400 s sleep is otherwise a natural break).
        var s = Settings(); s.naturalBreak = 0
        let c = Clock(); let e = c.engine(s); c.step(e, seconds: 20)
        e.setMeeting(true, duration: 1800); e.setSuspended(true)
        c.time += 2400; c.date += 2400; c.idle = 2400
        e.setSuspended(false)
        XCTAssertFalse(e.meeting); XCTAssertEqual(e.activeWork, 20)
        XCTAssertEqual(e.today.activeSeconds, 20)
        c.step(e); XCTAssertEqual(e.activeWork, 21)
    }
    func testMeetingRestartBeforeAndAfterDeadlinePreservesProgress() {
        let c = Clock(); let e = c.engine(); c.step(e, seconds: 20)
        e.setMeeting(true, duration: 1800); let saved = e.checkpoint
        c.time += 600; c.date += 600
        let restored = c.engine(checkpoint: saved)
        XCTAssertTrue(restored.meeting); XCTAssertEqual(restored.checkpoint.meetingDeadline, saved.meetingDeadline)
        XCTAssertEqual(restored.activeWork, 20)
        c.time += 1800; c.date += 1800
        let expired = c.engine(checkpoint: saved)
        XCTAssertFalse(expired.meeting); XCTAssertNil(expired.checkpoint.meetingDeadline)
        XCTAssertEqual(expired.activeWork, 20); XCTAssertEqual(expired.today.activeSeconds, 20)
    }
    func testMeetingExpirationRetainsManualPauseAndResetClearsDeadline() {
        let c = Clock(); let e = c.engine(); e.perform(.startBreak); c.step(e, seconds: 10)
        let remaining = e.remaining
        e.setMeeting(true, duration: 900); e.perform(.togglePause); c.step(e, seconds: 900)
        XCTAssertFalse(e.meeting); XCTAssertTrue(e.paused); XCTAssertEqual(e.remaining, remaining)
        c.step(e, seconds: 10); XCTAssertEqual(e.remaining, remaining)
        e.perform(.togglePause); c.step(e); XCTAssertEqual(e.remaining, remaining - 1)
        e.setMeeting(true, duration: 900); e.perform(.reset)
        XCTAssertFalse(e.meeting); XCTAssertNil(e.checkpoint.meetingDeadline)
        XCTAssertEqual(e.today.breaks, 0)
    }
    func testMeetingConsumesDueReminderWithoutReplayAndLaterEpisodesNotify() {
        let c = Clock(); var s = Settings(); s.work = 60; s.naturalBreak = 0
        let e = c.engine(s); c.step(e, seconds: 60); let id = e.reminderID
        e.setMeeting(true, duration: 900); c.step(e, seconds: 899, input: false)
        XCTAssertNil(e.reminderID); XCTAssertEqual(e.checkpoint.dueID, id); XCTAssertTrue(e.breakDueActionable)
        XCTAssertFalse(NotificationPolicy.shouldDeliver(enabled: true, authorized: true, due: e.reminderID, sent: nil))
        // The manager stores the marked episode as already attempted while the meeting runs.
        let sent = NotificationPolicy.markingMeetingSuppressed(sent: nil, meeting: e.meeting, dueID: e.checkpoint.dueID)
        XCTAssertEqual(sent, id)
        c.step(e, input: false)
        XCTAssertFalse(e.meeting); XCTAssertEqual(e.reminderID, id); XCTAssertEqual(e.activeWork, 60)
        XCTAssertEqual(NotificationPolicy.markingMeetingSuppressed(sent: sent, meeting: false, dueID: id), sent)
        XCTAssertFalse(NotificationPolicy.shouldDeliver(enabled: true, authorized: true, due: e.reminderID, sent: sent))
        // A later episode has a new identifier and notifies normally.
        e.perform(.skip); c.step(e, seconds: 60)
        XCTAssertNotNil(e.reminderID); XCTAssertNotEqual(e.reminderID, id)
        XCTAssertTrue(NotificationPolicy.shouldDeliver(enabled: true, authorized: true, due: e.reminderID, sent: sent))
    }
    func testTimerReachesZeroDuringMeetingAndBreakRunsSilently() {
        let c = Clock(); var s = Settings(); s.work = 60; s.shortBreak = 30; s.breakEndSound = true
        let e = c.engine(s); c.step(e, seconds: 30)
        e.setMeeting(true); c.step(e, seconds: 30)
        // Normal completion logic: the interval becomes Due; only the reminder is withheld.
        XCTAssertEqual(e.checkpoint.phase, .due); XCTAssertEqual(e.status, .meeting)
        XCTAssertNil(e.reminderID); XCTAssertNotNil(e.checkpoint.dueID); XCTAssertTrue(e.breakDueActionable)
        XCTAssertEqual(e.remaining, 0); XCTAssertEqual(e.remainingFraction, 0)
        // Manual break and snooze stay available during a meeting.
        e.perform(.startBreak); XCTAssertEqual(e.status, .onBreak); XCTAssertTrue(e.meeting)
        c.step(e, seconds: 30, input: false)
        let outcome = BreakCompletionFeedback.consume(from: e)
        XCTAssertTrue(outcome.completed); XCTAssertFalse(outcome.playSound)
        XCTAssertEqual(e.today.breaks, 1); XCTAssertEqual(e.checkpoint.phase, .working)
        XCTAssertFalse(BreakCompletionFeedback.consume(from: e).completed, "consumed once, never replayed")
        c.step(e, seconds: 60); e.perform(.snooze)
        XCTAssertEqual(e.checkpoint.phase, .working); XCTAssertTrue(e.checkpoint.snoozed)
    }
    func testMeetingToggleKeepsUnconfirmedCreditAndRapidTogglesAreHarmless() {
        let c = Clock(); let e = c.engine(); c.step(e, seconds: 10)
        c.step(e, seconds: 30, input: false)            // 30 s without input awaits confirmation
        for _ in 0..<5 { c.time += 0.2; c.date += 0.2; c.idle += 0.2; e.setMeeting(true); e.setMeeting(false) }
        c.step(e)                                       // input confirms the pending span
        XCTAssertEqual(e.activeWork, 42, accuracy: 0.001)
        XCTAssertFalse(e.meeting); XCTAssertNil(e.checkpoint.meetingDeadline)
    }
    func testMeetingDiscardsUnconfirmedInputTail() {
        let c = Clock(); let e = c.engine(); c.step(e, seconds: 30, input: false)
        e.setMeeting(true, duration: 900); c.step(e, seconds: 900, input: false)
        c.step(e); XCTAssertEqual(e.activeWork, 1)
    }
    func testInvalidMeetingDeadlineRecoversOnlyMeetingState() throws {
        let c = Clock(); let e = c.engine(); c.step(e, seconds: 20)
        for deadline in [Date(timeIntervalSince1970: .nan), c.date + 86400, c.date - 1] {
            var saved = e.checkpoint; saved.meeting = true; saved.meetingDeadline = deadline
            let restored = c.engine(checkpoint: saved)
            XCTAssertFalse(restored.meeting); XCTAssertNil(restored.checkpoint.meetingDeadline)
            XCTAssertEqual(restored.activeWork, 20)
        }
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(e.checkpoint)) as? [String: Any])
        object["meeting"] = true; object["meetingDeadline"] = "broken"
        let recovered = try JSONDecoder().decode(Checkpoint.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertFalse(recovered.meeting); XCTAssertEqual(recovered.activeWork, 20)
        object.removeValue(forKey: "meetingDeadline")
        let legacy = try JSONDecoder().decode(Checkpoint.self, from: JSONSerialization.data(withJSONObject: object))
        let restored = c.engine(checkpoint: legacy)
        XCTAssertTrue(restored.meeting); XCTAssertNil(restored.checkpoint.meetingDeadline)
    }
    func testWallClockAdjustmentNeverCreditsMoreThanMonotonicTime() {
        let c = Clock(); let e = c.engine(); c.step(e, seconds: 20)
        e.setMeeting(true, duration: 900)
        c.date += 901; c.time += 1; e.tick()
        // The wall-clock jump ends the timed meeting; only the one monotonic second is credited.
        XCTAssertFalse(e.meeting); XCTAssertEqual(e.activeWork, 21)
        e.setMeeting(true, duration: 3600)
        c.date -= 3601; c.time += 1; e.tick()
        XCTAssertFalse(e.meeting); XCTAssertEqual(e.activeWork, 22)
        c.time += 500; c.date += 500; e.tick(); XCTAssertEqual(e.activeWork, 22, "unknown gap is never credited")
    }

    func testNaturalCompletionSoundExactlyOnceForShortAndLongBreaks() {
        let c = Clock(); var s = Settings(); s.shortBreak = 10; s.longBreak = 20
        s.longEvery = 1; s.breakEndSound = true
        let e = c.engine(s); var sounds = 0
        e.perform(.startBreak); c.step(e, seconds: 10)
        BreakCompletionFeedback.consume(from: e) { sounds += 1 }
        BreakCompletionFeedback.consume(from: e) { sounds += 1 }
        c.step(e); BreakCompletionFeedback.consume(from: e) { sounds += 1 }
        XCTAssertEqual(sounds, 1)
        e.perform(.startBreak); XCTAssertTrue(e.isLongBreak); c.step(e, seconds: 20)
        BreakCompletionFeedback.consume(from: e) { sounds += 1 }
        XCTAssertEqual(sounds, 2); XCTAssertEqual(e.today.breaks, 2)
    }
    func testManualActionsAndOverridesDoNotProduceCompletionSound() {
        let c = Clock(); var s = Settings(); s.shortBreak = 10; s.breakEndSound = true
        let e = c.engine(s); var sounds = 0
        for action in [SchedulerAction.skip, .reset] {
            e.perform(.startBreak); c.step(e, seconds: 9); e.perform(action)
            BreakCompletionFeedback.consume(from: e) { sounds += 1 }
        }
        e.perform(.startBreak); c.step(e, seconds: 9)
        e.perform(.togglePause); c.step(e, seconds: 30)
        BreakCompletionFeedback.consume(from: e) { sounds += 1 }
        // Meeting mode: the break keeps counting and completes (credited) but silently.
        e.perform(.togglePause); e.setMeeting(true, duration: 900); c.step(e)
        let silent = BreakCompletionFeedback.consume(from: e) { sounds += 1 }
        XCTAssertTrue(silent.completed); XCTAssertFalse(silent.playSound); XCTAssertEqual(e.today.breaks, 1)
        e.setMeeting(false)
        e.perform(.startBreak); c.step(e, seconds: 9)
        e.setSuspended(true); c.time += 600; c.date += 600; e.setSuspended(false)
        BreakCompletionFeedback.consume(from: e) { sounds += 1 }
        XCTAssertEqual(sounds, 0); XCTAssertEqual(e.remaining, 1)
        c.step(e); BreakCompletionFeedback.consume(from: e) { sounds += 1 }
        XCTAssertEqual(sounds, 1)
    }
    func testCompletionSoundDisabledConsumedAndNotReplayedOnRestore() {
        let c = Clock(); var s = Settings(); s.shortBreak = 10
        XCTAssertFalse(s.breakEndSound)
        let e = c.engine(s); var sounds = 0
        e.perform(.startBreak); c.step(e, seconds: 10)
        BreakCompletionFeedback.consume(from: e) { sounds += 1 }
        s.breakEndSound = true; e.updateSettings(s)
        BreakCompletionFeedback.consume(from: e) { sounds += 1 }
        XCTAssertEqual(sounds, 0)
        e.perform(.startBreak); c.step(e, seconds: 10)
        let restored = c.engine(s, checkpoint: e.checkpoint)
        BreakCompletionFeedback.consume(from: restored) { sounds += 1 }
        XCTAssertEqual(sounds, 0)
    }
    func testUserActionAtCompletionBoundarySuppressesSound() {
        for action in [SchedulerAction.skip, .reset, .togglePause] {
            let c = Clock(); var s = Settings(); s.shortBreak = 10; s.breakEndSound = true
            let e = c.engine(s); e.perform(.startBreak); c.step(e, seconds: 9)
            c.time += 1; c.date += 1; e.perform(action)
            var sounds = 0; BreakCompletionFeedback.consume(from: e) { sounds += 1 }
            XCTAssertEqual(sounds, 0)
        }
    }
    func testV011PayloadsDecodeWithNewDefaultsAndMalformedAdditionsDoNotWipePreferences() throws {
        let v011 = #"{"work":1800,"shortBreak":90,"longBreak":240,"longEvery":2,"afk":120,"snooze":420,"notifications":false,"sound":true,"breakEndSound":true,"appearance":"dark"}"#
        let s = try JSONDecoder().decode(Settings.self, from: Data(v011.utf8)).validated()
        XCTAssertEqual(s.work, 1800); XCTAssertTrue(s.breakEndSound); XCTAssertFalse(s.notifications)
        XCTAssertEqual(s.naturalBreak, 600); XCTAssertEqual(s.workingHours, WorkingHours())
        XCTAssertEqual(s.exerciseFocus, "all"); XCTAssertEqual(s.menuBarStyle, "timer")
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(v011.utf8)) as? [String: Any])
        object["naturalBreak"] = "x"; object["workingHours"] = 5; object["exerciseFocus"] = "legs"; object["menuBarStyle"] = 3
        let broken = try JSONDecoder().decode(Settings.self, from: JSONSerialization.data(withJSONObject: object)).validated()
        XCTAssertEqual(broken.work, 1800); XCTAssertEqual(broken.snooze, 420); XCTAssertEqual(broken.appearance, "dark")
        XCTAssertEqual(broken.naturalBreak, 600); XCTAssertEqual(broken.exerciseFocus, "all"); XCTAssertEqual(broken.menuBarStyle, "timer")
        object["naturalBreak"] = 1234; object["exerciseFocus"] = "back"
        object["workingHours"] = ["enabled": true, "weekdays": [0, 9], "start": 2000, "end": 10]
        let clamped = try JSONDecoder().decode(Settings.self, from: JSONSerialization.data(withJSONObject: object)).validated()
        XCTAssertEqual(clamped.naturalBreak, 600); XCTAssertEqual(clamped.exerciseFocus, "back")
        XCTAssertTrue(clamped.workingHours.enabled); XCTAssertEqual(clamped.workingHours.weekdays, [2, 3, 4, 5, 6])
        XCTAssertEqual(clamped.workingHours.start, 540); XCTAssertEqual(clamped.workingHours.end, 1080)
        let c = Clock(); let e = c.engine(); c.step(e, seconds: 5)
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(e.checkpoint)) as? [String: Any])
        legacy.removeValue(forKey: "exerciseRotation"); legacy.removeValue(forKey: "breakFocus")
        let restored = try JSONDecoder().decode(Checkpoint.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertEqual(restored.exerciseRotation, 0); XCTAssertNil(restored.breakFocus); XCTAssertEqual(restored.activeWork, 5)
    }
    func testLegacySettingsAndCheckpointMigrationPreserveValues() throws {
        let oldSettings = Data(#"{"work":1800,"shortBreak":90,"longBreak":240,"longEvery":2,"afk":120,"snooze":420,"notifications":false,"sound":true,"appearance":"dark"}"#.utf8)
        let s = try JSONDecoder().decode(Settings.self, from: oldSettings)
        XCTAssertEqual(s.work, 1800); XCTAssertEqual(s.shortBreak, 90); XCTAssertEqual(s.snooze, 420)
        XCTAssertFalse(s.notifications); XCTAssertTrue(s.sound); XCTAssertEqual(s.appearance, "dark")
        XCTAssertFalse(s.breakEndSound)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: oldSettings) as? [String: Any])
        object["breakEndSound"] = "invalid"
        let recovered = try JSONDecoder().decode(Settings.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertFalse(recovered.breakEndSound); XCTAssertEqual(recovered.work, 1800)
        let c = Clock(); let e = c.engine(s); c.step(e, seconds: 20); e.setMeeting(true, duration: 900)
        let suite = "KipirMigration.\(UUID().uuidString)"; let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(oldSettings, forKey: "settings")
        let store = LocalStore(defaults: defaults)
        XCTAssertEqual(store.loadSettings(), s)
        var enabled = s; enabled.breakEndSound = true; store.save(enabled)
        XCTAssertTrue(store.loadSettings().breakEndSound)
        store.save(e.checkpoint)
        XCTAssertEqual(store.loadCheckpoint()?.meetingDeadline, e.checkpoint.meetingDeadline)
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(e.checkpoint)) as? [String: Any])
        legacy.removeValue(forKey: "meetingDeadline")
        defaults.set(try JSONSerialization.data(withJSONObject: legacy), forKey: "checkpoint")
        XCTAssertEqual(store.loadCheckpoint()?.activeWork, 20)
        XCTAssertEqual(store.loadCheckpoint()?.today.activeSeconds, 20)
        XCTAssertTrue(try XCTUnwrap(store.loadCheckpoint()).meeting)
    }

    func testBalancedWorkflowIntegratesCountdownReminderGuideAndCompletion() {
        let c = Clock(); let e = c.engine(); var s = e.settings
        TimingPreset.balanced.apply(to: &s); s.breakEndSound = true; e.updateSettings(s)
        XCTAssertEqual(MenuBarStatusFormatter(status: e.status, remaining: e.remaining).minutes, 45)
        c.step(e, seconds: 60)
        XCTAssertEqual(MenuBarStatusFormatter(status: e.status, remaining: e.remaining).minutes, 44)
        c.step(e, seconds: 2640)
        XCTAssertEqual(MenuBarStatusFormatter(status: e.status, remaining: e.remaining).textKey, "menubar.due")
        XCTAssertTrue(NotificationPolicy.shouldDeliver(enabled: s.notifications, authorized: true, due: e.reminderID, sent: nil))
        e.perform(.startBreak)
        XCTAssertEqual(e.exercises?.current.id, .shoulders)
        XCTAssertEqual(MenuBarStatusFormatter(status: e.status, remaining: e.remaining).minutes, 2)
        c.step(e, seconds: 120, input: false)
        var sounds = 0; BreakCompletionFeedback.consume(from: e) { sounds += 1 }
        BreakCompletionFeedback.consume(from: e) { sounds += 1 }
        XCTAssertEqual(sounds, 1); XCTAssertEqual(e.today.breaks, 1)
        XCTAssertEqual(e.checkpoint.completedShorts, 1); XCTAssertEqual(e.remaining, 2700)
        XCTAssertNil(e.reminderID); XCTAssertNil(e.exercises)
    }

    func testDesktopNotificationEligibilityRequiresAlertsAndVisibleStyle() {
        var settings = NotificationCapabilities(permission: .authorized, alertsEnabled: true,
            style: .banner, centerEnabled: true, soundEnabled: true)
        XCTAssertTrue(settings.canSubmit); XCTAssertTrue(settings.canShowDesktopAlerts)
        XCTAssertEqual(settings.statusKey, "permission.allowed")
        settings.style = .alert; XCTAssertTrue(settings.canShowDesktopAlerts)
        settings.style = .none
        XCTAssertFalse(settings.canShowDesktopAlerts); XCTAssertTrue(settings.canSubmit)
        XCTAssertEqual(settings.statusKey, "permission.centerOnly")
        settings.style = .banner; settings.alertsEnabled = false
        XCTAssertFalse(settings.canShowDesktopAlerts)
        settings.centerEnabled = false; XCTAssertEqual(settings.statusKey, "permission.alertsDisabled")
        settings.alertsEnabled = true
        XCTAssertTrue(settings.canShowDesktopAlerts)
        XCTAssertEqual(settings.statusKey, "permission.allowed")
    }
    func testQuietDeniedAndUndeterminedNotificationSettingsCannotClaimBanners() {
        var settings = NotificationCapabilities(permission: .provisional, alertsEnabled: true,
            style: .banner, centerEnabled: true, soundEnabled: false)
        XCTAssertTrue(settings.canSubmit); XCTAssertFalse(settings.canShowDesktopAlerts)
        XCTAssertEqual(settings.statusKey, "permission.quiet")
        XCTAssertNil(NotificationPolicy.testBlock(enabled: true, permission: .provisional))
        settings.permission = .denied
        XCTAssertFalse(settings.canSubmit); XCTAssertFalse(settings.canShowDesktopAlerts)
        XCTAssertEqual(settings.statusKey, "permission.denied")
        settings.permission = .unknown
        XCTAssertFalse(settings.canSubmit); XCTAssertFalse(settings.canShowDesktopAlerts)
        XCTAssertEqual(settings.statusKey, "permission.unknown")
    }

}

#if !SWIFT_PACKAGE
import UserNotifications

@MainActor
private final class RecordingNotificationDelivery: NotificationDelivery {
    var permission: NotificationPermission = .authorized
    var requests: [UNNotificationRequest] = []
    var removed: [String] = []
    var permissionRequests = 0
    var fail = false
    var hold = false
    var pendingAdd: CheckedContinuation<Void, Never>?
    var onAddStarted: (() -> Void)?
    var onRemove: (() -> Void)?
    var alertsEnabled = true
    var style: NotificationCapabilities.AlertStyle = .banner
    var centerEnabled = true
    var soundEnabled = true
    weak var delegate: UNUserNotificationCenterDelegate?
    var categories: Set<UNNotificationCategory> = []
    func settings() async -> NotificationCapabilities {
        NotificationCapabilities(permission: permission, alertsEnabled: alertsEnabled,
            style: style, centerEnabled: centerEnabled, soundEnabled: soundEnabled)
    }
    func requestPermission() async throws { permissionRequests += 1 }
    func configure(delegate: UNUserNotificationCenterDelegate, categories: Set<UNNotificationCategory>) {
        self.delegate = delegate; self.categories = categories
    }
    func add(_ request: UNNotificationRequest) async throws {
        if fail { throw NSError(domain: "TestDelivery", code: 1) }
        if hold {
            await withCheckedContinuation { continuation in
                pendingAdd = continuation; onAddStarted?()
            }
        }
        requests.append(request)
    }
    func remove(_ identifier: String) {
        removed.append(identifier); requests.removeAll { $0.identifier == identifier }; onRemove?()
    }
}

final class NotificationManagerTests: XCTestCase {
    func testForegroundPresentationRequestsListBannerAndOnlyConfiguredSound() {
        XCTAssertEqual(NotificationManager.presentationOptions(hasSound: false), [.banner, .list])
        XCTAssertEqual(NotificationManager.presentationOptions(hasSound: true), [.banner, .list, .sound])
    }
    func testNativeNotificationSettingsMapping() {
        let silent = NotificationCapabilities(authorizationStatus: .authorized, alertSetting: .enabled,
            alertStyle: .none, notificationCenterSetting: .enabled, soundSetting: .disabled)
        XCTAssertEqual(silent.statusKey, "permission.centerOnly")
        XCTAssertFalse(silent.canShowDesktopAlerts); XCTAssertFalse(silent.soundEnabled)
        XCTAssertTrue(silent.centerEnabled)
        let visible = NotificationCapabilities(authorizationStatus: .authorized, alertSetting: .enabled,
            alertStyle: .alert, notificationCenterSetting: .disabled, soundSetting: .enabled)
        XCTAssertTrue(visible.canShowDesktopAlerts); XCTAssertFalse(visible.centerEnabled)
        XCTAssertTrue(visible.soundEnabled)
        let quiet = NotificationCapabilities(authorizationStatus: .provisional, alertSetting: .enabled,
            alertStyle: .banner, notificationCenterSetting: .enabled, soundSetting: .enabled)
        XCTAssertEqual(quiet.permission, .provisional); XCTAssertFalse(quiet.canShowDesktopAlerts)
        let unsupported = NotificationCapabilities(authorizationStatus: .authorized, alertSetting: .notSupported,
            alertStyle: .banner, notificationCenterSetting: .notSupported, soundSetting: .notSupported)
        XCTAssertFalse(unsupported.canShowDesktopAlerts); XCTAssertFalse(unsupported.soundEnabled)
    }
    @MainActor func testQuietSubmissionReportsCapabilitiesAndRetainsDelegate() async throws {
        let suite = "KipirBannerTests.\(UUID().uuidString)"; let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let delivery = RecordingNotificationDelivery()
        let manager = NotificationManager(delivery: delivery, defaults: defaults)
        XCTAssertTrue(delivery.delegate === manager)
        XCTAssertEqual(delivery.categories.map(\.identifier), ["break"])
        delivery.style = .none; delivery.soundEnabled = false
        await manager.testNotification(enabled: { true }, sound: true)
        XCTAssertEqual(manager.capabilities.statusKey, "permission.centerOnly")
        XCTAssertEqual(manager.testResultKey, "notification.test.submittedQuiet")
        XCTAssertNil(try XCTUnwrap(delivery.requests.last).content.sound)
        XCTAssertNil(defaults.string(forKey: "lastNotificationAttempt"))
        delivery.permission = .provisional; delivery.style = .banner
        await manager.testNotification(enabled: { true }, sound: true)
        XCTAssertEqual(manager.capabilities.statusKey, "permission.quiet")
        XCTAssertEqual(manager.testResultKey, "notification.test.submittedQuiet")
        XCTAssertEqual(delivery.permissionRequests, 0)
        delivery.permission = .authorized; delivery.soundEnabled = true
        await manager.testNotification(enabled: { true }, sound: true)
        XCTAssertTrue(manager.capabilities.canShowDesktopAlerts)
        XCTAssertEqual(manager.testResultKey, "notification.test.submitted")
        XCTAssertNotNil(try XCTUnwrap(delivery.requests.last).content.sound)
        XCTAssertTrue(delivery.delegate === manager)
    }
    @MainActor func testSettingsNavigationFallsBackAndReportsFailureWithoutOpeningUI() {
        let delivery = RecordingNotificationDelivery()
        let suite = "KipirSettingsLinkTests.\(UUID().uuidString)"; let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = NotificationManager(delivery: delivery, defaults: defaults)
        var urls: [URL] = []
        manager.openNotificationSettings { url in urls.append(url); return urls.count == 2 }
        XCTAssertEqual(urls.count, 2)
        XCTAssertEqual(urls.first?.scheme, "x-apple.systempreferences")
        XCTAssertEqual(urls.first?.path, "com.apple.Notifications-Settings.extension")
        XCTAssertEqual(urls.last?.pathExtension, "app")
        XCTAssertEqual(manager.settingsNavigationKey, "notification.settings.guidance")
        manager.openNotificationSettings { _ in false }
        XCTAssertEqual(manager.settingsNavigationKey, "notification.settings.failed")
        urls = []
        manager.openNotificationSettings { url in urls.append(url); return true }
        XCTAssertEqual(urls.count, 1)
        XCTAssertEqual(manager.settingsNavigationKey, "notification.settings.guidance")
    }
    @MainActor func testQueuedRealReminderCannotOutlivePause() async {
        let suite = "KipirNotificationRace.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let delivery = RecordingNotificationDelivery()
        let manager = NotificationManager(delivery: delivery, defaults: defaults)
        await manager.refreshPermission()
        let c = BreakSchedulerTests.Clock(); var s = Settings(); s.work = 60
        let e = c.engine(s); c.step(e, seconds: 60)
        manager.sync(engine: e)
        e.perform(.togglePause); manager.sync(engine: e)
        await Task.yield()
        XCTAssertTrue(delivery.requests.isEmpty)
    }

    @MainActor func testInFlightRealReminderIsRemovedAfterMeetingStarts() async {
        let suite = "KipirNotificationFlight.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let delivery = RecordingNotificationDelivery()
        let manager = NotificationManager(delivery: delivery, defaults: defaults)
        await manager.refreshPermission()
        let c = BreakSchedulerTests.Clock(); var s = Settings(); s.work = 60
        let e = c.engine(s); c.step(e, seconds: 60)
        let started = expectation(description: "submission started")
        delivery.hold = true; delivery.onAddStarted = { started.fulfill() }
        manager.sync(engine: e)
        await fulfillment(of: [started], timeout: 2)
        e.setMeeting(true, duration: 900); manager.sync(engine: e)
        let cleaned = expectation(description: "in-flight stale request cleaned")
        delivery.onRemove = { cleaned.fulfill() }
        delivery.pendingAdd?.resume()
        await fulfillment(of: [cleaned], timeout: 2)
        XCTAssertTrue(delivery.requests.isEmpty)
    }

    @MainActor func testMeetingSuppressesReminderAndNeverReplaysItAfterwards() async {
        let suite = "KipirNotificationMeeting.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let delivery = RecordingNotificationDelivery()
        let manager = NotificationManager(delivery: delivery, defaults: defaults)
        await manager.refreshPermission()
        let c = BreakSchedulerTests.Clock(); var s = Settings(); s.work = 60; s.naturalBreak = 0
        let e = c.engine(s); c.step(e, seconds: 30)
        e.setMeeting(true); c.step(e, seconds: 30); manager.sync(engine: e)
        await Task.yield()
        XCTAssertEqual(e.checkpoint.phase, .due); XCTAssertTrue(delivery.requests.isEmpty)
        XCTAssertEqual(defaults.string(forKey: "lastNotificationAttempt"), e.checkpoint.dueID?.uuidString)
        // Ending the meeting resumes normal behavior without replaying the silenced episode.
        e.setMeeting(false); manager.sync(engine: e); c.step(e); manager.sync(engine: e)
        await Task.yield()
        XCTAssertNotNil(e.reminderID); XCTAssertTrue(delivery.requests.isEmpty)
        // The next episode notifies normally, and a restarted manager still remembers the silenced one.
        e.perform(.skip); c.step(e, seconds: 60); manager.sync(engine: e)
        await Task.yield(); await Task.yield()
        XCTAssertEqual(delivery.requests.map(\.identifier), [e.reminderID?.uuidString].compactMap { $0 })
        // A reminder delivered before the meeting is withdrawn when the meeting starts.
        e.setMeeting(true); manager.sync(engine: e)
        XCTAssertTrue(delivery.requests.isEmpty)
    }

    @MainActor func testTestNotificationIsolationAndPermissionFailures() async throws {
        let suite = "KipirNotificationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let id = UUID().uuidString
        defaults.set(id, forKey: "lastNotificationAttempt")
        let delivery = RecordingNotificationDelivery()
        let manager = NotificationManager(delivery: delivery, defaults: defaults)
        for permission in [NotificationPermission.denied, .unknown] {
            delivery.permission = permission
            await manager.testNotification(enabled: { true }, sound: false)
            XCTAssertTrue(delivery.requests.isEmpty)
            XCTAssertEqual(manager.testResultKey, permission == .denied ? "permission.denied" : "permission.unknown")
        }
        delivery.permission = .authorized
        await manager.testNotification(enabled: { false }, sound: false)
        XCTAssertEqual(manager.testResultKey, "notification.test.disabled")
        XCTAssertTrue(delivery.requests.isEmpty)
        await manager.testNotification(enabled: { true }, sound: false)
        let request = try XCTUnwrap(delivery.requests.first)
        XCTAssertTrue(request.identifier.hasPrefix("kipir.test."))
        XCTAssertTrue(request.content.categoryIdentifier.isEmpty)
        XCTAssertTrue(request.content.userInfo.isEmpty)
        XCTAssertNil(request.trigger)
        XCTAssertNil(request.content.sound)
        XCTAssertEqual(manager.testResultKey, "notification.test.submitted")
        delivery.fail = true
        await manager.testNotification(enabled: { true }, sound: false)
        XCTAssertEqual(manager.testResultKey, "notification.test.failed")
        XCTAssertEqual(defaults.string(forKey: "lastNotificationAttempt"), id)
        XCTAssertTrue(delivery.removed.isEmpty)
        XCTAssertEqual(delivery.permissionRequests, 0)
        let c = BreakSchedulerTests.Clock(); var s = Settings(); s.work = 60
        let e = c.engine(s); c.step(e, seconds: 60)
        let before = e.checkpoint
        delivery.fail = false
        await manager.testNotification(enabled: { true }, sound: true)
        XCTAssertEqual(e.checkpoint.dueID, before.dueID)
        XCTAssertEqual(e.today, before.today)
        XCTAssertEqual(e.activeWork, before.activeWork)
        manager.sync(engine: e)
        await Task.yield()
        XCTAssertEqual(defaults.string(forKey: "lastNotificationAttempt"), e.reminderID?.uuidString)
        XCTAssertEqual(delivery.requests.last?.content.categoryIdentifier, "break")
    }
}
#endif
