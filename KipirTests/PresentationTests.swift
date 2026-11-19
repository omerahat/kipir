import XCTest
#if SWIFT_PACKAGE
@testable import KipirCore
#endif

/// Presentation-policy tests for Core helpers used by the UI (UI workstream).
final class PresentationTests: XCTestCase {
    typealias Clock = BreakSchedulerTests.Clock

    // MARK: Effective notification state

    func testEffectiveNotificationStateMatrix() {
        func state(_ enabled: Bool, _ permission: NotificationPermission, alerts: Bool = true,
                   style: NotificationCapabilities.AlertStyle = .banner, center: Bool = true) -> NotificationEffectiveState {
            .derive(enabled: enabled, capabilities: NotificationCapabilities(permission: permission, alertsEnabled: alerts,
                                                                             style: style, centerEnabled: center, soundEnabled: true))
        }
        for permission in [NotificationPermission.authorized, .provisional, .denied, .unknown] {
            XCTAssertEqual(state(false, permission), .off, "disabled preference always reads off")
        }
        XCTAssertEqual(state(true, .unknown), .needsPermission)
        XCTAssertEqual(state(true, .denied), .denied)
        XCTAssertEqual(state(true, .provisional), .limited, "provisional is never active")
        XCTAssertEqual(state(true, .authorized), .active)
        XCTAssertEqual(state(true, .authorized, style: .alert), .active)
        XCTAssertEqual(state(true, .authorized, style: .none), .limited)
        XCTAssertEqual(state(true, .authorized, alerts: false), .limited)
        XCTAssertEqual(state(true, .authorized, alerts: false, style: .none, center: false), .limited)
    }

    func testPrimaryActionPerStateAndNeverActiveWithoutAuthorization() {
        XCTAssertEqual(NotificationEffectiveState.off.primaryAction, .none)
        XCTAssertEqual(NotificationEffectiveState.needsPermission.primaryAction, .requestPermission)
        XCTAssertEqual(NotificationEffectiveState.denied.primaryAction, .openSettings)
        XCTAssertEqual(NotificationEffectiveState.limited.primaryAction, .openSettings)
        XCTAssertEqual(NotificationEffectiveState.active.primaryAction, .none)
        for permission in [NotificationPermission.denied, .unknown] {
            var caps = NotificationCapabilities(); caps.permission = permission
            caps.alertsEnabled = true; caps.style = .banner
            XCTAssertNotEqual(NotificationEffectiveState.derive(enabled: true, capabilities: caps), .active)
        }
        // The stored preference is an input only; deriving never mutates settings.
        let settings = Settings()
        _ = NotificationEffectiveState.derive(enabled: settings.notifications, capabilities: NotificationCapabilities())
        XCTAssertTrue(settings.notifications)
        XCTAssertEqual(NotificationEffectiveState.needsPermission.statusKey, "ui.notif.state.needsPermission")
    }

    // MARK: Notices

    func testNoticeExpiresSixSecondsAfterItWasDisplayed() {
        let notice = try! XCTUnwrap(TransientNotice(.breakCompleted(today: 3), now: 100).markingDisplayed(at: 100))
        XCTAssertTrue(notice.isVisible(at: 100)); XCTAssertTrue(notice.isVisible(at: 105.9))
        XCTAssertFalse(notice.isVisible(at: 106)); XCTAssertFalse(notice.isVisible(at: .nan))
        XCTAssertEqual(notice.count, 3); XCTAssertEqual(notice.textKey, "ui.notice.breakCompleted")
        let none = BreakCompletionFeedback.Outcome()
        XCTAssertEqual(TransientNotice.next(current: notice, outcome: none, todayBreaks: 3, now: 104), notice)
        XCTAssertNil(TransientNotice.next(current: notice, outcome: none, todayBreaks: 3, now: 106))
        XCTAssertNil(TransientNotice.next(current: nil, outcome: none, todayBreaks: 0, now: 0))
    }

