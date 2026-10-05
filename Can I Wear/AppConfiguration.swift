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
}
