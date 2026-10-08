import Foundation

nonisolated protocol CacheDataStore: Sendable {
    func data(forKey key: String) async -> Data?
    func set(_ data: Data?, forKey key: String) async
}

actor UserDefaultsCacheDataStore: CacheDataStore {
    static let shared = UserDefaultsCacheDataStore(defaults: .standard)

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func data(forKey key: String) -> Data? {
        defaults.data(forKey: key)
    }

    func set(_ data: Data?, forKey key: String) {
        defaults.set(data, forKey: key)
    }
}

nonisolated struct LocationCache: Sendable {
    private let store: any CacheDataStore
    private let config: ReusePolicyConfig
    private let maximumAcceptedAccuracyMeters: Double
    private let key: String

    init(
        store: any CacheDataStore = UserDefaultsCacheDataStore.shared,
        config: ReusePolicyConfig = AppConfiguration.reusePolicy,
        maximumAcceptedAccuracyMeters: Double = AppConfiguration.locationAcquisition.maximumAcceptedAccuracyMeters,
        key: String = "latestAcceptedLocation"
    ) {
        self.store = store
        self.config = config
        self.maximumAcceptedAccuracyMeters = maximumAcceptedAccuracyMeters
        self.key = key
    }

    func validReading(at now: Date) async -> LocationReading? {
        guard
            let data = await store.data(forKey: key),
            let reading = try? JSONDecoder().decode(LocationReading.self, from: data),
            isValid(reading, at: now)
        else { return nil }
        return reading
    }

    func save(_ reading: LocationReading) async {
        guard
            isAccepted(reading),
            let data = try? JSONEncoder().encode(reading)
        else { return }
        await store.set(data, forKey: key)
    }

    private func isValid(_ reading: LocationReading, at now: Date) -> Bool {
        let age = now.timeIntervalSince(reading.timestamp)
        return age >= 0 && age <= config.locationFreshness && isAccepted(reading)
    }

    private func isAccepted(_ reading: LocationReading) -> Bool {
        guard
            reading.identity.isValidCoordinate,
            let accuracy = reading.accuracyMeters,
            accuracy.isFinite,
            accuracy >= 0,
            accuracy <= maximumAcceptedAccuracyMeters
        else { return false }
        return true
    }
}

nonisolated struct WeatherCache: Sendable {
    private let store: any CacheDataStore
    private let config: ReusePolicyConfig
    private let key: String

    init(
        store: any CacheDataStore = UserDefaultsCacheDataStore.shared,
        config: ReusePolicyConfig = AppConfiguration.reusePolicy,
        key: String = "latestNormalizedForecast"
    ) {
        self.store = store
        self.config = config
        self.key = key
    }

    func validForecast(
        at now: Date,
        for location: LocationIdentity
    ) async -> NormalizedForecast? {
        guard case .valid(let forecast) = await lookup(at: now, for: location) else {
            return nil
        }
        return forecast
    }

    func lookup(
        at now: Date,
        for location: LocationIdentity
    ) async -> WeatherCacheLookup {
        guard
            location.isValidCoordinate,
            let data = await store.data(forKey: key),
            let forecast = try? JSONDecoder().decode(NormalizedForecast.self, from: data),
            isStructurallyValid(forecast),
            hasPotentialCoverage(forecast, at: now)
        else { return .unavailable }

        guard forecast.metadata.location.distance(to: location) <= config.maximumForecastDistanceMeters else {
            return .unavailable
        }
        let age = now.timeIntervalSince(forecast.metadata.fetchedAt)
        guard age >= 0 else { return .unavailable }
        guard age <= config.weatherFreshness else { return .expired }
        return .valid(forecast)
    }

    func save(_ forecast: NormalizedForecast) async {
        guard
            isStructurallyValid(forecast),
            let data = try? JSONEncoder().encode(forecast)
        else { return }
        await store.set(data, forKey: key)
    }

    private func isStructurallyValid(_ forecast: NormalizedForecast) -> Bool {
        guard
            forecast.metadata.location.isValidCoordinate,
            !forecast.hours.isEmpty,
            forecast.hours.allSatisfy({ $0.timestamp.timeIntervalSinceReferenceDate.isFinite })
        else { return false }
        return true
    }

    private func hasPotentialCoverage(_ forecast: NormalizedForecast, at now: Date) -> Bool {
        let identifiers = Set(forecast.hours.compactMap(\.timezoneIdentifier))
        guard
            identifiers.count == 1,
            let identifier = identifiers.first,
            let timezone = TimeZone(identifier: identifier)
        else { return false }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        guard
            let day = calendar.dateInterval(of: .day, for: now),
            let currentHour = calendar.dateInterval(of: .hour, for: now)?.start
        else { return false }
        return forecast.hours.contains {
            $0.timestamp >= currentHour && $0.timestamp < day.end
        }
    }
}

nonisolated enum WeatherCacheLookup: Equatable, Sendable {
    case valid(NormalizedForecast)
    case expired
    case unavailable
}

nonisolated private extension LocationIdentity {
    var isValidCoordinate: Bool {
        latitude.isFinite && longitude.isFinite
            && (-90...90).contains(latitude)
            && (-180...180).contains(longitude)
    }

    func distance(to other: LocationIdentity) -> Double {
        guard isValidCoordinate, other.isValidCoordinate else { return .infinity }

        let earthRadiusMeters = 6_371_000.0
        let latitude1 = latitude * .pi / 180
        let latitude2 = other.latitude * .pi / 180
        let latitudeDelta = (other.latitude - latitude) * .pi / 180
        let longitudeDelta = (other.longitude - longitude) * .pi / 180
        let a = sin(latitudeDelta / 2) * sin(latitudeDelta / 2)
            + cos(latitude1) * cos(latitude2)
            * sin(longitudeDelta / 2) * sin(longitudeDelta / 2)
        return earthRadiusMeters * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}
