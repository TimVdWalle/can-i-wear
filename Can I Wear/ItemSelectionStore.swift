import Foundation
import Observation

@MainActor
@Observable
final class ItemSelectionStore {
    private(set) var selectedItems: [PredefinedItem]
    private(set) var isCompleted: Bool
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = Set(defaults.stringArray(forKey: AppConfiguration.selectedItemIDsKey) ?? [])
        let items = PredefinedItem.allCases.filter { saved.contains($0.rawValue) }
        selectedItems = items
        isCompleted = defaults.bool(forKey: AppConfiguration.itemSelectionCompletedKey) && !items.isEmpty
        refreshFromSettings()
    }

    /// Settings may have changed while the app was suspended or terminated.
    func refreshFromSettings() {
        defaults.synchronize()
        guard defaults.bool(forKey: AppConfiguration.resetItemSetupKey) else { return }
        replaySetup()
        defaults.set(false, forKey: AppConfiguration.resetItemSetupKey)
        defaults.synchronize()
    }

    @discardableResult
    func save(_ items: Set<PredefinedItem>) -> Bool {
        guard !items.isEmpty else { return false }
        selectedItems = PredefinedItem.allCases.filter { items.contains($0) }
        defaults.set(selectedItems.map(\.rawValue), forKey: AppConfiguration.selectedItemIDsKey)
        defaults.set(true, forKey: AppConfiguration.itemSelectionCompletedKey)
        isCompleted = true
        return true
    }

    /// Restore empty first-use selection without touching Home preferences or cached data.
    func replaySetup() {
        selectedItems = []
        defaults.removeObject(forKey: AppConfiguration.selectedItemIDsKey)
        defaults.set(false, forKey: AppConfiguration.itemSelectionCompletedKey)
        isCompleted = false
    }
}