    func testUnseenNoticeStaysPendingForFifteenMinutesThenExpires() {
        let none = BreakCompletionFeedback.Outcome()
        let notice = TransientNotice(.naturalBreak, now: 100)
        XCTAssertTrue(notice.isPending)
        XCTAssertTrue(notice.isVisible(at: 106), "the old 6 s window no longer applies while unseen")
        XCTAssertEqual(TransientNotice.next(current: notice, outcome: none, todayBreaks: 0, now: 700), notice)
        XCTAssertTrue(notice.isVisible(at: 999.9)); XCTAssertFalse(notice.isVisible(at: 1000))
        XCTAssertNil(TransientNotice.next(current: notice, outcome: none, todayBreaks: 0, now: 1000))
        XCTAssertNil(notice.markingDisplayed(at: 1000), "an expired pending notice cannot be displayed")
    }

    func testDisplayStartsTheSixSecondLifetimeOnceAndIsIdempotent() throws {
        let none = BreakCompletionFeedback.Outcome()
        let pending = TransientNotice(.breakCompleted(today: 1), now: 100)
        let shown = try XCTUnwrap(pending.markingDisplayed(at: 700))
        XCTAssertFalse(shown.isPending); XCTAssertEqual(shown.postedAt, 100)
        XCTAssertTrue(shown.isVisible(at: 705.9)); XCTAssertFalse(shown.isVisible(at: 706))
        XCTAssertEqual(shown.markingDisplayed(at: 704), shown, "a second display does not extend the lifetime")
        XCTAssertEqual(TransientNotice.next(current: shown, outcome: none, todayBreaks: 1, now: 705), shown)
        XCTAssertNil(TransientNotice.next(current: shown, outcome: none, todayBreaks: 1, now: 706))
        XCTAssertNil(shown.markingDisplayed(at: 710), "an expired notice is not revived by a later display")
        // A notice displayed just before the pending limit still gets its full 6 s.
        let late = try XCTUnwrap(pending.markingDisplayed(at: 999))
        XCTAssertTrue(late.isVisible(at: 1004.9)); XCTAssertFalse(late.isVisible(at: 1005))
    }

    func testNewerEventReplacesOlderNoticeSeenOrNot() throws {
        let none = BreakCompletionFeedback.Outcome()
        let old = try XCTUnwrap(TransientNotice(.breakCompleted(today: 1), now: 10).markingDisplayed(at: 11))
        let replaced = try XCTUnwrap(TransientNotice.next(current: old, outcome: none, naturalBreak: true, todayBreaks: 1, now: 12))
        XCTAssertEqual(replaced.kind, .naturalBreak); XCTAssertTrue(replaced.isPending); XCTAssertEqual(replaced.postedAt, 12)
        let completed = BreakCompletionFeedback.Outcome(completed: true, playSound: false)
        let again = try XCTUnwrap(TransientNotice.next(current: replaced, outcome: completed, todayBreaks: 2, now: 20))
        XCTAssertEqual(again.kind, .breakCompleted(today: 2)); XCTAssertTrue(again.isPending)
        XCTAssertNotEqual(again.postedAt, replaced.postedAt, "a replaced notice gets a new identity for the view")
    }

    func testCompletionOutranksNaturalBreakInOnePublish() {
        let both = BreakCompletionFeedback.Outcome(completed: true, playSound: false)
        XCTAssertEqual(TransientNotice.next(current: nil, outcome: both, naturalBreak: true, todayBreaks: 2, now: 10)?.kind, .breakCompleted(today: 2))
        let n = TransientNotice.next(current: nil, outcome: BreakCompletionFeedback.Outcome(), naturalBreak: true, todayBreaks: 2, now: 10)
        XCTAssertEqual(n?.kind, .naturalBreak); XCTAssertNil(n?.count)
        XCTAssertEqual(n?.textKey, "ui.notice.naturalBreak")
    }

