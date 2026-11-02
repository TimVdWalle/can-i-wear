import Foundation

/// Load reporting only. Request policy, fallback selection and observable recommendation state stay with the view model.
@MainActor
final class RecommendationLoadDiagnostics {
    private struct LocationContext {
        let reading: LocationReading
        let source: String
        let cacheStatus: String
    }

    private struct WeatherContext {
        let trigger: String
        let outcome: String
        let cacheStatus: String
        let duration: TimeInterval?
    }

    private let diagnostics: DebugDiagnostics
    private let providerName: String
    private let config: ReusePolicyConfig
    private var locationContext: LocationContext?
    private var weatherContext: WeatherContext?

    init(diagnostics: DebugDiagnostics, providerName: String, config: ReusePolicyConfig) {
        self.diagnostics = diagnostics
        self.providerName = providerName
        self.config = config
    }

    /// Returns true only on enablement; the caller can then record a fresh evaluation without changing screen state.
    func refreshSetting(forecast: NormalizedForecast?, at date: Date) -> Bool {
        let wasEnabled = diagnostics.isEnabled
        diagnostics.refreshSetting()
        guard !wasEnabled, diagnostics.isEnabled else { return false }
        if let context = locationContext {
            diagnostics.updateLocation(
                context.reading, source: context.source,
                ageSeconds: max(0, date.timeIntervalSince(context.reading.timestamp)), cacheStatus: context.cacheStatus
            )
        }
        if let forecast, let context = weatherContext {
            diagnostics.updateWeather(
                forecast, provider: providerName, trigger: context.trigger, outcome: context.outcome,
                durationSeconds: context.duration, cacheStatus: context.cacheStatus
            )
        }
        return true
    }

    func manualRefreshBlocked(remaining: TimeInterval? = nil) {
        let detail = remaining.map {
            "Available in \(RecommendationDiagnosticText.countdownText($0)) after the previous failure."
        } ?? "A location or weather request is already running."
        diagnostics.record(category: .weather, outcome: .rejected, title: "Manual refresh blocked", detail: detail)
    }

    func retryBlocked(remaining: TimeInterval? = nil) {
        let detail = remaining.map { "Available in \(RecommendationDiagnosticText.countdownText($0))." }
            ?? "A request is already running."
        diagnostics.record(category: .weather, outcome: .rejected, title: "Retry blocked", detail: detail)
    }

    func manualRefreshStarted() {
        diagnostics.record(
            category: .weather, outcome: .started, title: "Manual refresh started",
            detail: "The user pulled down to reacquire location, then check whether weather needs refreshing."
        )
    }

    func retryRequested() {
        diagnostics.record(
            category: .session, outcome: .started, title: "Retry requested",
            detail: "The user requested a new location and weather attempt."
        )
    }

    func loadStarted(trigger: String) {
        diagnostics.record(category: .session, outcome: .started, title: "Recommendation load", detail: "\(trigger) requested.")
    }

    func reusedLocation(_ reading: LocationReading, age: TimeInterval) {
        updateLocation(reading, source: "Location cache", age: age, cacheStatus: "Reused: fresh and sufficiently accurate")
        diagnostics.record(
            category: .cache, outcome: .reused, title: "Location cache",
            detail: "Reused a \(RecommendationDiagnosticText.durationText(age))-old reading with \(RecommendationDiagnosticText.accuracyText(reading.accuracyMeters))."
        )
    }

    func locationCacheRejected(_ reason: LocationCacheRejectionReason) {
        diagnostics.record(category: .cache, outcome: .rejected, title: "Location cache", detail: RecommendationDiagnosticText.locationCacheReason(reason))
    }

    func locationRequestStarted(cacheRejection: LocationCacheRejectionReason?) {
        let reason = cacheRejection.map {
            "Requested because the cache was not reusable: \(RecommendationDiagnosticText.locationCacheReason($0))"
        } ?? "Pull-to-refresh requires a new device fix instead of saved location."
        diagnostics.record(category: .location, outcome: .started, title: "Location request", detail: reason)
    }

