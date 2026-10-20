import Foundation
import Testing
@testable import Can_I_Wear

@MainActor
struct ItemSelectionStoreTests {
    @Test func freshSetupIsEmptyAndCannotCompleteWithoutAnItem() throws {
        try withDefaults { defaults in
            AppConfiguration.registerDefaults(in: defaults)
            let store = ItemSelectionStore(defaults: defaults)
            #expect(store.selectedItems.isEmpty)
            #expect(!store.isCompleted)
            #expect(!store.save([]))
            #expect(!defaults.bool(forKey: AppConfiguration.itemSelectionCompletedKey))
        }
    }

    @Test func savesCanonicalSelectionAcrossRelaunchAndRejectsEmptyEdits() throws {
        try withDefaults { defaults in
            let store = ItemSelectionStore(defaults: defaults)
            #expect(store.save([.sunglasses, .leatherJacket]))
            #expect(store.selectedItems == [.leatherJacket, .sunglasses])
            #expect(!store.save([]))
            let relaunched = ItemSelectionStore(defaults: defaults)
            #expect(relaunched.isCompleted)
            #expect(relaunched.selectedItems == [.leatherJacket, .sunglasses])
            #expect(relaunched.save([.gloves]))
            #expect(ItemSelectionStore(defaults: defaults).selectedItems == [.gloves])
        }
    }

    @Test func replayClearsSelectionAndSetupButNotGuidanceOrCachedData() throws {
        try withDefaults { defaults in
            defaults.set(false, forKey: AppConfiguration.guidedHomeEnabledKey)
            defaults.set(false, forKey: AppConfiguration.showHomeIntroductionKey)
            defaults.set(Data([1, 2, 3]), forKey: WeatherCache.storageKey)
            let store = ItemSelectionStore(defaults: defaults)
            store.save([.sweater])
            store.replaySetup()
            #expect(store.selectedItems.isEmpty)
            #expect(!store.isCompleted)
            #expect(defaults.object(forKey: AppConfiguration.selectedItemIDsKey) == nil)
            let relaunched = ItemSelectionStore(defaults: defaults)
            #expect(!relaunched.isCompleted)
            #expect(relaunched.selectedItems.isEmpty)
            #expect(!relaunched.save([]))
            #expect(!defaults.bool(forKey: AppConfiguration.guidedHomeEnabledKey))
            #expect(!defaults.bool(forKey: AppConfiguration.showHomeIntroductionKey))
            #expect(defaults.data(forKey: WeatherCache.storageKey) == Data([1, 2, 3]))
        }
    }

    @Test func invalidOrUnknownSavedItemsCannotBypassSetup() throws {
        try withDefaults { defaults in
            defaults.set(true, forKey: AppConfiguration.itemSelectionCompletedKey)
            defaults.set(["unknown"], forKey: AppConfiguration.selectedItemIDsKey)
            #expect(!ItemSelectionStore(defaults: defaults).isCompleted)
            defaults.set(["gloves", "unknown", "gloves"], forKey: AppConfiguration.selectedItemIDsKey)
            #expect(ItemSelectionStore(defaults: defaults).selectedItems == [.gloves])
            defaults.set("not-an-array", forKey: AppConfiguration.selectedItemIDsKey)
            #expect(ItemSelectionStore(defaults: defaults).selectedItems.isEmpty)
        }
    }

    @Test func settingsResetIsOffByDefaultAndDoesNotReplayConfirmedSetup() throws {
        try withDefaults { defaults in
            AppConfiguration.registerDefaults(in: defaults)
            #expect(!defaults.bool(forKey: AppConfiguration.resetItemSetupKey))
            let store = ItemSelectionStore(defaults: defaults)
            store.save([.gloves])
            store.refreshFromSettings()
            #expect(store.isCompleted)
            #expect(ItemSelectionStore(defaults: defaults).isCompleted)
        }
    }

    @Test func settingsResetOnLaunchPreservesAllUnrelatedStoredValues() throws {
        try withDefaults { defaults in
            AppConfiguration.registerDefaults(in: defaults)
            let store = ItemSelectionStore(defaults: defaults)
            store.save([.sunglasses, .leatherJacket])
            defaults.set(false, forKey: AppConfiguration.guidedHomeEnabledKey)
            defaults.set(false, forKey: AppConfiguration.showHomeIntroductionKey)
            defaults.set(Data([1, 2, 3]), forKey: WeatherCache.storageKey)
            defaults.set("location sentinel", forKey: "latestAcceptedLocation")
            defaults.set(true, forKey: AppConfiguration.resetItemSetupKey)
            var before = defaults.dictionaryRepresentation()

            let relaunched = ItemSelectionStore(defaults: defaults)
            #expect(!relaunched.isCompleted)
            #expect(relaunched.selectedItems.isEmpty)
            #expect(defaults.object(forKey: AppConfiguration.selectedItemIDsKey) == nil)
            #expect(!defaults.bool(forKey: AppConfiguration.itemSelectionCompletedKey))
            #expect(!defaults.bool(forKey: AppConfiguration.resetItemSetupKey))
            var after = defaults.dictionaryRepresentation()
            for key in [AppConfiguration.selectedItemIDsKey, AppConfiguration.itemSelectionCompletedKey, AppConfiguration.resetItemSetupKey] {
                before.removeValue(forKey: key)
                after.removeValue(forKey: key)
            }
            #expect((before as NSDictionary).isEqual(to: after))
        }
    }

    @Test func foregroundSettingsResetIsConsumedOnceAndCanBeRequestedAgain() throws {
        try withDefaults { defaults in
            let store = ItemSelectionStore(defaults: defaults)
            store.save([.sweater])
            for _ in 0..<2 {
                defaults.set(true, forKey: AppConfiguration.resetItemSetupKey)
                store.refreshFromSettings()
                #expect(!store.isCompleted)
                #expect(!defaults.bool(forKey: AppConfiguration.itemSelectionCompletedKey))
                #expect(!defaults.bool(forKey: AppConfiguration.resetItemSetupKey))
                #expect(store.selectedItems.isEmpty)
                #expect(defaults.object(forKey: AppConfiguration.selectedItemIDsKey) == nil)
                #expect(!store.save([]))
                #expect(store.save([.sweater]))
                store.refreshFromSettings()
                #expect(store.isCompleted)
                #expect(ItemSelectionStore(defaults: defaults).isCompleted)
            }
        }
    }

    @Test func packagedSettingsExposeOneShotResetWithExplicitBooleanValues() throws {
        let url = try #require(Bundle.main.url(forResource: "Root", withExtension: "plist", subdirectory: "Settings.bundle"))
        let plist = try #require(PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any])
        let specifiers = try #require(plist["PreferenceSpecifiers"] as? [[String: Any]])
        let reset = try #require(specifiers.first { $0["Key"] as? String == AppConfiguration.resetItemSetupKey })
        #expect(reset["Type"] as? String == "PSToggleSwitchSpecifier")
        #expect(reset["Title"] as? String == "Reset Item Setup")
        #expect(reset["DefaultValue"] as? Bool == false)
        #expect(reset["TrueValue"] as? Bool == true)
        #expect(reset["FalseValue"] as? Bool == false)
    }

    private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let suite = "ItemSelectionStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults)
    }
}
