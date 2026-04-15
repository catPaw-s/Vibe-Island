import Foundation

struct HookInstaller {
    static func installIfNeeded() {
        EditorIntegrationRegistry.installAllHooks()
    }

    static func isInstalled() -> Bool {
        EditorIntegrationRegistry.areAllHooksInstalled()
    }

    static func uninstall() {
        EditorIntegrationRegistry.uninstallAllHooks()
    }
}
