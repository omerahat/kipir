import XCTest
#if SWIFT_PACKAGE
@testable import KipirCore
#endif

/// Natural-break (DECISIONS 018), working-hours (DECISIONS 019) and reliability tests (scheduler workstream).
final class NaturalBreakTests: XCTestCase {
    typealias Clock = BreakSchedulerTests.Clock

    // MARK: Helpers

    private func calendar(_ zone: String) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: zone)!
        return c
    }
    private func utc(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }
    /// Local wall time in `cal` (default Istanbul). 2027-01-15 is a Friday.
    private func local(_ cal: Calendar, _ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, _ s: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi, second: s))!
    }
    private func clock(_ zone: String = "Europe/Istanbul", at date: ((Calendar) -> Date)? = nil) -> Clock {
        let c = Clock(); c.calendar = calendar(zone)
        c.date = date?(c.calendar) ?? local(c.calendar, 2027, 1, 15, 11, 0)
        return c
    }
    private func hours(start: Int = 9 * 60, end: Int = 18 * 60, days: [Int] = [2, 3, 4, 5, 6]) -> WorkingHours {
        WorkingHours(enabled: true, weekdays: days, start: start, end: end)
    }
    private func settings(work: Double = 2700, hours: WorkingHours = WorkingHours()) -> Settings {
        var s = Settings(); s.work = work; s.workingHours = hours; return s
    }
    /// Work for `work` seconds with input, then `away` seconds without any input.
    private func away(_ c: Clock, _ e: BreakScheduler, work: Int = 20, idle: Int) {
        c.step(e, seconds: work); c.step(e, seconds: idle, input: false)
    }

    // MARK: Natural break thresholds

    func testBelowExactlyAndAboveThreshold() {
        let c = clock(); let e = c.engine(); c.step(e, seconds: 20)
        c.step(e, seconds: 599, input: false)
        XCTAssertEqual(e.activeWork, 20); XCTAssertFalse(e.consumeNaturalBreak())
        c.step(e, seconds: 1, input: false)
        XCTAssertEqual(e.activeWork, 0); XCTAssertEqual(e.status, .idle)
        XCTAssertEqual(e.remaining, 2700)
        c.step(e, seconds: 100, input: false)
        XCTAssertEqual(e.activeWork, 0)
    }
    func testActiveSecondsAndBreaksAreNeverTouchedByNaturalReset() {
        let c = clock(); let e = c.engine(); away(c, e, idle: 700)
        XCTAssertEqual(e.activeWork, 0)
        XCTAssertEqual(e.today.activeSeconds, 20); XCTAssertEqual(e.today.breaks, 0)
        XCTAssertEqual(e.checkpoint.completedShorts, 0)
    }
    func testRepeatedShortIdlePeriodsNeverReset() {
        let c = clock(); let e = c.engine()
        for _ in 0..<12 { c.step(e, seconds: 5); c.step(e, seconds: 300, input: false) }
        XCTAssertGreaterThan(e.activeWork, 55)
        XCTAssertFalse(e.consumeNaturalBreak())
    }
    func testLongReadingWithoutInputBelowThresholdKeepsInterval() {
        let c = clock(); let e = c.engine(); c.step(e, seconds: 120)
        c.step(e, seconds: 580, input: false); c.step(e, seconds: 3)
        c.step(e, seconds: 580, input: false)
        XCTAssertEqual(e.activeWork, 123, accuracy: 0.001)
    }
    func testThresholdIsClampedStrictlyAboveAFK() {
        var s = Settings(); s.afk = 300; s.naturalBreak = 300     // effective 360
        let c = clock(); var e = c.engine(s); away(c, e, idle: 359)
        XCTAssertEqual(e.activeWork, 20)
        c.step(e, seconds: 1, input: false); XCTAssertEqual(e.activeWork, 0)
        s.afk = 600; s.naturalBreak = 300                           // effective 660
        let d = clock(); e = d.engine(s); away(d, e, idle: 659)
        XCTAssertEqual(e.activeWork, 20)
        d.step(e, seconds: 1, input: false); XCTAssertEqual(e.activeWork, 0)
    }
    func testDisabledNaturalBreakNeverResets() {
        var s = Settings(); s.naturalBreak = 0
        let c = clock(); let e = c.engine(s); away(c, e, idle: 5000)
        XCTAssertEqual(e.activeWork, 20)
        c.step(e); XCTAssertFalse(e.consumeNaturalBreak())
    }
    func testNoNoticeAndNoResetWhenNothingToReset() {
        let c = clock(); let e = c.engine(); c.step(e, seconds: 5); e.perform(.reset)
        c.step(e, seconds: 700, input: false); c.step(e)
        XCTAssertFalse(e.consumeNaturalBreak())
    }

    // MARK: Natural break and scheduler state

    func testPendingDueReminderIsWithdrawnWithoutStatisticsChange() {
        var s = Settings(); s.shortBreak = 10; s.work = 60
        let c = clock(); let e = c.engine(s)
        e.perform(.startBreak); c.step(e, seconds: 10)
        XCTAssertEqual(e.today.breaks, 1); XCTAssertNotNil(e.consumeBreakCompletion())
        c.step(e, seconds: 60); XCTAssertEqual(e.status, .due)
        XCTAssertNotNil(e.reminderID)
        let active = e.today.activeSeconds
        c.step(e, seconds: 600, input: false)
        XCTAssertNil(e.reminderID); XCTAssertNil(e.checkpoint.dueID)
        XCTAssertEqual(e.activeWork, 0); XCTAssertEqual(e.checkpoint.phase, .working)
        XCTAssertEqual(e.today.breaks, 1); XCTAssertEqual(e.checkpoint.completedShorts, 1)
        XCTAssertEqual(e.today.activeSeconds, active)
        XCTAssertNil(e.consumeBreakCompletion())
    }
    func testActiveBreakIsNotNaturalBreakAndCountsDownNormally() {
        let c = clock(); let e = c.engine(); c.step(e, seconds: 20)
        e.perform(.startBreak); c.step(e, seconds: 50, input: false)
        XCTAssertEqual(e.status, .onBreak); XCTAssertEqual(e.remaining, 70)
        c.step(e, seconds: 70, input: false)
        XCTAssertEqual(e.today.breaks, 1); XCTAssertEqual(e.checkpoint.completedShorts, 1)
        XCTAssertNotNil(e.consumeBreakCompletion())
        c.step(e, seconds: 700, input: false); c.step(e)
        XCTAssertFalse(e.consumeNaturalBreak()); XCTAssertEqual(e.today.breaks, 1)
    }
    func testSnoozedReminderIsReset() {
        var s = Settings(); s.work = 60; s.snooze = 60
        let c = clock(); let e = c.engine(s); c.step(e, seconds: 60); e.perform(.snooze)
        XCTAssertTrue(e.checkpoint.snoozed)
        c.step(e, seconds: 600, input: false)
        XCTAssertFalse(e.checkpoint.snoozed); XCTAssertEqual(e.checkpoint.target, 60)
        XCTAssertEqual(e.activeWork, 0); XCTAssertNil(e.reminderID)
        c.step(e); XCTAssertTrue(e.consumeNaturalBreak())
    }
    func testMeetingModeDoesNotAccrueAndChainNeedsFreshInput() {
        let c = clock(); let e = c.engine(); c.step(e, seconds: 20)
        e.perform(.toggleMeeting); c.step(e, seconds: 700, input: false)
        XCTAssertEqual(e.activeWork, 20)
        e.perform(.toggleMeeting)
        c.step(e, seconds: 700, input: false)       // chain tainted: no input since the meeting
        XCTAssertEqual(e.activeWork, 20)
        c.step(e); c.step(e, seconds: 599, input: false); XCTAssertEqual(e.activeWork, 21)
        c.step(e, seconds: 1, input: false); XCTAssertEqual(e.activeWork, 0)
    }
    func testPauseAndResumeDoNotAccrueAndRestartChain() {
        let c = clock(); let e = c.engine(); c.step(e, seconds: 20)
        e.perform(.togglePause); c.step(e, seconds: 700, input: false)
        XCTAssertEqual(e.activeWork, 20); XCTAssertEqual(e.status, .paused)
        e.perform(.togglePause)
        c.step(e, seconds: 700, input: false); XCTAssertEqual(e.activeWork, 20)
        c.step(e); c.step(e, seconds: 600, input: false); XCTAssertEqual(e.activeWork, 0)
    }
    func testNaturalBreakNeverTouchesPausedOrMeetingCountersWhileActive() {
        let c = clock(); let e = c.engine(); c.step(e, seconds: 20)
        c.step(e, seconds: 300, input: false)
        e.perform(.togglePause); e.perform(.togglePause)   // restarts as tainted
        c.step(e, seconds: 400, input: false)
        XCTAssertEqual(e.activeWork, 20)
    }

    // MARK: Verified away time

    func testLockSuspensionAccruesAndUnlockInputDeliversNoticeOnce() {
        let c = clock(); let e = c.engine(); c.step(e, seconds: 20)
        e.setSuspended(true); c.step(e, seconds: 600, input: false)
        XCTAssertEqual(e.activeWork, 0); XCTAssertEqual(e.status, .suspended)
        e.setSuspended(false)
        XCTAssertFalse(e.consumeNaturalBreak())          // not before the user provides input
        c.step(e)
        XCTAssertTrue(e.consumeNaturalBreak()); XCTAssertFalse(e.consumeNaturalBreak())
    }
    func testSuspensionAccruesEvenWhenIdleCounterIsUnreliable() {
        let c = clock(); let e = c.engine(); c.step(e, seconds: 20)
        e.setSuspended(true)
        c.step(e, seconds: 600, input: true)             // idle pinned at 0 under a lock: still verified away
        XCTAssertEqual(e.activeWork, 0)
    }
    func testUnlockKeypressAfterAlmostThresholdEndsChain() {
        let c = clock(); let e = c.engine(); c.step(e, seconds: 20)
        e.setSuspended(true); c.step(e, seconds: 590, input: false)
        c.time += 0.5; c.date += 0.5; c.idle = 0.1       // keypress, then the unlock event arrives
        e.setSuspended(false)
        c.step(e, seconds: 30, input: false)             // would cross 600 if the keypress were ignored
        XCTAssertGreaterThan(e.activeWork, 0)
    }
    func testUnknownGapTaintsUntilNewInput() {
        let c = clock(); let e = c.engine(); c.step(e, seconds: 20)
        c.step(e, seconds: 300, input: false)
        c.time += 500; c.date += 500; c.idle += 500; e.tick()     // heartbeat stall: unknown, uncredited
        c.step(e, seconds: 700, input: false)
        XCTAssertEqual(e.activeWork, 20)
        c.step(e); c.step(e, seconds: 600, input: false)
        XCTAssertEqual(e.activeWork, 0)
    }
    func testUnknownGapWhileSuspendedTaints() {
        let c = clock(); let e = c.engine(); c.step(e, seconds: 20)
        e.setSuspended(true); c.step(e, seconds: 300, input: false)
        c.time += 400; c.date += 400; c.idle += 400; e.tick()
        c.step(e, seconds: 700, input: false)
        XCTAssertEqual(e.activeWork, 20)
    }
    func testInvalidSamplesTaintTheChain() {
        let c = clock(); let e = c.engine(); c.step(e, seconds: 20)
        c.step(e, seconds: 500, input: false)
        c.idle = .nan; c.time += 1; e.tick()
        c.idle = 501; c.step(e, seconds: 0); c.idle = 502
        c.step(e, seconds: 300, input: false)
        XCTAssertEqual(e.activeWork, 20)
        c.time -= 100; e.tick()                                     // backward clock
        c.step(e, seconds: 700, input: false); XCTAssertEqual(e.activeWork, 20)
    }
    func testSleepWithoutUptimeAdvanceDoesNotAccrue() {
        let c = clock(); let e = c.engine(); c.step(e, seconds: 20)
        e.setSuspended(true)
        c.date += 8 * 3600; c.idle += 8 * 3600                      // wall clock and idle advance, uptime does not
        e.setSuspended(false)
        c.step(e, seconds: 5, input: false)
        XCTAssertEqual(e.activeWork, 20); XCTAssertFalse(e.consumeNaturalBreak())
        c.step(e, seconds: 500, input: false); XCTAssertEqual(e.activeWork, 20)
    }
    func testWallClockJumpDoesNotAffectMonotonicAccrual() {
        let c = clock(); let e = c.engine(); c.step(e, seconds: 20)
        c.step(e, seconds: 300, input: false)
        c.date += 7200; c.step(e, seconds: 299, input: false)
        XCTAssertEqual(e.activeWork, 20)
        c.date -= 86400 * 3; c.step(e, seconds: 1, input: false)
        XCTAssertEqual(e.activeWork, 0)
    }
    func testDayRolloverKeepsAwayChainButDoesNotCreditCrossingSample() {
        let c = clock(at: { self.local($0, 2027, 1, 15, 23, 55) }); let e = c.engine()
        c.step(e, seconds: 20); c.step(e, seconds: 300, input: false)   // crosses local midnight at 5:00 in
        XCTAssertEqual(e.activeWork, 20); XCTAssertEqual(e.today.activeSeconds, 0)
        c.step(e, seconds: 300, input: false)
        XCTAssertEqual(e.activeWork, 0); XCTAssertEqual(e.today.breaks, 0)
        c.step(e, seconds: 20); XCTAssertEqual(e.today.activeSeconds, 20 - 1 + 1, accuracy: 1)
    }
    func testRestartViaCheckpointStartsTaintedAndNeverCreditsOfflineTime() {
        let c = clock(); let e = c.engine(); c.step(e, seconds: 20)
        c.step(e, seconds: 300, input: false)
        let saved = e.checkpoint; c.time += 7200; c.date += 7200; c.idle += 7200
        let r = c.engine(checkpoint: saved)
        XCTAssertEqual(r.activeWork, 20)
        c.step(r, seconds: 900, input: false)
        XCTAssertEqual(r.activeWork, 20); XCTAssertFalse(r.consumeNaturalBreak())
        c.step(r); c.step(r, seconds: 600, input: false)
        XCTAssertEqual(r.activeWork, 0)
    }
    func testNoticeFiresExactlyOnceAndOnlyOnReturnInput() {
        let c = clock(); let e = c.engine(); away(c, e, idle: 800)
        XCTAssertEqual(e.activeWork, 0)
        XCTAssertFalse(e.consumeNaturalBreak())
        c.step(e, seconds: 50, input: false); XCTAssertFalse(e.consumeNaturalBreak())
        c.step(e)
        XCTAssertTrue(e.consumeNaturalBreak()); XCTAssertFalse(e.consumeNaturalBreak())
        c.step(e, seconds: 5); XCTAssertFalse(e.consumeNaturalBreak())
    }
    func testNaturalResetIsNotRepeatedWithinOneAwaySpan() {
        let c = clock(); let e = c.engine(); away(c, e, idle: 600)
        let id = e.checkpoint
        c.step(e, seconds: 1500, input: false)
        XCTAssertEqual(e.checkpoint.activeWork, id.activeWork)
        XCTAssertFalse(e.consumeNaturalBreak())
        c.step(e); XCTAssertTrue(e.consumeNaturalBreak())
        c.step(e, seconds: 600, input: false)         // a new away span with fresh work resets again, once
        XCTAssertEqual(e.activeWork, 0); XCTAssertFalse(e.consumeNaturalBreak())
        c.step(e); XCTAssertTrue(e.consumeNaturalBreak()); XCTAssertFalse(e.consumeNaturalBreak())
    }
    func testNoPhantomBreakCompletionOrCycleAdvance() {
        let c = clock(); let e = c.engine(); away(c, e, idle: 800); c.step(e)
        XCTAssertNil(e.consumeBreakCompletion())
        XCTAssertNotEqual(e.status, .onBreak)
        XCTAssertEqual(e.today.breaks, 0); XCTAssertEqual(e.checkpoint.completedShorts, 0)
        XCTAssertFalse(e.nextBreakIsLong)
    }
    func testPendingWorkBufferIsDiscardedOnReset() {
        let c = clock(); let e = c.engine(); c.step(e, seconds: 20)
        c.step(e, seconds: 30, input: false)             // provisional, unconfirmed tail
        c.step(e, seconds: 570, input: false)
        XCTAssertEqual(e.activeWork, 0)
        c.step(e); XCTAssertEqual(e.activeWork, 1, accuracy: 1.001)
    }
    func testAppActionsEndTheChain() {
        let c = clock(); let e = c.engine(); c.step(e, seconds: 20)
        c.step(e, seconds: 590, input: false)
        c.idle = 0; c.time += 1; c.date += 1; e.perform(.togglePause); e.perform(.togglePause)
        c.step(e, seconds: 60, input: false)
        XCTAssertEqual(e.activeWork, 21)                 // the input tick credited 1 s; the chain restarted
    }

    // MARK: WorkingHours.contains

    func testContainsDisabledAlwaysTrue() {
        let cal = calendar("Europe/Istanbul")
        XCTAssertTrue(WorkingHours().contains(local(cal, 2027, 1, 16, 3, 0), calendar: cal))
    }
    func testContainsBoundaryMinutes() {
        let cal = calendar("Europe/Istanbul"); let w = hours()
        XCTAssertFalse(w.contains(local(cal, 2027, 1, 15, 8, 59, 59), calendar: cal))
        XCTAssertTrue(w.contains(local(cal, 2027, 1, 15, 9, 0), calendar: cal))
        XCTAssertTrue(w.contains(local(cal, 2027, 1, 15, 17, 59, 59), calendar: cal))
        XCTAssertFalse(w.contains(local(cal, 2027, 1, 15, 18, 0), calendar: cal))
    }
    func testContainsWeekdayExclusion() {
        let cal = calendar("Europe/Istanbul"); let w = hours()
        XCTAssertTrue(w.contains(local(cal, 2027, 1, 15, 12, 0), calendar: cal))   // Friday
        XCTAssertFalse(w.contains(local(cal, 2027, 1, 16, 12, 0), calendar: cal))  // Saturday
        XCTAssertFalse(w.contains(local(cal, 2027, 1, 17, 12, 0), calendar: cal))  // Sunday
        XCTAssertTrue(w.contains(local(cal, 2027, 1, 18, 12, 0), calendar: cal))   // Monday
    }
    func testContainsMidnightCrossingBelongsToStartDay() {
        let cal = calendar("Europe/Istanbul"); let w = hours(start: 22 * 60, end: 6 * 60, days: [6]) // Friday only
        XCTAssertTrue(w.contains(local(cal, 2027, 1, 15, 23, 0), calendar: cal))
        XCTAssertTrue(w.contains(local(cal, 2027, 1, 16, 2, 0), calendar: cal))    // Saturday 02:00 belongs to Friday
        XCTAssertFalse(w.contains(local(cal, 2027, 1, 16, 6, 0), calendar: cal))
        XCTAssertFalse(w.contains(local(cal, 2027, 1, 16, 23, 0), calendar: cal))  // Saturday evening is not Friday
        XCTAssertFalse(w.contains(local(cal, 2027, 1, 15, 3, 0), calendar: cal))   // Friday 03:00 belongs to Thursday
        XCTAssertFalse(w.contains(local(cal, 2027, 1, 15, 21, 59), calendar: cal))
        let sunday = hours(start: 22 * 60, end: 6 * 60, days: [1])                  // Sunday night spills into Monday
        XCTAssertTrue(sunday.contains(local(cal, 2027, 1, 18, 1, 0), calendar: cal))
        let saturday = hours(start: 22 * 60, end: 6 * 60, days: [7])                // Saturday spills into Sunday (wrap)
        XCTAssertTrue(saturday.contains(local(cal, 2027, 1, 17, 1, 0), calendar: cal))
    }
    func testContainsInterpretsLocalTimeAcrossTimeZones() {
        let w = hours()
        let instant = utc("2027-01-15T07:00:00Z")           // 10:00 Istanbul (UTC+3), 02:00 New York
        XCTAssertTrue(w.contains(instant, calendar: calendar("Europe/Istanbul")))
        XCTAssertFalse(w.contains(instant, calendar: calendar("America/New_York")))
    }
    func testContainsAcrossDaylightSavingTransitions() {
        let ny = calendar("America/New_York")
        let night = hours(start: 3 * 60, end: 4 * 60, days: [1])   // Sunday 03:00-04:00 local
        XCTAssertFalse(night.contains(utc("2027-03-14T06:59:59Z"), calendar: ny))  // 01:59:59 EST
        XCTAssertTrue(night.contains(utc("2027-03-14T07:00:00Z"), calendar: ny))   // 03:00 EDT, same instant+1s
        XCTAssertFalse(night.contains(utc("2027-03-14T08:00:00Z"), calendar: ny))  // 04:00 EDT
        let early = hours(start: 60, end: 2 * 60, days: [1])       // 01:00-02:00 on fall-back day (hour repeats)
        XCTAssertTrue(early.contains(utc("2027-11-07T05:30:00Z"), calendar: ny))   // 01:30 EDT
        XCTAssertTrue(early.contains(utc("2027-11-07T06:30:00Z"), calendar: ny))   // 01:30 EST
        XCTAssertFalse(early.contains(utc("2027-11-07T07:30:00Z"), calendar: ny))  // 02:30 EST
        let day = hours()
        XCTAssertFalse(day.contains(utc("2027-03-15T12:59:00Z"), calendar: ny))    // 08:59 EDT Monday
        XCTAssertTrue(day.contains(utc("2027-03-15T13:00:00Z"), calendar: ny))     // 09:00 EDT
    }
    func testContainsFailsSafeOnInvalidConfiguration() {
        let cal = calendar("Europe/Istanbul")
        let bad = WorkingHours(enabled: true, weekdays: [], start: 5000, end: 5000)  // validated to defaults
        XCTAssertTrue(bad.contains(local(cal, 2027, 1, 15, 10, 0), calendar: cal))
        XCTAssertFalse(bad.contains(local(cal, 2027, 1, 15, 20, 0), calendar: cal))
    }

    // MARK: Working hours in the scheduler

    func testInsideAndOutsideWindowCredit() {
        let s = settings(hours: hours())
        let inside = clock(at: { self.local($0, 2027, 1, 15, 10, 0) }); let a = inside.engine(s)
        inside.step(a, seconds: 20); XCTAssertEqual(a.activeWork, 20); XCTAssertEqual(a.status, .working)
        let outside = clock(at: { self.local($0, 2027, 1, 15, 20, 0) }); let b = outside.engine(s)
        XCTAssertEqual(b.status, .offHours)
        outside.step(b, seconds: 20); XCTAssertEqual(b.activeWork, 0); XCTAssertEqual(b.today.activeSeconds, 0)
    }
    func testLeavingTheWindowDiscardsCrossingSampleAndPreservesPhase() {
        let c = clock(at: { self.local($0, 2027, 1, 15, 17, 59, 30) }); let e = c.engine(settings(hours: hours()))
        c.step(e, seconds: 29); XCTAssertEqual(e.activeWork, 29)
        c.step(e, seconds: 1)                            // 18:00:00 crossing sample
        XCTAssertEqual(e.status, .offHours); XCTAssertEqual(e.activeWork, 29)
        c.step(e, seconds: 600); XCTAssertEqual(e.activeWork, 29)
        XCTAssertEqual(e.checkpoint.phase, .working)
    }
    func testEnteringTheWindowRebaselinesWithoutCreditingCrossingSample() {
        let c = clock(at: { self.local($0, 2027, 1, 15, 8, 59, 40) }); let e = c.engine(settings(hours: hours()))
        c.step(e, seconds: 19); XCTAssertEqual(e.activeWork, 0); XCTAssertEqual(e.status, .offHours)
        c.step(e, seconds: 1)                            // 09:00:00 enters
        XCTAssertEqual(e.activeWork, 0); XCTAssertEqual(e.status, .working)
        c.step(e, seconds: 5); XCTAssertEqual(e.activeWork, 5)
    }
    func testNoDueTransitionOrReminderOffHours() {
        var w = hours(); w.end = 18 * 60
        let c = clock(at: { self.local($0, 2027, 1, 15, 17, 59, 50) })
        let e = c.engine(settings(work: 60, hours: w))
        e.updateSettings(settings(work: 60, hours: w))
        c.step(e, seconds: 9)                            // credited, still working
        XCTAssertEqual(e.status, .working)
        c.step(e, seconds: 200)
        XCTAssertEqual(e.status, .offHours); XCTAssertNil(e.reminderID)
        XCTAssertEqual(e.checkpoint.phase, .working); XCTAssertNil(e.checkpoint.dueID)
    }
    func testExistingDueEpisodeIsPreservedOffHoursAndRestoredWithSameID() {
        let c = clock(at: { self.local($0, 2027, 1, 15, 17, 58) }); let s = settings(work: 60, hours: hours())
        let e = c.engine(s); c.step(e, seconds: 60)
        XCTAssertEqual(e.status, .due); let id = e.reminderID; XCTAssertNotNil(id)
        c.step(e, seconds: 120)                          // crosses 18:00
        XCTAssertEqual(e.status, .offHours); XCTAssertNil(e.reminderID)
        XCTAssertEqual(e.checkpoint.phase, .due); XCTAssertEqual(e.checkpoint.dueID, id)
        e.updateSettings(s)                              // an unrelated settings write must not drop Due
        XCTAssertEqual(e.checkpoint.phase, .due)
        c.date = self.local(c.calendar, 2027, 1, 18, 9, 0); c.time += 3; e.tick()
        XCTAssertEqual(e.status, .due); XCTAssertEqual(e.reminderID, id)
    }
    func testNaturalBreakDoesNotAccrueOffHours() {
        let c = clock(at: { self.local($0, 2027, 1, 15, 17, 58) }); let e = c.engine(settings(hours: hours()))
        c.step(e, seconds: 20); c.step(e, seconds: 3000, input: false)
        XCTAssertEqual(e.status, .offHours); XCTAssertEqual(e.activeWork, 20)
        XCTAssertFalse(e.consumeNaturalBreak())
    }
    func testRestartWhileOffHoursKeepsStateAndCreditsNothing() {
        let s = settings(work: 60, hours: hours())
        let c = clock(at: { self.local($0, 2027, 1, 15, 17, 58) }); let e = c.engine(s)
        c.step(e, seconds: 60); let saved = e.checkpoint
        c.date = local(c.calendar, 2027, 1, 15, 23, 0); c.time += 4 * 3600
        let r = c.engine(s, checkpoint: saved)
        XCTAssertEqual(r.status, .offHours); XCTAssertNil(r.reminderID)
        XCTAssertEqual(r.activeWork, 60); c.step(r, seconds: 100)
        XCTAssertEqual(r.activeWork, 60); XCTAssertEqual(r.checkpoint.phase, .due)
        XCTAssertEqual(r.today.activeSeconds, saved.today.activeSeconds)
    }
    func testBreakStartedInsideWindowFinishesExactlyOnceAfterItEnds() {
        var s = settings(hours: hours()); s.shortBreak = 30
        let c = clock(at: { self.local($0, 2027, 1, 15, 17, 59, 50) }); let e = c.engine(s)
        c.step(e, seconds: 3); e.perform(.startBreak)
        c.step(e, seconds: 15)                           // now 18:00:08, off hours mid break
        XCTAssertEqual(e.status, .onBreak); XCTAssertEqual(e.remaining, 15, accuracy: 0.001)
        c.step(e, seconds: 15)
        XCTAssertEqual(e.today.breaks, 1); XCTAssertEqual(e.checkpoint.completedShorts, 1)
        XCTAssertNotNil(e.consumeBreakCompletion()); XCTAssertNil(e.consumeBreakCompletion())
        XCTAssertEqual(e.status, .offHours)
        c.step(e, seconds: 120); XCTAssertEqual(e.today.breaks, 1)
    }
    func testManualBreakAllowedOffHours() {
        let c = clock(at: { self.local($0, 2027, 1, 15, 22, 0) }); let e = c.engine(settings(hours: hours()))
        e.perform(.startBreak); XCTAssertEqual(e.status, .onBreak)
        c.step(e, seconds: 10); XCTAssertEqual(e.remaining, 110, accuracy: 0.001)
    }
    func testStatusPriorityOverOffHours() {
        let s = settings(hours: hours())
        let c = clock(at: { self.local($0, 2027, 1, 15, 22, 0) }); let e = c.engine(s)
        XCTAssertEqual(e.status, .offHours)
        e.perform(.toggleMeeting); XCTAssertEqual(e.status, .meeting)
        e.perform(.togglePause); XCTAssertEqual(e.status, .paused)
        e.setSuspended(true); XCTAssertEqual(e.status, .suspended)
        e.setSuspended(false); e.perform(.togglePause); e.perform(.toggleMeeting)
        XCTAssertEqual(e.status, .offHours)
        e.perform(.startBreak); XCTAssertEqual(e.status, .onBreak)
    }
    func testMeetingAndPauseKeepOverridingInsideWindow() {
        let c = clock(); let e = c.engine(settings(hours: hours())); c.step(e, seconds: 10)
        e.perform(.togglePause); c.step(e, seconds: 30); XCTAssertEqual(e.activeWork, 10)
        e.perform(.togglePause); e.perform(.toggleMeeting)
        c.step(e, seconds: 30); XCTAssertEqual(e.activeWork, 10); XCTAssertEqual(e.status, .meeting)
        e.perform(.toggleMeeting); c.step(e, seconds: 2); XCTAssertEqual(e.activeWork, 12)
    }
    func testTogglingWorkingHoursInSettingsRebaselines() {
        let c = clock(at: { self.local($0, 2027, 1, 15, 22, 0) }); let e = c.engine(); c.step(e, seconds: 10)
        XCTAssertEqual(e.activeWork, 10)
        e.updateSettings(settings(hours: hours()))
        XCTAssertEqual(e.status, .offHours)
        c.step(e, seconds: 20); XCTAssertEqual(e.activeWork, 10)
        c.time += 1; c.date += 1; e.updateSettings(settings())         // disabled: back in, crossing not credited
        XCTAssertEqual(e.status, .working); XCTAssertEqual(e.activeWork, 10)
        c.step(e, seconds: 4); XCTAssertEqual(e.activeWork, 14)
    }
    func testTimeZoneChangeIsReadInNewLocalTime() {
        let previous = NSTimeZone.default
        defer { NSTimeZone.default = previous }
        NSTimeZone.default = TimeZone(identifier: "Europe/Istanbul")!
        let s = settings(hours: hours())
        let c = Clock(); c.calendar = .autoupdatingCurrent
        c.date = utc("2027-01-15T07:00:00Z")             // 10:00 Istanbul
        let e = c.engine(s)
        XCTAssertEqual(e.status, .working)
        NSTimeZone.default = TimeZone(identifier: "America/New_York")!   // same instant: 02:00 local
        c.step(e, seconds: 3)                            // transition tick rebaselines
        XCTAssertEqual(e.status, .offHours); XCTAssertEqual(e.activeWork, 0)
        NSTimeZone.default = TimeZone(identifier: "Europe/Istanbul")!
        c.step(e, seconds: 1); XCTAssertEqual(e.status, .working); XCTAssertEqual(e.activeWork, 0)
        c.step(e, seconds: 3); XCTAssertEqual(e.activeWork, 3)
    }
    func testDaylightSavingDayDoesNotCreateSpuriousWindowTransitions() {
        let ny = "America/New_York"
        let w = hours(start: 60, end: 4 * 60, days: [1])                // Sunday 01:00-04:00
        let c = clock(ny, at: { _ in self.utc("2027-03-14T06:59:50Z") }) // 01:59:50 EST
        let e = c.engine(settings(hours: w))
        c.step(e, seconds: 20)                           // wall clock jumps 02:00 -> 03:00 during this span
        XCTAssertEqual(e.status, .working); XCTAssertEqual(e.activeWork, 20)
        let enter = hours(start: 3 * 60, end: 5 * 60, days: [1])
        let d = clock(ny, at: { _ in self.utc("2027-03-14T06:59:50Z") }); let f = d.engine(settings(hours: enter))
        XCTAssertEqual(f.status, .offHours)
        d.step(f, seconds: 15)                           // 03:00:00 EDT reached after 10 s
        XCTAssertEqual(f.status, .working); XCTAssertEqual(f.activeWork, 5)
    }

    // MARK: Persistence

    func testWorkingHoursAndNaturalBreakRoundTripThroughLocalStore() {
        let suite = "KipirTests.NaturalBreak.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = LocalStore(defaults: defaults)
        var s = Settings(); s.naturalBreak = 900
        s.workingHours = WorkingHours(enabled: true, weekdays: [1, 7], start: 22 * 60, end: 6 * 60)
        store.save(s)
        let loaded = store.loadSettings()
        XCTAssertEqual(loaded.naturalBreak, 900)
        XCTAssertEqual(loaded.workingHours, s.workingHours)
        XCTAssertEqual(loaded, s.validated())
        // Invalid persisted window and threshold recover to safe defaults without touching other values.
        var bad = Settings(); bad.work = 3000; bad.naturalBreak = 123
        bad.workingHours = WorkingHours(enabled: true, weekdays: [0, 9], start: 3000, end: 3000)
        store.save(bad)
        let recovered = store.loadSettings()
        XCTAssertEqual(recovered.work, 3000); XCTAssertEqual(recovered.naturalBreak, 600)
        XCTAssertEqual(recovered.workingHours.weekdays, [2, 3, 4, 5, 6])
        XCTAssertEqual(recovered.workingHours.start, 540); XCTAssertEqual(recovered.workingHours.end, 1080)
    }
    func testNaturalBreakResetIsPersistableAndNoticeIsNot() {
        let suite = "KipirTests.NaturalBreak.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = LocalStore(defaults: defaults)
        let c = clock(); let e = c.engine(); away(c, e, idle: 700)
        store.save(e.checkpoint)
        let restored = c.engine(checkpoint: store.loadCheckpoint())
        XCTAssertEqual(restored.activeWork, 0); XCTAssertEqual(restored.today.activeSeconds, 20)
        c.step(restored); XCTAssertFalse(restored.consumeNaturalBreak())
    }

    // MARK: Reliability audit regressions

    func testRepeatedSameInstantTicksDoNotTaintTheChain() {
        let c = clock(); let e = c.engine(); c.step(e, seconds: 20)
        c.step(e, seconds: 300, input: false)
        e.tick(); e.tick(); e.perform(.snooze)           // no-ops at the same instant
        c.step(e, seconds: 300, input: false)
        XCTAssertEqual(e.activeWork, 0)
    }
    func testDueReminderSurvivesSleepWakeWithSameEpisode() {
        var s = Settings(); s.work = 60
        let c = clock(); let e = c.engine(s); c.step(e, seconds: 60); let id = e.reminderID
        e.setSuspended(true); c.time += 5; c.date += 8 * 3600; c.idle += 8 * 3600
        XCTAssertNil(e.reminderID)
        e.setSuspended(false)
        XCTAssertEqual(e.reminderID, id)
        XCTAssertEqual(e.today.breaks, 0)
    }
    func testBreakInterruptedByLockDoesNotCompleteWhileSuspended() {
        let c = clock(); let e = c.engine(); e.perform(.startBreak); c.step(e, seconds: 30)
        e.setSuspended(true); c.step(e, seconds: 600, input: false)
        XCTAssertEqual(e.remaining, 90); XCTAssertEqual(e.today.breaks, 0)
        XCTAssertNil(e.consumeBreakCompletion()); XCTAssertFalse(e.consumeNaturalBreak())
    }
}