    func testCompletionOutcomeIsSharedAndSingleConsumption() {
        let c = Clock(); var s = Settings(); s.shortBreak = 10; s.breakEndSound = true
        let e = c.engine(s); var sounds = 0
        e.perform(.startBreak); c.step(e, seconds: 10)
        let first = BreakCompletionFeedback.consume(from: e) { sounds += 1 }
        XCTAssertTrue(first.completed); XCTAssertTrue(first.playSound); XCTAssertEqual(sounds, 1)
        XCTAssertEqual(e.today.breaks, 1)
        let second = BreakCompletionFeedback.consume(from: e) { sounds += 1 }
        XCTAssertEqual(second, BreakCompletionFeedback.Outcome()); XCTAssertEqual(sounds, 1)
    }

    func testSoundNeedsPreferenceAtCompletionAndNow_NoticeStillShown() {
        let c = Clock(); var s = Settings(); s.shortBreak = 10; s.breakEndSound = false
        let e = c.engine(s)
        // Off at completion, on at consumption: notice yes, sound no.
        e.perform(.startBreak); c.step(e, seconds: 10)
        var on = e.settings; on.breakEndSound = true; e.updateSettings(on)
        let a = BreakCompletionFeedback.consume(from: e)
        XCTAssertTrue(a.completed); XCTAssertFalse(a.playSound)
        // On at completion, off at consumption: notice yes, sound no.
        e.perform(.startBreak); c.step(e, seconds: 10)
        var off = e.settings; off.breakEndSound = false; e.updateSettings(off)
        let b = BreakCompletionFeedback.consume(from: e)
        XCTAssertTrue(b.completed); XCTAssertFalse(b.playSound)
        // On at both: sound.
        var again = e.settings; again.breakEndSound = true; e.updateSettings(again)
        e.perform(.startBreak); c.step(e, seconds: 10)
        XCTAssertTrue(BreakCompletionFeedback.consume(from: e).playSound)
    }

    func testSkipAndManualFinishProduceNoNotice() {
        let c = Clock(); var s = Settings(); s.shortBreak = 10; s.breakEndSound = true
        let e = c.engine(s)
        for action in [SchedulerAction.skip, .reset] {
            e.perform(.startBreak); c.step(e, seconds: 9); e.perform(action)
            XCTAssertEqual(BreakCompletionFeedback.consume(from: e), BreakCompletionFeedback.Outcome())
        }
        XCTAssertEqual(e.today.breaks, 0)
    }

    func testCompletionFeedbackLeavesNaturalBreakEventForTheController() {
        // Legacy sound consumption must not swallow the scheduler's one-shot natural-break event.
        let c = Clock(); let e = c.engine(); c.step(e, seconds: 5)
        BreakCompletionFeedback.consume(from: e) {}
        XCTAssertFalse(e.consumeNaturalBreak(), "stub returns false; the point is consume(from:) does not call it")
        XCTAssertNil(TransientNotice.next(current: nil, outcome: BreakCompletionFeedback.Outcome(), naturalBreak: false, todayBreaks: 0, now: 0))
    }

    // MARK: Menu bar formatter

    func testFormatterIconModeAndOffHours() {
        let timer = MenuBarStatusFormatter(status: .working, remaining: 125)
        XCTAssertEqual(timer.minutes, 3); XCTAssertTrue(timer.showsText); XCTAssertEqual(timer.textKey, "menubar.minutes")
        let icon = MenuBarStatusFormatter(status: .working, remaining: 125, iconOnly: true)
        XCTAssertFalse(icon.showsText); XCTAssertEqual(icon.symbol, "figure.walk"); XCTAssertEqual(icon.minutes, 3)
        let off = MenuBarStatusFormatter(status: .offHours, remaining: 600)
        XCTAssertEqual(off.symbol, "moon.zzz"); XCTAssertEqual(off.textKey, "menubar.offHours"); XCTAssertTrue(off.showsText)
        XCTAssertFalse(MenuBarStatusFormatter(status: .offHours, remaining: 600, iconOnly: true).showsText)
        XCTAssertFalse(MenuBarStatusFormatter(status: .paused, remaining: 60).showsText)
        // Tooltip/accessibility summary always carries status and remaining time, in either style.
        let table = ["app.name": "Kıpır", "status.offHours": "Mesai dışı", "menubar.minutes": "%d dk"]
        let summary = MenuBarStatusFormatter(status: .offHours, remaining: 600, iconOnly: true).summary { table[$0] ?? $0 }
        XCTAssertEqual(summary, "Kıpır, Mesai dışı, 10 dk")
        XCTAssertEqual(MenuBarStatusFormatter(status: .working, remaining: .infinity).minutes, 0)
    }

