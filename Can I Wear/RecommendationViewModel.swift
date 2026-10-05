import Foundation
import Observation

nonisolated struct RecommendationPresentation: Equatable, Sendable {
    let title: String
    let reason: String
    let symbolName: String

    init(recommendation: HourlyRecommendation) {
        switch recommendation.level {
        case .okay:
            title = "Wear"
            symbolName = "checkmark.circle.fill"
        case .caution:
            title = "Maybe"
            symbolName = "exclamationmark.triangle.fill"
        case .avoid:
            title = "Don’t wear"
            symbolName = "xmark.circle.fill"
        }

        reason = switch recommendation.reason {
        case .suitableTemperature:
            "No precipitation is expected, and it should not feel too warm."
        case .warmTemperature:
            "It may feel warm for a leather jacket."
        case .excessiveHeat:
            "It is expected to feel too warm for a leather jacket."
        case .precipitationRisk:
            "There is a small chance of precipitation today."
        case .precipitation:
            "Precipitation is expected today and could damage leather."
        case .incompleteForecast:
            "Part of today’s forecast is uncertain."
        }
    }
}

@MainActor
@Observable
final class RecommendationViewModel {
    enum State: Equatable {
        case idle
        case loading
        case result(RecommendationPresentation)
        case locationPermissionDenied
        case locationUnavailable
        case weatherUnavailable
        case forecastIncomplete
    }

    private(set) var state: State

    private let locationProvider: any LocationProvider
    private let weatherProvider: any WeatherProvider
    private let dailyEngine: DailyRecommendationEngine
    private let now: @Sendable () -> Date

    convenience init() {
        self.init(
            locationProvider: CoreLocationProvider(),
            weatherProvider: OpenMeteoProvider()
        )
    }

    convenience init(initialState: State) {
        self.init(
            locationProvider: CoreLocationProvider(),
            weatherProvider: OpenMeteoProvider(),
            initialState: initialState
        )
    }

    init(
        locationProvider: any LocationProvider,
        weatherProvider: any WeatherProvider,
        dailyEngine: DailyRecommendationEngine = DailyRecommendationEngine(),
        now: @escaping @Sendable () -> Date = { Date() },
        initialState: State = .idle
    ) {
        self.locationProvider = locationProvider
        self.weatherProvider = weatherProvider
        self.dailyEngine = dailyEngine
        self.now = now
        state = initialState
    }

    func loadIfNeeded() async {
        guard state == .idle else { return }
        state = .loading

        let location: LocationReading
        do {
            location = try await locationProvider.currentLocation()
        } catch LocationProviderError.permissionDenied {
            state = .locationPermissionDenied
            return
        } catch LocationProviderError.cancelled {
            state = .idle
            return
        } catch {
            state = .locationUnavailable
            return
        }

        let forecast: NormalizedForecast
        do {
            forecast = try await weatherProvider.hourlyForecast(for: location.identity)
        } catch WeatherProviderError.cancelled {
            state = .idle
            return
        } catch {
            state = .weatherUnavailable
            return
        }

        guard let recommendation = dailyEngine.evaluate(forecast, now: now()) else {
            state = .forecastIncomplete
            return
        }
        state = .result(RecommendationPresentation(recommendation: recommendation))
    }

    func retry() async {
        state = .idle
        await loadIfNeeded()
    }
}
