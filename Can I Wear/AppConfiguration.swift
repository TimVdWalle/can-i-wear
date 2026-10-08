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

nonisolated struct ReusePolicyConfig: Equatable, Sendable {
    let locationFreshness: TimeInterval
    let weatherFreshness: TimeInterval
    let maximumForecastDistanceMeters: Double
    let weatherRequestTimeout: Duration
}

nonisolated enum AppConfiguration {
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

    static let reusePolicy = ReusePolicyConfig(
        locationFreshness: 30 * 60,
        weatherFreshness: 30 * 60,
        maximumForecastDistanceMeters: 5_000,
        weatherRequestTimeout: .seconds(10)
    )
}
