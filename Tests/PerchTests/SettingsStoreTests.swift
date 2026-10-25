import Foundation
import Testing
@testable import Perch

/// Each test gets its own `UserDefaults` suite and a recorder in place of
/// the real login item, so your actual settings are never touched.
@Suite final class SettingsStoreTests {
    let suiteName = "PerchTests-\(UUID().uuidString)"
    let defaults: UserDefaults
    var loginItemCalls: [Bool] = []

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func makeStore() -> SettingsStore {
        SettingsStore(defaults: defaults, syncLoginItem: { [unowned self] in loginItemCalls.append($0) })
    }

    @Test func freshInstallDefaults() {
        let settings = makeStore()
        #expect(!settings.launchAtLogin)
        #expect(!settings.startExpanded)
        #expect(settings.glanceTranslucent)
        #expect(settings.glanceOpacity == 0.55)
        #expect(settings.perchieStyle == .hanging)
        #expect(settings.perchieHangPosition == 0.22)
        #expect(settings.recentCompletedCount == 5)
    }

    @Test func changesPersistAcrossLaunches() {
        let settings = makeStore()
        settings.startExpanded = true
        settings.glanceTranslucent = false
        settings.glanceOpacity = 0.8
        settings.perchieStyle = .top
        settings.perchieHangPosition = -0.1
        settings.recentCompletedCount = 12

        let reloaded = makeStore()
        #expect(reloaded.startExpanded)
        #expect(!reloaded.glanceTranslucent)
        #expect(reloaded.glanceOpacity == 0.8)
        #expect(reloaded.perchieStyle == .top)
        #expect(reloaded.perchieHangPosition == -0.1)
        #expect(reloaded.recentCompletedCount == 12)
    }

    @Test func launchAtLoginPersistsAndSyncsLoginItem() {
        let settings = makeStore()
        settings.launchAtLogin = true
        settings.launchAtLogin = false
        #expect(loginItemCalls == [true, false])
        #expect(!makeStore().launchAtLogin)
    }

    @Test func settingLaunchAtLoginToSameValueDoesNotResync() {
        let settings = makeStore()
        settings.launchAtLogin = false
        #expect(loginItemCalls.isEmpty)
    }

    @Test func loadingDoesNotTouchLoginItem() {
        defaults.set(true, forKey: "launchAtLogin")
        #expect(makeStore().launchAtLogin)
        #expect(loginItemCalls.isEmpty)
    }

    @Test func unknownPerchieStyleFallsBackToHanging() {
        defaults.set("upside-down", forKey: "perchieStyle")
        #expect(makeStore().perchieStyle == .hanging)
    }

    @Test(arguments: PerchieStyle.allCases)
    func perchieStyleHasALabel(style: PerchieStyle) {
        #expect(!style.label.isEmpty)
        #expect(style.id == style.rawValue)
    }
}