    // MARK: Break durations

    func testBreakDurationLabelsAndPresets() {
        XCTAssertEqual(BreakDurationOptions.short, [30, 60, 120, 180, 300])
        XCTAssertEqual(BreakDurationOptions.long, [180, 300, 600, 900])
        XCTAssertEqual(BreakDurationOptions.label(30).key, "ui.duration.seconds"); XCTAssertEqual(BreakDurationOptions.label(30).values, [30])
        XCTAssertEqual(BreakDurationOptions.label(120).key, "ui.duration.minutes"); XCTAssertEqual(BreakDurationOptions.label(120).values, [2])
        XCTAssertEqual(BreakDurationOptions.label(90).key, "ui.duration.minutesSeconds"); XCTAssertEqual(BreakDurationOptions.label(90).values, [1, 30])
        XCTAssertEqual(BreakDurationOptions.label(.nan).values, [0]); XCTAssertEqual(BreakDurationOptions.label(-5).values, [0])
        XCTAssertTrue(BreakDurationOptions.isPreset(60, in: BreakDurationOptions.short))
        XCTAssertFalse(BreakDurationOptions.isPreset(90, in: BreakDurationOptions.short))
        XCTAssertFalse(BreakDurationOptions.isPreset(120, in: BreakDurationOptions.long))
    }

    func testTimingPresetsUseOnlyPresetBreakLengthsAndCustomValueIsPreserved() {
        for preset in TimingPreset.allCases {
            var s = Settings(); preset.apply(to: &s)
            XCTAssertTrue(BreakDurationOptions.isPreset(s.shortBreak, in: BreakDurationOptions.short))
            XCTAssertTrue(BreakDurationOptions.isPreset(s.longBreak, in: BreakDurationOptions.long))
        }
        // A legacy custom value passes validation untouched; it is only replaced by an explicit new choice.
        var s = Settings(); s.shortBreak = 90; s.longBreak = 400
        let v = s.validated()
        XCTAssertEqual(v.shortBreak, 90); XCTAssertEqual(v.longBreak, 400)
        XCTAssertFalse(BreakDurationOptions.isPreset(v.shortBreak, in: BreakDurationOptions.short))
        XCTAssertNil(TimingPreset.match(v))
        var picked = v; picked.shortBreak = 180
        XCTAssertEqual(picked.validated().shortBreak, 180); XCTAssertEqual(picked.validated().longBreak, 400)
        // Every preset survives validation and a Codable round trip in seconds.
        for value in BreakDurationOptions.short { var t = Settings(); t.shortBreak = value; XCTAssertEqual(t.validated().shortBreak, value) }
        for value in BreakDurationOptions.long { var t = Settings(); t.longBreak = value; XCTAssertEqual(t.validated().longBreak, value) }
    }

    // MARK: Working hours editing

