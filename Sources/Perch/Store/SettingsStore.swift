import Foundation
import Combine

/// Where Perchie, the bird from the app icon, appears on the panel.
enum PerchieStyle: String, CaseIterable, Identifiable {
    /// `hanging`: below the shape's bottom edge. `top`: from the top edge of
    /// the screen, in the notch band just right of the camera.
    case none, hanging, top
    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "None"
        case .hanging: return "Hanging"
        case .top: return "Top of screen"
        }
    }
}

final class SettingsStore: ObservableObject {
    @Published var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue else { return }
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            syncLoginItem(launchAtLogin)
        }
    }

    @Published var startExpanded: Bool {
        didSet { defaults.set(startExpanded, forKey: Keys.startExpanded) }
    }

    /// Whether the resting (not hovered) list lets the screen show through.
    @Published var glanceTranslucent: Bool {
        didSet { defaults.set(glanceTranslucent, forKey: Keys.glanceTranslucent) }
    }

    /// How opaque the resting list's background is when translucent.
    @Published var glanceOpacity: Double {
        didSet { defaults.set(glanceOpacity, forKey: Keys.glanceOpacity) }
    }

    @Published var perchieStyle: PerchieStyle {
        didSet { defaults.set(perchieStyle.rawValue, forKey: Keys.perchieStyle) }
    }

    /// Where Perchie hangs along the bottom edge, as a fraction of the
    /// shape's width from its centre (draggable while expanded).
    @Published var perchieHangPosition: Double {
        didSet { defaults.set(perchieHangPosition, forKey: Keys.perchieHangPosition) }
    }

    @Published var recentCompletedCount: Int {
        didSet { defaults.set(recentCompletedCount, forKey: Keys.recentCompletedCount) }
    }

    private enum Keys {
        static let launchAtLogin = "launchAtLogin"
        static let startExpanded = "startExpanded"
        static let recentCompletedCount = "recentCompletedCount"
        static let glanceTranslucent = "glanceTranslucent"
        static let glanceOpacity = "glanceOpacity"
        static let perchieStyle = "perchieStyle"
        static let perchieHangPosition = "perchieHangPosition"
    }

    private let defaults: UserDefaults
    private let syncLoginItem: (Bool) -> Void

    init(
        defaults: UserDefaults = .standard,
        syncLoginItem: @escaping (Bool) -> Void = { LoginItemManager.shared.sync(enabled: $0) }
    ) {
        self.defaults = defaults
        self.syncLoginItem = syncLoginItem
        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        startExpanded = defaults.bool(forKey: Keys.startExpanded)
        glanceTranslucent = defaults.object(forKey: Keys.glanceTranslucent) as? Bool ?? true
        glanceOpacity = defaults.object(forKey: Keys.glanceOpacity) as? Double ?? 0.55
        perchieStyle = defaults.string(forKey: Keys.perchieStyle).flatMap(PerchieStyle.init(rawValue:)) ?? .hanging
        perchieHangPosition = defaults.object(forKey: Keys.perchieHangPosition) as? Double ?? 0.22
        recentCompletedCount = defaults.object(forKey: Keys.recentCompletedCount) as? Int ?? 5
    }
}
