import Foundation
import Testing
@testable import Can_I_Wear

struct RefreshPolicyTests {
    private let fetchedAt = Date(timeIntervalSince1970: 1_791_201_600)

    @Test func freshnessAndForcedFetchBoundariesAreUnchanged() {
        let policy = RefreshPolicy()
        #expect(!policy.shouldFetchWeather(age: 899.999, forced: false))
        #expect(policy.shouldFetchWeather(age: 900, forced: false))
        #expect(policy.shouldFetchWeather(age: 0, forced: true))
        #expect(policy.isWeatherUsable(fetchedAt: fetchedAt, at: date(5_400)))
        #expect(!policy.isWeatherUsable(fetchedAt: fetchedAt, at: date(5_400.001)))
        #expect(policy.automaticAction(fetchedAt: fetchedAt, at: date(899.999)) == .wait)
        #expect(policy.automaticAction(fetchedAt: fetchedAt, at: date(900)) == .refresh)
    }

    @Test func routineAndExpiryAttemptsAreSeparateAndResetOnSuccess() {
        var policy = RefreshPolicy()
        policy.recordAttempt(fetchedAt: nil, at: date(900))
        #expect(policy.automaticAction(fetchedAt: fetchedAt, at: date(900)) == .refresh)
        policy.recordAttempt(fetchedAt: fetchedAt, at: date(900))
        #expect(policy.automaticAction(fetchedAt: fetchedAt, at: date(901)) == .wait)
        #expect(policy.automaticAction(fetchedAt: fetchedAt, at: date(5_400)) == .refresh)
        policy.recordAttempt(fetchedAt: fetchedAt, at: date(5_400))
        #expect(policy.automaticAction(fetchedAt: fetchedAt, at: date(5_400)) == .wait)
        #expect(policy.automaticAction(fetchedAt: fetchedAt, at: date(5_400.001)) == .expire)
        #expect(policy.automaticAction(fetchedAt: date(1), at: date(901)) == .refresh)
        policy.recordRetryFailure(at: date(5_400))
        policy.recordWeatherSuccess()
        #expect(policy.failureCooldownUntil == nil)
        #expect(policy.retryAvailableAt == nil)
        #expect(policy.automaticAction(fetchedAt: fetchedAt, at: date(900)) == .refresh)
        #expect(policy.automaticAction(fetchedAt: fetchedAt, at: date(5_400)) == .refresh)
    }

    @Test func cooldownDistinguishesRefreshFromRetryAndDoesNotDelayExpiry() {
        var policy = RefreshPolicy()
        #expect(policy.canRetry(at: fetchedAt))
        #expect(policy.retryCountdown(at: fetchedAt) == nil)
        #expect(policy.refreshAvailableAt(fetchedAt: fetchedAt) == date(900))
        policy.recordRefreshFailure(at: date(5_390))
        #expect(policy.retryAvailableAt == nil)
        #expect(policy.manualRefreshBlockedUntil(at: date(5_419.999)) == date(5_420))
        #expect(policy.manualRefreshBlockedUntil(at: date(5_420)) == nil)
        #expect(policy.automaticAction(fetchedAt: fetchedAt, at: date(5_399)) == .wait)
        #expect(policy.automaticAction(fetchedAt: fetchedAt, at: date(5_400)) == .refresh)
        #expect(policy.refreshAvailableAt(fetchedAt: fetchedAt) == date(5_420))
        policy.recordRetryFailure(at: date(900))
        #expect(!policy.canRetry(at: date(929.999)))
        #expect(policy.canRetry(at: date(930)))
        #expect(policy.retryCountdown(at: date(900)) == 30)
        #expect(policy.retryCountdown(at: date(929.999)) == 1)
        #expect(policy.retryCountdown(at: date(930)) == nil)
    }

    @Test func schedulingKeepsHourRefreshCooldownAndInclusiveExpiryBoundaries() {
        var policy = RefreshPolicy()
        #expect(next(policy, at: 0) == date(900))
        #expect(next(policy, at: 0, hour: date(-3_540)) == date(60))
        #expect(policy.nextActionDate(fetchedAt: nil, evaluationHour: nil, hasResult: true, at: fetchedAt) == nil)
        #expect(policy.nextActionDate(fetchedAt: fetchedAt, evaluationHour: nil, hasResult: false, at: fetchedAt) == nil)
        #expect(next(policy, at: 900) == date(900))
        policy.recordRefreshFailure(at: date(900))
        #expect(next(policy, at: 900) == date(930))
        policy.recordAttempt(fetchedAt: fetchedAt, at: date(900))
        #expect(next(policy, at: 930) == date(5_400))
        #expect(next(policy, at: 930, hour: fetchedAt) == date(3_600))
        #expect(next(policy, at: 5_400) == date(5_400))
        policy.recordAttempt(fetchedAt: fetchedAt, at: date(5_400))
        #expect(next(policy, at: 5_400) == date(5_400.001))
        #expect(next(policy, at: 5_401) == date(5_401))
    }

    @Test func injectedConfigurationControlsEveryTimingBoundary() {
        let config = ReusePolicyConfig(
            locationFreshness: 1, weatherRefreshInterval: 2, weatherFreshness: 4,
            maximumForecastDistanceMeters: 5, weatherRequestTimeout: .seconds(6), failedRequestCooldown: 7
        )
        var policy = RefreshPolicy(config: config)
        #expect(policy.refreshInterval == 2)
        #expect(policy.maximumWeatherAge == 4)
        #expect(policy.failureCooldown == 7)
        #expect(!policy.shouldFetchWeather(age: 1, forced: false))
        #expect(policy.shouldFetchWeather(age: 2, forced: false))
        #expect(!policy.isWeatherUsable(fetchedAt: fetchedAt, at: date(4.001)))
        policy.recordRetryFailure(at: fetchedAt)
        #expect(policy.retryAvailableAt == date(7))
        #expect(policy.automaticAction(fetchedAt: fetchedAt, at: date(4)) == .refresh)
    }

    private func date(_ seconds: TimeInterval) -> Date { fetchedAt.addingTimeInterval(seconds) }

    private func next(_ policy: RefreshPolicy, at seconds: TimeInterval, hour: Date? = nil) -> Date? {
        policy.nextActionDate(fetchedAt: fetchedAt, evaluationHour: hour, hasResult: true, at: date(seconds))
    }
}