    func acquiredLocation(_ reading: LocationReading, cacheRejection: LocationCacheRejectionReason?, at date: Date, duration: TimeInterval) {
        let cacheStatus = cacheRejection.map(RecommendationDiagnosticText.shortLocationCacheReason)
            ?? "Saved location bypassed for pull-to-refresh"
        updateLocation(
            reading, source: "Live device location", age: max(0, date.timeIntervalSince(reading.timestamp)),
            cacheStatus: "New reading • \(cacheStatus)"
        )
        diagnostics.record(
            category: .location, outcome: .success, title: "Location request",
            detail: "Accepted and cached a reading with \(RecommendationDiagnosticText.accuracyText(reading.accuracyMeters)).",
            durationSeconds: duration
        )
    }

    func locationFailed(_ detail: String, duration: TimeInterval) {
        diagnostics.record(category: .error, outcome: .failed, title: "Location request", detail: detail, durationSeconds: duration)
    }

    func cachedWeatherFound(_ forecast: NormalizedForecast, age: TimeInterval, distance: Double) {
        updateWeather(
            forecast, trigger: "Cache policy", outcome: "Usable saved forecast",
            cacheStatus: "\(RecommendationDiagnosticText.ageText(age)) old; location separation \(RecommendationDiagnosticText.distanceText(distance))"
        )
    }

    func weatherRefreshSkipped(_ forecast: NormalizedForecast, age: TimeInterval) {
        updateWeather(
            forecast, trigger: "Cache policy", outcome: "Refresh skipped",
            cacheStatus: "Used; \(RecommendationDiagnosticText.ageText(age)) old; refresh skipped"
        )
        diagnostics.record(
            category: .cache, outcome: .reused, title: "Weather cache used",
            detail: "\(RecommendationDiagnosticText.ageText(age)) old; refresh skipped because weather is current for \(RecommendationDiagnosticText.ageText(config.weatherRefreshInterval))."
        )
    }

    func cachedWeatherRefreshing(age: TimeInterval, isManual: Bool) {
        diagnostics.record(
            category: .cache, outcome: .reused, title: "Weather cache used",
            detail: "\(RecommendationDiagnosticText.ageText(age)) old; \(isManual ? "manual" : "background") refresh started."
        )
    }

    func weatherCacheExpired(age: TimeInterval, distance: Double) {
        diagnostics.record(
            category: .cache, outcome: .rejected, title: "Weather cache",
            detail: "Rejected at \(RecommendationDiagnosticText.ageText(age)) old because the \(RecommendationDiagnosticText.ageText(config.weatherFreshness)) usable limit was exceeded; location separation \(RecommendationDiagnosticText.distanceText(distance))."
        )
    }

    func weatherCacheUnavailable(_ reason: WeatherCacheRejectionReason) {
        diagnostics.record(category: .cache, outcome: .rejected, title: "Weather cache", detail: RecommendationDiagnosticText.weatherCacheReason(reason))
    }

    func weatherRequestStarted(trigger: String) {
        let components = config.weatherRequestTimeout.components
        let timeout = TimeInterval(components.seconds) + TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000
        diagnostics.record(
            category: .weather, outcome: .started, title: "Weather request",
            detail: "\(trigger) requested live weather. Timeout: \(RecommendationDiagnosticText.durationText(timeout))."
        )
    }

    func liveWeatherReceived(_ forecast: NormalizedForecast, duration: TimeInterval) {
        updateWeather(
            forecast, trigger: "Live refresh after location resolution", outcome: "Success",
            cacheStatus: "Live response; saved after successful evaluation", duration: duration
        )
        diagnostics.record(
            category: .weather, outcome: .success, title: "Weather request",
            detail: "Received \(forecast.hours.count) normalized hourly records from \(providerName).", durationSeconds: duration
        )
    }