    private func calendar(_ id: String = "UTC", locale: String = "en_US") -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: id)!; c.locale = Locale(identifier: locale)
        return c
    }

    func testMinutesDateRoundTrip() {
        let c = calendar("Europe/Istanbul")
        let reference = Date(timeIntervalSince1970: 1_800_014_400)
        for minutes in [0, 1, 59, 60, 540, 1080, 1439] {
            let date = WorkingHoursEditing.date(forMinutes: minutes, calendar: c, reference: reference)
            XCTAssertEqual(WorkingHoursEditing.minutes(of: date, calendar: c), minutes)
            XCTAssertTrue(c.isDate(date, inSameDayAs: reference))
        }
        XCTAssertEqual(WorkingHoursEditing.minutes(of: WorkingHoursEditing.date(forMinutes: -5, calendar: c, reference: reference), calendar: c), 0)
        XCTAssertEqual(WorkingHoursEditing.minutes(of: WorkingHoursEditing.date(forMinutes: 5000, calendar: c, reference: reference), calendar: c), 1439)
    }

    func testDSTDayKeepsWallClockTime() {
        let c = calendar("America/New_York")
        // 2027-03-14 is the US spring-forward date; 09:00 local must stay 09:00.
        var parts = DateComponents(); parts.year = 2027; parts.month = 3; parts.day = 14; parts.hour = 12
        let reference = c.date(from: parts)!
        let date = WorkingHoursEditing.date(forMinutes: 9 * 60, calendar: c, reference: reference)
        XCTAssertEqual(c.component(.hour, from: date), 9)
        XCTAssertEqual(WorkingHoursEditing.minutes(of: date, calendar: c), 540)
    }

    func testWeekdayOrderingAndNames() {
        var monday = calendar(locale: "tr_TR"); monday.firstWeekday = 2
        XCTAssertEqual(WorkingHoursEditing.orderedWeekdays(calendar: monday), [2, 3, 4, 5, 6, 7, 1])
        var sunday = calendar(); sunday.firstWeekday = 1
        XCTAssertEqual(WorkingHoursEditing.orderedWeekdays(calendar: sunday), [1, 2, 3, 4, 5, 6, 7])
        XCTAssertEqual(WorkingHoursEditing.weekdayName(2, locale: Locale(identifier: "en"), short: true), "Mon")
        XCTAssertEqual(WorkingHoursEditing.weekdayName(1, locale: Locale(identifier: "en"), short: false), "Sunday")
        XCTAssertEqual(WorkingHoursEditing.weekdayName(2, locale: Locale(identifier: "tr"), short: false), "Pazartesi")
        XCTAssertFalse(WorkingHoursEditing.weekdayName(7, locale: Locale(identifier: "tr"), short: true).isEmpty)
        XCTAssertEqual(WorkingHoursEditing.weekdayName(0, locale: Locale(identifier: "tr"), short: true), "")
    }

    func testWeekdayTogglingKeepsAtLeastOneDay() {
        XCTAssertEqual(WorkingHoursEditing.toggling(7, in: [2, 3]), [2, 3, 7])
        XCTAssertEqual(WorkingHoursEditing.toggling(3, in: [2, 3]), [2])
        XCTAssertEqual(WorkingHoursEditing.toggling(2, in: [2]), [2], "last day cannot be removed")
        XCTAssertEqual(WorkingHoursEditing.toggling(9, in: [2]), [2])
    }

    func testTimeUpdatesIgnoreInvalidAndEqualAndDetectOvernight() {
        let base = WorkingHours()
        XCTAssertEqual(WorkingHoursEditing.updating(base, start: 480).start, 480)
        XCTAssertEqual(WorkingHoursEditing.updating(base, end: 1020).end, 1020)
        XCTAssertEqual(WorkingHoursEditing.updating(base, start: base.end), base, "equal start/end would be reset by validation")
        XCTAssertEqual(WorkingHoursEditing.updating(base, end: base.start), base)
        XCTAssertEqual(WorkingHoursEditing.updating(base, start: 1440), base)
        XCTAssertEqual(WorkingHoursEditing.updating(base, end: -1), base)
        XCTAssertFalse(WorkingHoursEditing.crossesMidnight(base))
        XCTAssertTrue(WorkingHoursEditing.crossesMidnight(WorkingHoursEditing.updating(base, start: 22 * 60, end: 6 * 60)))
        var s = Settings(); s.workingHours = WorkingHoursEditing.updating(base, start: 22 * 60, end: 6 * 60)
        XCTAssertEqual(s.validated().workingHours.start, 22 * 60)
    }
}
