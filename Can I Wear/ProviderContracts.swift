import Foundation

/// App-owned location identity. Keeping this independent of Core Location makes
/// domain code and tests portable.
nonisolated struct LocationIdentity: Equatable, Sendable {
    let latitude: Double
    let longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

nonisolated struct LocationReading: Equatable, Sendable {
    let identity: LocationIdentity
    let accuracyMeters: Double?
    let timestamp: Date
}

nonisolated enum LocationProviderError: Error, Equatable, Sendable {
    case permissionDenied
    case unavailable
    case timedOut
    case cancelled
}

nonisolated protocol LocationProvider: Sendable {
    @MainActor
    func currentLocation() async throws -> LocationReading
}

nonisolated enum PrecipitationType: String, Equatable, Sendable {
    case none
    case drizzle
    case rain
    case hail
    case snow
    case sleet
    case mixed
    case unknown
}

nonisolated struct HourlyWeather: Equatable, Sendable {
    let timestamp: Date
    /// Nil when the provider does not supply a timezone for the forecast location.
    let timezoneIdentifier: String?
    let actualTemperatureCelsius: Double?
    let apparentTemperatureCelsius: Double?
    let precipitationAmountMillimeters: Double?
    let precipitationType: PrecipitationType?
    /// A provider-normalized value from 0 (impossible) through 1 (certain).
    let precipitationChanceFraction: Double?
}

nonisolated struct ForecastMetadata: Equatable, Sendable {
    let fetchedAt: Date
    let location: LocationIdentity
}

nonisolated struct NormalizedForecast: Equatable, Sendable {
    let hours: [HourlyWeather]
    let metadata: ForecastMetadata
}

nonisolated enum WeatherProviderError: Error, Equatable, Sendable {
    case unavailable
    case network
    case unauthorized
    case cancelled
}

nonisolated protocol WeatherProvider: Sendable {
    func hourlyForecast(for location: LocationIdentity) async throws -> NormalizedForecast
}