    func weatherFailed(_ detail: String, duration: TimeInterval) {
        diagnostics.record(category: .error, outcome: .failed, title: "Weather request", detail: detail, durationSeconds: duration)
    }

    func selectedItemForecastUnavailable() {
        diagnostics.record(
            category: .evaluation, outcome: .failed, title: "Selected-item forecast unavailable",
            detail: "The live response cannot advise on any selected item; retaining still-usable saved advice."
        )
    }

    func weatherSaved() {
        diagnostics.record(
            category: .cache, outcome: .success, title: "Weather cache save",
            detail: "Saved the valid normalized forecast after evaluation."
        )
    }

    func fallbackExpired() {
        diagnostics.record(
            category: .cache, outcome: .rejected, title: "Weather fallback",
            detail: "The saved forecast crossed the \(RecommendationDiagnosticText.ageText(config.weatherFreshness)) limit while the request was running."
        )
    }

    func reusedFallback(_ forecast: NormalizedForecast, age: TimeInterval) {
        updateWeather(
            forecast, trigger: "Fallback after live request failure", outcome: "Reused cached forecast",
            cacheStatus: "Refresh failed; using \(RecommendationDiagnosticText.ageText(age))-old saved weather"
        )
        diagnostics.record(
            category: .cache, outcome: .reused, title: "Weather fallback",
            detail: "Refresh failed; retained the \(RecommendationDiagnosticText.ageText(age))-old saved forecast. Manual refresh is available again in \(RecommendationDiagnosticText.countdownText(config.failedRequestCooldown))."
        )
    }

    func evaluationFailed() {
        diagnostics.record(
            category: .evaluation, outcome: .failed, title: "Forecast evaluation",
            detail: "Timezone or remaining-day coverage requirements were not met."
        )
    }

    func evaluated(_ output: RecommendationPresentationBuilder.Output, forecast: NormalizedForecast) {
        if let evaluation = output.jacketEvaluation {
            diagnostics.updateEvaluation(forecast: forecast, evaluation: evaluation, periods: output.jacketPeriods)
        } else {
            diagnostics.clearEvaluation()
        }
        let itemResults = output.presentation.itemResults
        diagnostics.record(
            category: .evaluation, outcome: .success, title: "Recommendation periods",
            detail: "Evaluated \(output.remainingHourCount) remaining hours; \(itemResults.filter { $0.evaluation != nil }.count) of \(itemResults.count) selected items have daily advice. Jacket diagnostics retain their own protective policy."
        )
    }

    func clearEvaluation() {
        diagnostics.clearEvaluation()
    }

    func weatherExpired() {
        diagnostics.record(
            category: .cache, outcome: .rejected, title: "Weather recommendation expired",
            detail: "The displayed saved forecast crossed the \(RecommendationDiagnosticText.ageText(config.weatherFreshness)) usable limit."
        )
    }

    func retryCooldown() {
        diagnostics.record(
            category: .session, outcome: .rejected, title: "Retry cooldown",
            detail: "Another retry is available in \(RecommendationDiagnosticText.countdownText(config.failedRequestCooldown))."
        )
    }

    private func updateLocation(_ reading: LocationReading, source: String, age: TimeInterval, cacheStatus: String) {
        locationContext = LocationContext(reading: reading, source: source, cacheStatus: cacheStatus)
        diagnostics.updateLocation(reading, source: source, ageSeconds: age, cacheStatus: cacheStatus)
    }

    private func updateWeather(_ forecast: NormalizedForecast, trigger: String, outcome: String, cacheStatus: String, duration: TimeInterval? = nil) {
        weatherContext = WeatherContext(trigger: trigger, outcome: outcome, cacheStatus: cacheStatus, duration: duration)
        diagnostics.updateWeather(
            forecast, provider: providerName, trigger: trigger, outcome: outcome,
            durationSeconds: duration, cacheStatus: cacheStatus
        )
    }
}
