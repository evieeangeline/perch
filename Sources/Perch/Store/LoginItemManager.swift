import Foundation
import ServiceManagement

final class LoginItemManager {
    static let shared = LoginItemManager()
    private init() {}

    func sync(enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("Perch: failed to update login item registration: \(error.localizedDescription)")
        }
    }
}
