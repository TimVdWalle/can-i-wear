import Foundation
@testable import Can_I_Wear

struct FixedLocationProvider: LocationProvider {
    let result: Result<LocationReading, LocationProviderError>

    func currentLocation() async throws -> LocationReading {
        try result.get()
    }
}

struct FixedWeatherProvider: WeatherProvider {
    let result: Result<NormalizedForecast, WeatherProviderError>

    func hourlyForecast(for location: LocationIdentity) async throws -> NormalizedForecast {
        try result.get()
    }
}
