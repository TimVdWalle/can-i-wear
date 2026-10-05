import CoreLocation
import Foundation
import WeatherKit

nonisolated struct WeatherKitHourlySnapshot: Sendable {
    let timestamp: Date
    let actualTemperature: Measurement<UnitTemperature>?
    let apparentTemperature: Measurement<UnitTemperature>?
    let precipitationAmount: Measurement<UnitLength>?
    let precipitation: WeatherKit.Precipitation?
    let precipitationChance: Double?
}

nonisolated protocol WeatherKitServing: Sendable {
    func hourlyWeather(for location: LocationIdentity) async throws -> [WeatherKitHourlySnapshot]
}

nonisolated struct SystemWeatherKitService: WeatherKitServing {
    func hourlyWeather(for location: LocationIdentity) async throws -> [WeatherKitHourlySnapshot] {
        let coreLocation = CLLocation(
            latitude: location.latitude,
            longitude: location.longitude
        )
        let forecast = try await WeatherService.shared.weather(for: coreLocation, including: .hourly)

        return forecast.map { hour in
            WeatherKitHourlySnapshot(
                timestamp: hour.date,
                actualTemperature: hour.temperature,
                apparentTemperature: hour.apparentTemperature,
                precipitationAmount: hour.precipitationAmount,
                precipitation: hour.precipitation,
                precipitationChance: hour.precipitationChance
            )
        }
    }
}

nonisolated struct WeatherKitProvider: WeatherProvider {
    private let service: any WeatherKitServing
    private let now: @Sendable () -> Date

    init(
        service: any WeatherKitServing = SystemWeatherKitService(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.service = service
        self.now = now
    }

    func hourlyForecast(for location: LocationIdentity) async throws -> NormalizedForecast {
        do {
            let snapshots = try await service.hourlyWeather(for: location)
            return NormalizedForecast(
                hours: snapshots.map(Self.normalize),
                metadata: ForecastMetadata(fetchedAt: now(), location: location)
            )
        } catch is CancellationError {
            throw WeatherProviderError.cancelled
        } catch let error as WeatherError {
            switch error {
            case .permissionDenied:
                throw WeatherProviderError.unauthorized
            case .unknown:
                throw WeatherProviderError.unavailable
            @unknown default:
                throw WeatherProviderError.unavailable
            }
        } catch is URLError {
            throw WeatherProviderError.network
        } catch let error as WeatherProviderError {
            throw error
        } catch {
            throw WeatherProviderError.unavailable
        }
    }

    private static func normalize(_ snapshot: WeatherKitHourlySnapshot) -> HourlyWeather {
        HourlyWeather(
            timestamp: snapshot.timestamp,
            timezoneIdentifier: nil,
            actualTemperatureCelsius: snapshot.actualTemperature?
                .converted(to: .celsius).value,
            apparentTemperatureCelsius: snapshot.apparentTemperature?
                .converted(to: .celsius).value,
            precipitationAmountMillimeters: snapshot.precipitationAmount?
                .converted(to: .millimeters).value,
            precipitationType: snapshot.precipitation.map(normalize),
            precipitationChanceFraction: snapshot.precipitationChance
        )
    }

    private static func normalize(_ precipitation: WeatherKit.Precipitation) -> PrecipitationType {
        switch precipitation {
        case .none:
            .none
        case .rain:
            .rain
        case .hail:
            .hail
        case .snow:
            .snow
        case .sleet:
            .sleet
        case .mixed:
            .mixed
        @unknown default:
            .unknown
        }
    }
}
