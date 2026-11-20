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
        XCTAssertEqual(off.symbol, "moon.zzz"); XCTAssertEqual(off.textKey, "menubar.minutes"); XCTAssertTrue(off.showsText)
        XCTAssertFalse(MenuBarStatusFormatter(status: .offHours, remaining: 600, iconOnly: true).showsText)
        XCTAssertTrue(MenuBarStatusFormatter(status: .paused, remaining: 60).showsText)
        // A Due episode behind meeting/pause/off hours reads "Break", not "0 min"; a running break shows minutes.
        for status in [WorkStatus.meeting, .paused, .offHours] {
            XCTAssertEqual(MenuBarStatusFormatter(status: status, remaining: 0, breakDue: true).textKey, "menubar.due")
        }
        XCTAssertEqual(MenuBarStatusFormatter(status: .meeting, remaining: 0).textKey, "menubar.minutes")
        // Tooltip/accessibility summary always carries status and remaining time, in either style.
        let table = ["app.name": "Kıpır", "status.offHours": "Mesai dışı", "menubar.minutes": "%d dk"]
        let summary = MenuBarStatusFormatter(status: .offHours, remaining: 600, iconOnly: true).summary { table[$0] ?? $0 }
        XCTAssertEqual(summary, "Kıpır, Mesai dışı, 10 dk")
        XCTAssertEqual(MenuBarStatusFormatter(status: .working, remaining: .infinity).minutes, 0)
    }

    // MARK: Countdown ring (pre-release Fix 1)

    func testRemainingFractionStartsFullAndDepletesExactlyToZero() {
        let c = Clock(); var s = Settings(); s.work = 400
        let e = c.engine(s)
        XCTAssertEqual(e.remainingFraction, 1)
        for expected in [0.75, 0.5, 0.25, 0.0] {
            c.step(e, seconds: 100); XCTAssertEqual(e.remainingFraction, expected, accuracy: 1e-9)
        }
        XCTAssertEqual(e.status, .due)
        c.step(e, seconds: 30); XCTAssertEqual(e.remainingFraction, 0, "Due never goes negative or wraps to full")
        XCTAssertEqual(CountdownRingMath.clamped(.nan), 0); XCTAssertEqual(CountdownRingMath.clamped(2), 1)
        XCTAssertEqual(CountdownRingMath.clamped(-1), 0)
    }
    func testRemainingFractionFreezesOnPauseAndSuspensionAndResumesWithoutDrift() {
        // Natural break off: a 900 s sleep would otherwise (correctly) restart the interval.
        let c = Clock(); var s = Settings(); s.work = 400; s.naturalBreak = 0
        let e = c.engine(s); c.step(e, seconds: 100)
        e.perform(.togglePause); c.step(e, seconds: 250)
        XCTAssertEqual(e.remainingFraction, 0.75, accuracy: 1e-9)
        e.perform(.togglePause); c.step(e, seconds: 100)
        XCTAssertEqual(e.remainingFraction, 0.5, accuracy: 1e-9)
        e.setSuspended(true); c.time += 900; c.date += 900; e.setSuspended(false)
        XCTAssertEqual(e.remainingFraction, 0.5, accuracy: 1e-9, "sleep is never credited")
        let restored = c.engine(s, checkpoint: e.checkpoint)
        XCTAssertEqual(restored.remainingFraction, 0.5, accuracy: 1e-9, "restart restores the same position")
    }
    func testRemainingFractionForSnoozeBreakSettingsChangeAndMeeting() {
        let c = Clock(); var s = Settings(); s.work = 60; s.snooze = 60
        let e = c.engine(s); c.step(e, seconds: 60)
        XCTAssertEqual(e.remainingFraction, 0)
        e.perform(.snooze); XCTAssertEqual(e.remainingFraction, 1, "a snooze refills the ring")
        c.step(e, seconds: 30); XCTAssertEqual(e.remainingFraction, 0.5, accuracy: 1e-9)
        c.step(e, seconds: 30); e.perform(.startBreak)
        XCTAssertEqual(e.remainingFraction, 1)
        c.step(e, seconds: 60, input: false); XCTAssertEqual(e.remainingFraction, 0.5, accuracy: 1e-9)
        c.step(e, seconds: 60, input: false)
        XCTAssertEqual(e.checkpoint.phase, .working); XCTAssertEqual(e.remainingFraction, 1)
        s.work = 400; e.updateSettings(s); c.step(e, seconds: 100)
        XCTAssertEqual(e.remainingFraction, 0.75, accuracy: 1e-9)
        s.work = 200; e.updateSettings(s); XCTAssertEqual(e.remainingFraction, 0.5, accuracy: 1e-9)
        e.setMeeting(true); c.step(e, seconds: 50)
        XCTAssertEqual(e.remainingFraction, 0.25, accuracy: 1e-9, "meeting mode keeps the ring moving")
    }

    // MARK: Menu bar geometry (pre-release Fix 2)

    private func strings(_ language: String) -> [String: String] {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent("Kipir/Resources/\(language).lproj/Localizable.strings")
        return (NSDictionary(contentsOf: url) as? [String: String]) ?? [:]
    }
    func testMenuBarTextSlotFitsEveryStateCountdownAndLanguage() {
        let tables = [strings("tr"), strings("en")]
        XCTAssertFalse(tables[0].isEmpty); XCTAssertFalse(tables[1].isEmpty)
        let candidates = MenuBarLabelLayout.candidates(tables: tables)
        for expected in ["888 dk", "888 min", "Mola", "Break"] { XCTAssertTrue(candidates.contains(expected), expected) }
        // Proportional stand-in for the font: wider strings measure wider.
        let measure: (String) -> Double = { Double($0.count) * 7.3 }
        let slot = MenuBarLabelLayout.textSlotWidth(candidates: candidates, measure: measure)
        let statuses: [WorkStatus] = [.working, .idle, .paused, .meeting, .due, .onBreak, .suspended, .offHours]
        for table in tables {
            for status in statuses {
                for remaining in [14401.0, 3600, 3599, 600, 599, 61, 60, 59, 1, 0] {
                    let text = MenuBarStatusFormatter(status: status, remaining: remaining).text { table[$0] ?? $0 }
                    XCTAssertLessThanOrEqual(measure(text), slot, "\(status) \(remaining) \(text)")
                }
            }
        }
        // The label's total width depends only on the style, never on state, countdown or language.
        XCTAssertEqual(MenuBarLabelLayout.totalWidth(textSlot: slot, iconOnly: false),
                       MenuBarLabelLayout.iconSlot + MenuBarLabelLayout.gap + slot)
        XCTAssertEqual(MenuBarLabelLayout.totalWidth(textSlot: slot, iconOnly: true), MenuBarLabelLayout.iconSlot)
        XCTAssertEqual(MenuBarLabelLayout.textSlotWidth(candidates: ["a"], measure: { _ in .nan }), 1)
        XCTAssertEqual(MenuBarLabelLayout.textSlotWidth(candidates: ["ab"], measure: { _ in 10.2 }), 12)
    }

    // MARK: Language and appearance preferences (pre-release Feature 6, Fix 4)

    func testLanguageResolutionHonorsExplicitChoiceSystemOrderAndFallback() {
        XCTAssertEqual(AppLanguage.resolve(preference: nil, preferredLanguages: ["tr-TR"]), "tr")
        XCTAssertEqual(AppLanguage.resolve(preference: nil, preferredLanguages: ["en-GB", "tr-TR"]), "en")
        XCTAssertEqual(AppLanguage.resolve(preference: "system", preferredLanguages: ["de-DE", "tr_TR"]), "tr")
        XCTAssertEqual(AppLanguage.resolve(preference: nil, preferredLanguages: ["de-DE", "fr-FR"]), "en")
        XCTAssertEqual(AppLanguage.resolve(preference: nil, preferredLanguages: []), "en")
        XCTAssertEqual(AppLanguage.resolve(preference: "tr", preferredLanguages: ["en-US"]), "tr")
        XCTAssertEqual(AppLanguage.resolve(preference: "en", preferredLanguages: ["tr-TR"]), "en")
        XCTAssertEqual(AppLanguage.resolve(preference: "xx", preferredLanguages: ["TR"]), "tr")
        XCTAssertEqual(AppLanguage.normalizedPreference(nil), "system")
        XCTAssertEqual(AppLanguage.normalizedPreference("bogus"), "system")
        XCTAssertEqual(AppLanguage.normalizedPreference("en"), "en")
    }
    func testAppearancePreferencePersistsAndInvalidValuesRecover() {
        let suite = "KipirAppearance.\(UUID().uuidString)"; let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = LocalStore(defaults: defaults)
        for value in ["light", "dark", "system"] {
            var s = Settings(); s.appearance = value; store.save(s)
            XCTAssertEqual(store.loadSettings().appearance, value)
        }
        var s = Settings(); s.appearance = "purple"; store.save(s)
        XCTAssertEqual(store.loadSettings().appearance, "system")
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

#if !SWIFT_PACKAGE
import AppKit
import SwiftUI
import UserNotifications

/// Native checks that need the app sources compiled into the Xcode test target.
final class PreReleaseNativeTests: XCTestCase {
    /// Renders the real ring and samples its pixels: the arc is anchored at 12 o'clock and the missing part is
    /// always just counterclockwise of 12, so depletion runs counterclockwise.
    @MainActor func testCountdownRingDrawsRemainingArcClockwiseFromTwelve() throws {
        func alphaSamples(_ fraction: Double) throws -> [String: Double] {
            let renderer = ImageRenderer(content: CountdownRing(fraction: fraction, lineWidth: 8)
                .frame(width: 100, height: 100).padding(4).environment(\.colorScheme, .light))
            renderer.scale = 1
            let image = try XCTUnwrap(renderer.cgImage)
            let width = image.width, height = image.height
            var pixels = [UInt8](repeating: 0, count: width * height * 4)
            let context = try XCTUnwrap(CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            // Clock positions measured clockwise from 12; rows run top to bottom in `pixels`.
            var result: [String: Double] = [:]
            for (name, degrees) in [("1:30", 45.0), ("4:30", 135.0), ("7:30", 225.0), ("10:30", 315.0)] {
                let radians = degrees * .pi / 180, radius = 50.0
                let x = Int((54 + radius * sin(radians)).rounded()), y = Int((54 - radius * cos(radians)).rounded())
                result[name] = Double(pixels[(y * width + x) * 4 + 3]) / 255
            }
            return result
        }
        let full = try alphaSamples(1), threeQuarters = try alphaSamples(0.75)
        let quarter = try alphaSamples(0.25), empty = try alphaSamples(0)
        for position in ["1:30", "4:30", "7:30", "10:30"] { XCTAssertGreaterThan(full[position]!, 0.8, position) }
        // 75 % left: the quarter just counterclockwise of 12 (the 9-12 quadrant) has gone.
        XCTAssertLessThan(threeQuarters["10:30"]!, 0.5)
        for position in ["1:30", "4:30", "7:30"] { XCTAssertGreaterThan(threeQuarters[position]!, 0.8, position) }
        // 25 % left: only the 12-3 quadrant remains.
        XCTAssertGreaterThan(quarter["1:30"]!, 0.8)
        for position in ["4:30", "7:30", "10:30"] { XCTAssertLessThan(quarter[position]!, 0.5, position) }
        // Empty: only the faint track remains.
        for position in ["1:30", "4:30", "7:30", "10:30"] {
            XCTAssertLessThan(empty[position]!, 0.5, position); XCTAssertGreaterThan(empty[position]!, 0, "track stays visible")
        }
    }

    /// The 2x bitmap must be drawn at 2x: content reaches the right and top halves, and size never varies.
    @MainActor func testStatusLabelImageIsConstantSizeAndDrawnAtFullScale() throws {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        let slot = CGFloat(MenuBarLabelLayout.textSlotWidth(candidates: ["888 min"]) {
            Double(($0 as NSString).size(withAttributes: [.font: font]).width)
        })
        var sizes = Set<String>()
        for (symbol, text) in [("figure.walk", "45 min"), ("pause.fill", "888 min"), ("person.2", "Mola"), ("moon", "1 dk")] {
            let image = StatusLabelImage.make(symbol: symbol, text: text, textSlot: slot, font: font, scale: 2)
            sizes.insert("\(image.size.width)x\(image.size.height)")
            XCTAssertTrue(image.isTemplate)
            let rep = try XCTUnwrap(image.representations.first as? NSBitmapImageRep)
            XCTAssertEqual(rep.pixelsWide, Int(ceil(image.size.width * 2)))
            var maxX = 0, minY = Int.max
            for y in 0..<rep.pixelsHigh { for x in 0..<rep.pixelsWide where (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.5 {
                maxX = max(maxX, x); minY = min(minY, y)
            } }
            if text == "888 min" { XCTAssertGreaterThan(maxX, rep.pixelsWide * 3 / 4, "text fills the slot at 2x") }
            XCTAssertLessThan(minY, rep.pixelsHigh / 2, "\(symbol): content reaches the top half (rows run top-down)")
        }
        XCTAssertEqual(sizes.count, 1, "label size must not depend on state or text")
        let iconOnly = StatusLabelImage.make(symbol: "figure.walk", text: nil, textSlot: slot, font: font, scale: 2)
        XCTAssertEqual(iconOnly.size.width, CGFloat(MenuBarLabelLayout.iconSlot))
    }

    func testNotificationClickRoutesToPanelAndActionsToSchedulerOnly() {
        let id = UUID()
        XCTAssertEqual(NotificationManager.route(actionIdentifier: UNNotificationDefaultActionIdentifier,
                                                 requestIdentifier: id.uuidString), .openPanel)
        XCTAssertEqual(NotificationManager.route(actionIdentifier: UNNotificationDefaultActionIdentifier,
                                                 requestIdentifier: "kipir.test.\(UUID().uuidString)"), .openPanel,
                       "the user-initiated test notification opens the same panel")
        XCTAssertEqual(NotificationManager.route(actionIdentifier: "start", requestIdentifier: id.uuidString),
                       .perform(id, .startBreak))
        XCTAssertEqual(NotificationManager.route(actionIdentifier: "snooze", requestIdentifier: id.uuidString),
                       .perform(id, .snooze))
        XCTAssertEqual(NotificationManager.route(actionIdentifier: "start", requestIdentifier: "kipir.test.x"), .ignore)
        XCTAssertEqual(NotificationManager.route(actionIdentifier: UNNotificationDismissActionIdentifier,
                                                 requestIdentifier: id.uuidString), .ignore)
        XCTAssertEqual(NotificationManager.route(actionIdentifier: "other", requestIdentifier: id.uuidString), .ignore)
    }

    func testLanguagePreferencePersistsAndSystemDefaultFollowsPreferredLanguages() {
        let suite = "KipirLanguage.\(UUID().uuidString)"; let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let system = AppLanguage.resolve(preference: nil, preferredLanguages: Locale.preferredLanguages)
        XCTAssertEqual(currentLanguage(defaults: defaults), system)
        defaults.set("en", forKey: "language"); XCTAssertEqual(currentLanguage(defaults: defaults), "en")
        defaults.set("tr", forKey: "language"); XCTAssertEqual(currentLanguage(defaults: defaults), "tr")
        defaults.removeObject(forKey: "language"); XCTAssertEqual(currentLanguage(defaults: defaults), system)
    }
}
#endif
