import Foundation

nonisolated struct LocationAcquisitionConfig: Equatable, Sendable {
    let requestedAccuracyMeters: Double
    let maximumAcceptedAccuracyMeters: Double
    let timeout: Duration
}

nonisolated struct JacketRulesConfig: Equatable, Sendable {
    let maximumDryPrecipitationAmountMillimeters: Double
    let cautionPrecipitationChanceFraction: Double
    let avoidPrecipitationChanceFraction: Double
    let maximumOkayTemperatureCelsius: Double
    let maximumCautionTemperatureCelsius: Double
}

nonisolated struct DayPeriodConfig: Equatable, Sendable {
    let minimumMeaningfulChangeHours: Int
    let isolatedAvoidSafetyHours: Int
    let minimumNoisyAlternationHours: Int
}

nonisolated struct ColdWeatherItemRules: Equatable, Sendable {
    let maximumUsefulCelsius: Double
    let maximumMaybeCelsius: Double
}

nonisolated struct ItemRulesConfig: Equatable, Sendable {
    let minimumUsefulHours: Int
    let warmCoat: ColdWeatherItemRules
    let sweater: ColdWeatherItemRules
    let gloves: ColdWeatherItemRules
    let shortsMinimumUsefulCelsius: Double
    let shortsMinimumMaybeCelsius: Double
    let raincoatUsefulAmountMillimeters: Double
    let raincoatMaybeChanceFraction: Double
    let raincoatWindUpgradeKilometersPerHour: Double
    let sunglassesUsefulUVIndex: Double
}

nonisolated struct ReusePolicyConfig: Equatable, Sendable {
    let locationFreshness: TimeInterval
    let weatherRefreshInterval: TimeInterval
    let weatherFreshness: TimeInterval
    let maximumForecastDistanceMeters: Double
    let weatherRequestTimeout: Duration
    let failedRequestCooldown: TimeInterval
}

nonisolated enum HomePresentationMode: Equatable, Sendable {
    case guided
    case compact
}

nonisolated struct HomePresentationPreferences: Equatable, Sendable {
    let guidedHomeEnabled: Bool
    let showHomeIntroduction: Bool
}

