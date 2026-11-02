import Foundation

/// Request timing and attempt bookkeeping only. No I/O, recommendation evaluation or screen state.
nonisolated struct RefreshPolicy: Sendable {
    enum AutomaticAction: Equatable {
        case wait
        case refresh
        case expire
    }

    private let config: ReusePolicyConfig
    private var routineAttemptedForForecast: Date?
    private var expiryAttemptedForForecast: Date?
    private(set) var failureCooldownUntil: Date?
    private(set) var retryAvailableAt: Date?

    init(config: ReusePolicyConfig = AppConfiguration.reusePolicy) {
        self.config = config
    }

    var maximumWeatherAge: TimeInterval { config.weatherFreshness }
    var refreshInterval: TimeInterval { config.weatherRefreshInterval }
    var failureCooldown: TimeInterval { config.failedRequestCooldown }

    func isWeatherUsable(fetchedAt: Date, at date: Date) -> Bool {
        date.timeIntervalSince(fetchedAt) <= config.weatherFreshness
    }

    func shouldFetchWeather(age: TimeInterval, forced: Bool) -> Bool {
        forced || age >= config.weatherRefreshInterval
    }

    func manualRefreshBlockedUntil(at date: Date) -> Date? {
        failureCooldownUntil.flatMap { $0 > date ? $0 : nil }
    }

    func canRetry(at date: Date) -> Bool {
        retryAvailableAt.map { $0 <= date } ?? true
    }

    func retryCountdown(at date: Date) -> Int? {
        guard let retryAvailableAt, retryAvailableAt > date else { return nil }
        return max(1, Int(ceil(retryAvailableAt.timeIntervalSince(date))))
    }

    func refreshAvailableAt(fetchedAt: Date) -> Date {
        max(fetchedAt.addingTimeInterval(config.weatherRefreshInterval), failureCooldownUntil ?? .distantPast)
    }

    mutating func recordAttempt(fetchedAt: Date?, at date: Date) {
        guard let fetchedAt else { return }
        if max(0, date.timeIntervalSince(fetchedAt)) >= config.weatherFreshness {
            expiryAttemptedForForecast = fetchedAt
        } else {
            routineAttemptedForForecast = fetchedAt
        }
    }

    mutating func recordWeatherSuccess() {
        failureCooldownUntil = nil
        retryAvailableAt = nil
        routineAttemptedForForecast = nil
        expiryAttemptedForForecast = nil
    }

    mutating func recordRefreshFailure(at date: Date) {
        failureCooldownUntil = date.addingTimeInterval(config.failedRequestCooldown)
    }

    mutating func recordRetryFailure(at date: Date) {
        recordRefreshFailure(at: date)
        retryAvailableAt = failureCooldownUntil
    }

    func automaticAction(fetchedAt: Date, at date: Date) -> AutomaticAction {
        let age = max(0, date.timeIntervalSince(fetchedAt))
        guard age >= config.weatherRefreshInterval else { return .wait }
        if let cooldown = failureCooldownUntil, cooldown > date, age < config.weatherFreshness {
            return .wait
        }
        if age >= config.weatherFreshness {
            if expiryAttemptedForForecast == fetchedAt {
                return age > config.weatherFreshness ? .expire : .wait
            }
        } else if routineAttemptedForForecast == fetchedAt {
            return .wait
        }
        return .refresh
    }

    func nextActionDate(
        fetchedAt: Date?, evaluationHour: Date?, hasResult: Bool, at date: Date
    ) -> Date? {
        guard let fetchedAt, hasResult else { return nil }
        let weatherDate = nextWeatherActionDate(fetchedAt: fetchedAt, at: date)
        guard let evaluationHour else { return weatherDate }
        return min(weatherDate, evaluationHour.addingTimeInterval(3_600))
    }

    private func nextWeatherActionDate(fetchedAt: Date, at date: Date) -> Date {
        let refreshDate = fetchedAt.addingTimeInterval(config.weatherRefreshInterval)
        let expiryDate = fetchedAt.addingTimeInterval(config.weatherFreshness)
        if date < refreshDate { return refreshDate }
        if date < expiryDate {
            if routineAttemptedForForecast != fetchedAt {
                return max(date, failureCooldownUntil ?? .distantPast)
            }
            return expiryDate
        }
        if expiryAttemptedForForecast == fetchedAt {
            // Exactly the maximum age remains usable; wake just after that inclusive boundary.
            return date <= expiryDate ? expiryDate.addingTimeInterval(0.001) : date
        }
        return date
    }
}
