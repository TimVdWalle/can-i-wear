import Foundation

/// Data access only. The caller evaluates item usability, publishes state and authorizes weather saves.
@MainActor
struct ForecastLoader {
    typealias Sleep = @Sendable (Duration) async throws -> Void

    enum LocationSource {
        case cached(LocationReading, age: TimeInterval)
        /// Nil rejection means the caller deliberately bypassed location reuse.
        case device(cacheRejection: LocationCacheRejectionReason?)
    }

    private let locationProvider: any LocationProvider
    private let weatherProvider: any WeatherProvider
    private let locationCache: LocationCache
    private let weatherCache: WeatherCache
    private let config: ReusePolicyConfig
    private let sleep: Sleep

    init(
        locationProvider: any LocationProvider,
        weatherProvider: any WeatherProvider,
        locationCache: LocationCache,
        weatherCache: WeatherCache,
        config: ReusePolicyConfig = AppConfiguration.reusePolicy,
        sleep: @escaping Sleep = { try await Task.sleep(for: $0) }
    ) {
        self.locationProvider = locationProvider
        self.weatherProvider = weatherProvider
        self.locationCache = locationCache
        self.weatherCache = weatherCache
        self.config = config
        self.sleep = sleep
    }

    var weatherProviderName: String { weatherProvider.diagnosticName }
    var weatherRequestTimeout: Duration { config.weatherRequestTimeout }

    func locationSource(reacquire: Bool, at date: Date) async -> LocationSource {
        guard !reacquire else { return .device(cacheRejection: nil) }
        switch await locationCache.lookup(at: date) {
        case .valid(let reading, let age): return .cached(reading, age: age)
        case .unavailable(let reason): return .device(cacheRejection: reason)
        }
    }

    func acquireLocation() async throws -> LocationReading {
        let reading = try await locationProvider.currentLocation()
        await locationCache.save(reading)
        return reading
    }

    func cachedWeather(for location: LocationIdentity, at date: Date) async -> WeatherCacheDiagnosticLookup {
        await weatherCache.diagnosticLookup(at: date, for: location)
    }

    func matchesForecastLocation(_ forecast: NormalizedForecast, location: LocationIdentity) -> Bool {
        forecast.metadata.location.distance(to: location) <= config.maximumForecastDistanceMeters
    }

    func fetchLiveForecast(for location: LocationIdentity) async throws -> NormalizedForecast {
        let weatherProvider = weatherProvider
        let timeout = config.weatherRequestTimeout
        let sleep = sleep
        return try await withThrowingTaskGroup(of: NormalizedForecast.self) { group in
            group.addTask { try await weatherProvider.hourlyForecast(for: location) }
            group.addTask {
                try await sleep(timeout)
                throw WeatherProviderError.timedOut
            }
            defer { group.cancelAll() }
            guard let forecast = try await group.next() else { throw WeatherProviderError.unavailable }
            return forecast
        }
    }

    /// Call only after recommendation evaluation has accepted this live candidate.
    func saveAcceptedForecast(_ forecast: NormalizedForecast) async {
        await weatherCache.save(forecast)
    }
}