nonisolated enum AppConfiguration {
    static let maximumDiagnosticEvents = 20
    // Open-Meteo's upstream cloud categories; adapter mapping, not item-specific thresholds.
    static let openMeteoClearSkyUpperCloudCoverPercent = 20.0
    static let openMeteoMainlyClearUpperCloudCoverPercent = 50.0
    static let openMeteoPartlyCloudyUpperCloudCoverPercent = 80.0
    static let homePresentationMode: HomePresentationMode = .guided
    static let guidedHomeEnabledKey = "home_presentation_guided"
    static let showHomeIntroductionKey = "home_introduction_visible"
    static let homeIntroductionAcknowledgedKey = "homeIntroductionAcknowledged"
    static let selectedItemIDsKey = "selected_item_ids"
    static let itemSelectionCompletedKey = "item_selection_completed"
    static let resetItemSetupKey = "reset_item_setup"
    private static let legacyGuidedHomeEnabledKey = "guided_home_enabled"
    private static let legacyShowHomeIntroductionKey = "show_home_introduction"
    private static let homePreferenceKeysMigratedKey = "homePreferenceKeysMigratedV2"
    private static let homeIntroductionSettingMigratedKey = "homeIntroductionSettingMigrated"
    private static let lastAppliedGuidedHomeKey = "lastAppliedGuidedHomeEnabled"
    private static let lastAppliedShowIntroductionKey = "lastAppliedShowHomeIntroduction"

    static func registerDefaults(in defaults: UserDefaults = .standard) {
        if !defaults.bool(forKey: homePreferenceKeysMigratedKey) {
            if defaults.object(forKey: legacyGuidedHomeEnabledKey) != nil {
                defaults.set(
                    defaults.bool(forKey: legacyGuidedHomeEnabledKey),
                    forKey: guidedHomeEnabledKey
                )
            }
            if defaults.object(forKey: legacyShowHomeIntroductionKey) != nil {
                defaults.set(
                    defaults.bool(forKey: legacyShowHomeIntroductionKey),
                    forKey: showHomeIntroductionKey
                )
            }
            defaults.set(true, forKey: homePreferenceKeysMigratedKey)
        }
        if !defaults.bool(forKey: homeIntroductionSettingMigratedKey) {
            if defaults.object(forKey: legacyShowHomeIntroductionKey) == nil,
               defaults.bool(forKey: homeIntroductionAcknowledgedKey) {
                defaults.set(false, forKey: showHomeIntroductionKey)
            }
            defaults.set(true, forKey: homeIntroductionSettingMigratedKey)
        }
        defaults.register(defaults: [
            itemSelectionCompletedKey: false,
            resetItemSetupKey: false,
            guidedHomeEnabledKey: homePresentationMode == .guided,
            showHomeIntroductionKey: true
        ])
    }

    static func resolveHomePresentationPreferences(
        in defaults: UserDefaults = .standard
    ) -> HomePresentationPreferences {
        var guidedHomeEnabled = defaults.bool(forKey: guidedHomeEnabledKey)
        var showHomeIntroduction = defaults.bool(forKey: showHomeIntroductionKey)

        guard
            defaults.object(forKey: lastAppliedGuidedHomeKey) != nil,
            defaults.object(forKey: lastAppliedShowIntroductionKey) != nil
        else {
            // On upgrade, the persistent mode is authoritative. A Compact user
            // should not remain in Guided presentation because of the new switch.
            if !guidedHomeEnabled && showHomeIntroduction {
                showHomeIntroduction = false
                defaults.set(false, forKey: showHomeIntroductionKey)
            }
            recordAppliedHomePreferences(
                guidedHomeEnabled: guidedHomeEnabled,
                showHomeIntroduction: showHomeIntroduction,
                in: defaults
            )
            return HomePresentationPreferences(
                guidedHomeEnabled: guidedHomeEnabled,
                showHomeIntroduction: showHomeIntroduction
            )
        }

        let previousGuidedHomeEnabled = defaults.bool(forKey: lastAppliedGuidedHomeKey)
        let previousShowHomeIntroduction = defaults.bool(forKey: lastAppliedShowIntroductionKey)
        let guidedHomeChanged = guidedHomeEnabled != previousGuidedHomeEnabled
        let showIntroductionChanged = showHomeIntroduction != previousShowHomeIntroduction

        if guidedHomeChanged && !guidedHomeEnabled {
            showHomeIntroduction = false
            defaults.set(false, forKey: showHomeIntroductionKey)
        } else if showIntroductionChanged && showHomeIntroduction && !guidedHomeEnabled {
            guidedHomeEnabled = true
            defaults.set(true, forKey: guidedHomeEnabledKey)
        }

        recordAppliedHomePreferences(
            guidedHomeEnabled: guidedHomeEnabled,
            showHomeIntroduction: showHomeIntroduction,
            in: defaults
        )
        return HomePresentationPreferences(
            guidedHomeEnabled: guidedHomeEnabled,
            showHomeIntroduction: showHomeIntroduction
        )
    }

    static func currentHomePresentationPreferences() -> HomePresentationPreferences {
        let defaults = synchronizedApplicationDefaults()
        return resolveHomePresentationPreferences(in: defaults)
    }

    static func setShowHomeIntroduction(_ enabled: Bool) -> HomePresentationPreferences {
        let defaults = synchronizedApplicationDefaults()
        defaults.set(enabled, forKey: showHomeIntroductionKey)
        defaults.synchronize()
        return resolveHomePresentationPreferences(in: defaults)
    }

    private static func synchronizedApplicationDefaults() -> UserDefaults {
        UserDefaults.standard.synchronize()
        registerDefaults()
        return .standard
    }

    private static func recordAppliedHomePreferences(
        guidedHomeEnabled: Bool,
        showHomeIntroduction: Bool,
        in defaults: UserDefaults
    ) {
        defaults.set(guidedHomeEnabled, forKey: lastAppliedGuidedHomeKey)
        defaults.set(showHomeIntroduction, forKey: lastAppliedShowIntroductionKey)
        defaults.synchronize()
    }

    static let locationAcquisition = LocationAcquisitionConfig(
        requestedAccuracyMeters: 1_000,
        maximumAcceptedAccuracyMeters: 5_000,
        timeout: .seconds(15)
    )

    static let jacketRules = JacketRulesConfig(
        maximumDryPrecipitationAmountMillimeters: 0,
        cautionPrecipitationChanceFraction: 0.10,
        avoidPrecipitationChanceFraction: 0.20,
        maximumOkayTemperatureCelsius: 15,
        maximumCautionTemperatureCelsius: 20
    )

    static let dayPeriods = DayPeriodConfig(
        minimumMeaningfulChangeHours: 3,
        isolatedAvoidSafetyHours: 2,
        minimumNoisyAlternationHours: 3
    )

    static let itemRules = ItemRulesConfig(
        minimumUsefulHours: 2,
        warmCoat: ColdWeatherItemRules(maximumUsefulCelsius: 5, maximumMaybeCelsius: 12),
        sweater: ColdWeatherItemRules(maximumUsefulCelsius: 12, maximumMaybeCelsius: 18),
        gloves: ColdWeatherItemRules(maximumUsefulCelsius: 5, maximumMaybeCelsius: 10),
        shortsMinimumUsefulCelsius: 22,
        shortsMinimumMaybeCelsius: 17,
        raincoatUsefulAmountMillimeters: 0.5,
        raincoatMaybeChanceFraction: 0.30,
        raincoatWindUpgradeKilometersPerHour: 30,
        sunglassesUsefulUVIndex: 6
    )

    static let reusePolicy = ReusePolicyConfig(
        locationFreshness: 30 * 60,
        weatherRefreshInterval: 15 * 60,
        weatherFreshness: 90 * 60,
        maximumForecastDistanceMeters: 5_000,
        weatherRequestTimeout: .seconds(10),
        failedRequestCooldown: 30
    )
}
