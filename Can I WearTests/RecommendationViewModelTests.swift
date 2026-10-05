import Foundation
import Testing
@testable import Can_I_Wear

@MainActor
struct RecommendationViewModelTests {
    private let now = Date(timeIntervalSince1970: 1_791_203_400)
    private let currentHour = Date(timeIntervalSince1970: 1_791_201_600)
    private let location = LocationIdentity(latitude: 50.85, longitude: 4.35)

    @Test func mapsSuccessfulWearCautionAndAvoidResults() async {
        let wear = makeModel(forecast: forecast())
        let caution = makeModel(forecast: forecast(chance: 0.10))
        let avoid = makeModel(forecast: forecast(amount: 1))

        await wear.loadIfNeeded()
        await caution.loadIfNeeded()
        await avoid.loadIfNeeded()

        #expect(wear.state.result?.title == "Wear")
        #expect(caution.state.result?.title == "Maybe")
        #expect(avoid.state.result?.title == "Don’t wear")
        #expect(avoid.state.result?.reason.contains("damage leather") == true)
    }

    @Test func representsLocationAndWeatherFailuresExplicitly() async {
        let denied = RecommendationViewModel(
            locationProvider: FixedLocationProvider(result: .failure(.permissionDenied)),
            weatherProvider: FixedWeatherProvider(result: .failure(.unavailable)),
            now: { self.now }
        )
        let weatherFailure = RecommendationViewModel(
            locationProvider: fixedLocationProvider(),
            weatherProvider: FixedWeatherProvider(result: .failure(.network)),
            now: { self.now }
        )

        await denied.loadIfNeeded()
        await weatherFailure.loadIfNeeded()

        #expect(denied.state == .locationPermissionDenied)
        #expect(weatherFailure.state == .weatherUnavailable)
    }

    @Test func representsIncompleteForecastWithoutInventingAResult() async {
        let model = makeModel(forecast: forecast().replacingHours(with: []))

        await model.loadIfNeeded()

        #expect(model.state == .forecastIncomplete)
    }

    @Test func repeatedLoadDoesNotDuplicateProviderRequests() async {
        let locationProvider = CountingLocationProvider(reading: locationReading())
        let weatherProvider = CountingWeatherProvider(forecast: forecast())
        let model = RecommendationViewModel(
            locationProvider: locationProvider,
            weatherProvider: weatherProvider,
            now: { self.now }
        )

        await model.loadIfNeeded()
        await model.loadIfNeeded()

        #expect(locationProvider.requestCount == 1)
        #expect(await weatherProvider.requestCount == 1)
    }

    private func makeModel(forecast: NormalizedForecast) -> RecommendationViewModel {
        RecommendationViewModel(
            locationProvider: fixedLocationProvider(),
            weatherProvider: FixedWeatherProvider(result: .success(forecast)),
            now: { self.now }
        )
    }

    private func fixedLocationProvider() -> FixedLocationProvider {
        FixedLocationProvider(result: .success(locationReading()))
    }

    private func locationReading() -> LocationReading {
        LocationReading(identity: location, accuracyMeters: 25, timestamp: now)
    }

    private func forecast(amount: Double = 0, chance: Double = 0) -> NormalizedForecast {
        let hours = (0..<10).map { offset in
            HourlyWeather(
                timestamp: currentHour.addingTimeInterval(TimeInterval(offset * 3_600)),
                timezoneIdentifier: "Europe/Brussels",
                actualTemperatureCelsius: 12,
                apparentTemperatureCelsius: 12,
                precipitationAmountMillimeters: amount,
                precipitationType: PrecipitationType.none,
                precipitationChanceFraction: chance
            )
        }
        return NormalizedForecast(
            hours: hours,
            metadata: ForecastMetadata(fetchedAt: now, location: location)
        )
    }
}

@MainActor
private final class CountingLocationProvider: LocationProvider {
    let reading: LocationReading
    private(set) var requestCount = 0

    init(reading: LocationReading) {
        self.reading = reading
    }

    func currentLocation() async throws -> LocationReading {
        requestCount += 1
        return reading
    }
}

private actor CountingWeatherProvider: WeatherProvider {
    let forecast: NormalizedForecast
    private(set) var requestCount = 0

    init(forecast: NormalizedForecast) {
        self.forecast = forecast
    }

    func hourlyForecast(for location: LocationIdentity) async throws -> NormalizedForecast {
        requestCount += 1
        return forecast
    }
}

private extension RecommendationViewModel.State {
    var result: RecommendationPresentation? {
        guard case .result(let presentation) = self else { return nil }
        return presentation
    }
}

private extension NormalizedForecast {
    func replacingHours(with hours: [HourlyWeather]) -> NormalizedForecast {
        NormalizedForecast(hours: hours, metadata: metadata)
    }
}
