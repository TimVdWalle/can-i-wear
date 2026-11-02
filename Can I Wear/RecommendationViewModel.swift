import Foundation
import Observation

@MainActor
@Observable
final class RecommendationViewModel {
    typealias Sleep = ForecastLoader.Sleep

    enum State: Equatable {
        case idle
        case loading
        case result(DailyRecommendationPresentation)
        case locationPermissionDenied
        case locationUnavailable
        case weatherUnavailable
        case weatherDataExpired
        case forecastIncomplete
    }

    private(set) var state: State
    private(set) var locality: String?
    var retryAvailableAt: Date? { refreshPolicy.retryAvailableAt }
    private(set) var selectedItems: [PredefinedItem] = [.leatherJacket]
    let diagnostics: DebugDiagnostics

    private let loader: ForecastLoader
    private let presentationBuilder: RecommendationPresentationBuilder
    private let itemEngine = MultiItemRecommendationEngine()
    private var refreshPolicy: RefreshPolicy
    private let localityResolver: any LocalityResolving
    private let now: @Sendable () -> Date
    private let automaticRefreshSleep: Sleep
    private let isLifecycleManaged: Bool
    private var latestLocation: LocationReading?
    private var latestLocationSource = "Unavailable"
    private var latestLocationCacheStatus = "Unavailable"
    private var latestForecast: NormalizedForecast?
    private var latestWeatherTrigger = "Unavailable"
    private var latestWeatherOutcome = "Unavailable"
    private var latestWeatherCacheStatus = "Unavailable"
    private var latestWeatherDuration: TimeInterval?
    private var isRequestInFlight = false
    private var localityLocation: LocationIdentity?

    private enum LoadTrigger: Equatable {
        case initial
        case automatic
        case manual
        case retry

        var diagnosticText: String {
            switch self {
            case .initial: "App load"
            case .automatic: "Automatic refresh"
            case .manual: "Pull-to-refresh"
            case .retry: "Retry"
            }
        }
    }

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
        periodEngine: DayPeriodEngine = DayPeriodEngine(),
        locationCache: LocationCache = LocationCache(),
        weatherCache: WeatherCache = WeatherCache(),
        reuseConfig: ReusePolicyConfig = AppConfiguration.reusePolicy,
        diagnostics: DebugDiagnostics? = nil,
        localityResolver: (any LocalityResolving)? = nil,
        now: @escaping @Sendable () -> Date = { Date() },
        sleep: @escaping Sleep = { duration in try await Task.sleep(for: duration) },
        automaticRefreshSleep: @escaping Sleep = { duration in try await Task.sleep(for: duration) },
        initialState: State = .idle
    ) {
        self.loader = ForecastLoader(
            locationProvider: locationProvider, weatherProvider: weatherProvider,
            locationCache: locationCache, weatherCache: weatherCache, config: reuseConfig, sleep: sleep
        )
        self.presentationBuilder = RecommendationPresentationBuilder(dailyEngine: dailyEngine, periodEngine: periodEngine)
        self.refreshPolicy = RefreshPolicy(config: reuseConfig)
        self.diagnostics = diagnostics ?? DebugDiagnostics()
        self.localityResolver = localityResolver ?? SystemLocalityResolver()
        self.now = now
        self.automaticRefreshSleep = automaticRefreshSleep
        isLifecycleManaged = initialState == .idle
        state = initialState
    }

    func loadIfNeeded() async {
        guard state == .idle else { return }
        await performLoad(trigger: .initial, forceLiveWeather: false)
    }

    /// Selection is local presentation/evaluation work, never a location or weather request.
    func updateSelectedItems(_ items: [PredefinedItem]) {
        let selected = PredefinedItem.allCases.filter { items.contains($0) }
        guard !selected.isEmpty, selected != selectedItems else { return }
        selectedItems = selected
        guard let current = state.result, let forecast = latestForecast else { return }
        guard refreshPolicy.isWeatherUsable(fetchedAt: forecast.metadata.fetchedAt, at: now()) else {
            state = .weatherDataExpired
            return
        }
        if let updated = makePresentation(
            from: forecast, at: now(), isUsingSavedWeather: current.isUsingSavedWeather,
            isRefreshing: current.isRefreshing, refreshFailed: current.refreshFailed
        ) {
            state = .result(updated)
        } else {
            state = .forecastIncomplete
        }
    }

    func appBecameActive() async {
        refreshDebugSetting()

        if state == .idle {
            await performLoad(trigger: .initial, forceLiveWeather: false)
            return
        }

        if latestForecast != nil {
            await automaticRefreshIfNeeded()
        } else if isLifecycleManaged,
                  refreshPolicy.canRetry(at: now()) {
            await performLoad(trigger: .automatic, forceLiveWeather: true)
        }
    }

    func monitorAutomaticRefreshes() async {
        while !Task.isCancelled {
            guard let actionDate = refreshPolicy.nextActionDate(
                fetchedAt: latestForecast?.metadata.fetchedAt,
                evaluationHour: state.result?.evaluationHour, hasResult: state.result != nil, at: now()
            ) else { return }
            let delay = max(0, actionDate.timeIntervalSince(now()))
            do {
                try await automaticRefreshSleep(.seconds(delay))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await automaticRefreshIfNeeded()
        }
    }

    func manualRefresh() async {
        guard !isRequestInFlight else {
            recordRefreshBlocked(title: "Manual refresh blocked", detail: "A location or weather request is already running.")
            return
        }
        let currentTime = now()
        if let cooldown = refreshPolicy.manualRefreshBlockedUntil(at: currentTime) {
            recordRefreshBlocked(
                title: "Manual refresh blocked",
                detail: "Available in \(RecommendationDiagnosticText.countdownText(cooldown.timeIntervalSince(currentTime))) after the previous failure."
            )
            return
        }

        diagnostics.record(
            category: .weather,
            outcome: .started,
            title: "Manual refresh started",
            detail: "The user pulled down to reacquire location, then check whether weather needs refreshing."
        )
        await performLoad(trigger: .manual, forceLiveWeather: false)
    }

    func retry() async {
        guard !isRequestInFlight else {
            recordRefreshBlocked(title: "Retry blocked", detail: "A request is already running.")
            return
        }
        let currentTime = now()
        if let retryAvailableAt, retryAvailableAt > currentTime {
            recordRefreshBlocked(
                title: "Retry blocked",
                detail: "Available in \(RecommendationDiagnosticText.countdownText(retryAvailableAt.timeIntervalSince(currentTime)))."
            )
            return
        }

        diagnostics.record(
            category: .session,
            outcome: .started,
            title: "Retry requested",
            detail: "The user requested a new location and weather attempt."
        )
        await performLoad(trigger: .retry, forceLiveWeather: true)
    }

    func canRetry(at date: Date) -> Bool {
        !isRequestInFlight && refreshPolicy.canRetry(at: date)
    }

    func retryCountdown(at date: Date) -> Int? {
        refreshPolicy.retryCountdown(at: date)
    }

    private func performLoad(trigger: LoadTrigger, forceLiveWeather: Bool) async {
        guard !isRequestInFlight else { return }
        isRequestInFlight = true
        defer { isRequestInFlight = false }

        showLoadingPresentation()
        diagnostics.record(
            category: .session,
            outcome: .started,
            title: "Recommendation load",
            detail: "\(trigger.diagnosticText) requested."
        )

        guard let location = await loadLocation(trigger: trigger) else { return }

        discardMismatchedForecast(for: location.identity)
        let cache = await cachedWeather(for: location.identity)
        var fallback: CachedWeather?
        switch cache {
        case .usable(let cached):
            fallback = cached
            let shouldFetch = refreshPolicy.shouldFetchWeather(age: cached.age, forced: forceLiveWeather)
            if !shouldFetch {
                latestForecast = cached.forecast
                latestWeatherTrigger = "Cache policy"
                latestWeatherOutcome = "Refresh skipped"
                latestWeatherCacheStatus = "Used; \(RecommendationDiagnosticText.ageText(cached.age)) old; refresh skipped"
                latestWeatherDuration = nil
                diagnostics.updateWeather(
                    cached.forecast,
                    provider: loader.weatherProviderName,
                    trigger: latestWeatherTrigger,
                    outcome: latestWeatherOutcome,
                    durationSeconds: nil,
                    cacheStatus: latestWeatherCacheStatus
                )
                diagnostics.record(
                    category: .cache,
                    outcome: .reused,
                    title: "Weather cache used",
                    detail: "\(RecommendationDiagnosticText.ageText(cached.age)) old; refresh skipped because weather is current for \(RecommendationDiagnosticText.ageText(refreshPolicy.refreshInterval))."
                )
                guard let presentation = makePresentation(
                    from: cached.forecast,
                    at: now(),
                    isUsingSavedWeather: true,
                    isRefreshing: false,
                    refreshFailed: false
                ) else {
                    state = .forecastIncomplete
                    return
                }
                state = .result(presentation)
                return
            }

            if let presentation = makePresentation(
                from: cached.forecast,
                at: now(),
                isUsingSavedWeather: true,
                isRefreshing: true,
                refreshFailed: false
            ) {
                state = .result(presentation)
            }
            diagnostics.record(
                category: .cache,
                outcome: .reused,
                title: "Weather cache used",
                detail: "\(RecommendationDiagnosticText.ageText(cached.age)) old; \(trigger == .manual ? "manual" : "background") refresh started."
            )
        case .expired:
            state = .loading
        case .unavailable:
            if state.result == nil { state = .loading }
        }

        refreshPolicy.recordAttempt(fetchedAt: fallback?.forecast.metadata.fetchedAt, at: now())

        let liveForecast: NormalizedForecast
        let weatherStartedAt = now()
        diagnostics.record(
            category: .weather,
            outcome: .started,
            title: "Weather request",
            detail: "\(trigger.diagnosticText) requested live weather. Timeout: \(RecommendationDiagnosticText.durationText(loader.weatherRequestTimeout.timeInterval))."
        )
        do {
            liveForecast = try await loader.fetchLiveForecast(for: location.identity)
        } catch WeatherProviderError.cancelled {
            recordWeatherFailure("Request cancelled", startedAt: weatherStartedAt)
            finishWeatherFailure(
                fallback: fallback,
                otherwise: .idle,
                whenExpired: .idle,
                trigger: trigger
            )
            return
        } catch {
            recordWeatherFailure(RecommendationDiagnosticText.weatherErrorText(error), startedAt: weatherStartedAt)
            finishWeatherFailure(
                fallback: fallback,
                otherwise: .weatherUnavailable,
                whenExpired: cache.isExpired ? .weatherDataExpired : .weatherUnavailable,
                trigger: trigger
            )
            return
        }

        let weatherDuration = max(0, now().timeIntervalSince(weatherStartedAt))
        latestForecast = liveForecast
        latestWeatherTrigger = "Live refresh after location resolution"
        latestWeatherOutcome = "Success"
        latestWeatherCacheStatus = "Live response; saved after successful evaluation"
        latestWeatherDuration = weatherDuration
        refreshPolicy.recordWeatherSuccess()
        diagnostics.updateWeather(
            liveForecast,
            provider: loader.weatherProviderName,
            trigger: latestWeatherTrigger,
            outcome: latestWeatherOutcome,
            durationSeconds: weatherDuration,
            cacheStatus: latestWeatherCacheStatus
        )
        diagnostics.record(
            category: .weather,
            outcome: .success,
            title: "Weather request",
            detail: "Received \(liveForecast.hours.count) normalized hourly records from \(loader.weatherProviderName).",
            durationSeconds: weatherDuration
        )

        guard let presentation = makePresentation(
            from: liveForecast,
            at: now(),
            isUsingSavedWeather: false,
            isRefreshing: false,
            refreshFailed: false
        ) else {
            finishWeatherFailure(
                fallback: fallback,
                otherwise: .forecastIncomplete,
                whenExpired: .forecastIncomplete,
                trigger: trigger
            )
            return
        }

        if shouldRetainFallback(insteadOf: presentation, fallback: fallback, at: now()) {
            diagnostics.record(
                category: .evaluation, outcome: .failed, title: "Selected-item forecast unavailable",
                detail: "The live response cannot advise on any selected item; retaining still-usable saved advice."
            )
            finishWeatherFailure(
                fallback: fallback, otherwise: .forecastIncomplete, whenExpired: .forecastIncomplete, trigger: trigger
            )
            return
        }

        await loader.saveAcceptedForecast(liveForecast)
        diagnostics.record(
            category: .cache,
            outcome: .success,
            title: "Weather cache save",
            detail: "Saved the valid normalized forecast after evaluation."
        )
        finishSuccessfulLoad(presentation, forecast: liveForecast)
    }

    private func showLoadingPresentation() {
        if let current = state.result,
           refreshPolicy.isWeatherUsable(fetchedAt: current.weatherFetchedAt, at: now()) {
            state = .result(DailyRecommendationPresentation(
                periods: current.periods, hours: current.hours, weatherFetchedAt: current.weatherFetchedAt,
                isUsingSavedWeather: true, isRefreshing: true, refreshFailed: false,
                refreshAvailableAt: current.refreshAvailableAt, dayParts: current.dayParts,
                displayHours: current.displayHours, itemResults: current.itemResults,
                itemPlanningResults: current.itemPlanningResults, evaluationHour: current.evaluationHour
            ))
        } else {
            state = .loading
        }
    }

    private func finishSuccessfulLoad(_ presentation: DailyRecommendationPresentation, forecast: NormalizedForecast) {
        guard refreshPolicy.isWeatherUsable(fetchedAt: forecast.metadata.fetchedAt, at: now()) else {
            state = .weatherDataExpired
            return
        }
        if presentation.itemResults.map(\.item) == selectedItems {
            state = .result(presentation)
        } else if let updated = makePresentation(
            from: forecast, at: now(), isUsingSavedWeather: false, isRefreshing: false, refreshFailed: false
        ) {
            state = .result(updated)
        } else {
            state = .forecastIncomplete
        }
    }

    private func shouldRetainFallback(
        insteadOf presentation: DailyRecommendationPresentation, fallback: CachedWeather?, at date: Date
    ) -> Bool {
        guard presentation.itemResults.allSatisfy({ $0.evaluation == nil }),
              let fallback,
              refreshPolicy.isWeatherUsable(fetchedAt: fallback.forecast.metadata.fetchedAt, at: date) else { return false }
        return itemEngine.evaluate(fallback.forecast, for: selectedItems, now: date).contains { $0.evaluation != nil }
    }

    func refreshDebugSetting() {
        let wasEnabled = diagnostics.isEnabled
        diagnostics.refreshSetting()
        guard !wasEnabled, diagnostics.isEnabled else { return }

        if let latestLocation {
            diagnostics.updateLocation(
                latestLocation,
                source: latestLocationSource,
                ageSeconds: max(0, now().timeIntervalSince(latestLocation.timestamp)),
                cacheStatus: latestLocationCacheStatus
            )
        }
        if let latestForecast {
            diagnostics.updateWeather(
                latestForecast,
                provider: loader.weatherProviderName,
                trigger: latestWeatherTrigger,
                outcome: latestWeatherOutcome,
                durationSeconds: latestWeatherDuration,
                cacheStatus: latestWeatherCacheStatus
            )
            _ = makePresentation(
                from: latestForecast,
                at: now(),
                isUsingSavedWeather: state.result?.isUsingSavedWeather ?? false,
                isRefreshing: state.result?.isRefreshing ?? false,
                refreshFailed: state.result?.refreshFailed ?? false
            )
        }
    }

    private func loadLocation(trigger: LoadTrigger) async -> LocationReading? {
        let requestReason: String
        let cacheStatus: String
        switch await loader.locationSource(reacquire: trigger == .manual, at: now()) {
        case .device(cacheRejection: nil):
            requestReason = "Pull-to-refresh requires a new device fix instead of saved location."
            cacheStatus = "Saved location bypassed for pull-to-refresh"
        case .cached(let cachedLocation, let age):
            latestLocation = cachedLocation
            latestLocationSource = "Location cache"
            latestLocationCacheStatus = "Reused: fresh and sufficiently accurate"
            resolveLocality(for: cachedLocation.identity)
            diagnostics.updateLocation(
                cachedLocation,
                source: latestLocationSource,
                ageSeconds: age,
                cacheStatus: latestLocationCacheStatus
            )
            diagnostics.record(
                category: .cache,
                outcome: .reused,
                title: "Location cache",
                detail: "Reused a \(RecommendationDiagnosticText.durationText(age))-old reading with \(RecommendationDiagnosticText.accuracyText(cachedLocation.accuracyMeters))."
            )
            return cachedLocation
        case .device(cacheRejection: .some(let reason)):
            requestReason = "Requested because the cache was not reusable: \(RecommendationDiagnosticText.locationCacheReason(reason))"
            cacheStatus = RecommendationDiagnosticText.shortLocationCacheReason(reason)
            diagnostics.record(
                category: .cache,
                outcome: .rejected,
                title: "Location cache",
                detail: RecommendationDiagnosticText.locationCacheReason(reason)
            )
        }

        let startedAt = now()
        diagnostics.record(
            category: .location,
            outcome: .started,
            title: "Location request",
            detail: requestReason
        )
        do {
            let location = try await loader.acquireLocation()
            let duration = max(0, now().timeIntervalSince(startedAt))
            latestLocation = location
            latestLocationSource = "Live device location"
            latestLocationCacheStatus = "New reading • \(cacheStatus)"
            resolveLocality(for: location.identity)
            diagnostics.updateLocation(
                location,
                source: latestLocationSource,
                ageSeconds: max(0, now().timeIntervalSince(location.timestamp)),
                cacheStatus: latestLocationCacheStatus
            )
            diagnostics.record(
                category: .location,
                outcome: .success,
                title: "Location request",
                detail: "Accepted and cached a reading with \(RecommendationDiagnosticText.accuracyText(location.accuracyMeters)).",
                durationSeconds: duration
            )
            return location
        } catch LocationProviderError.permissionDenied {
            recordLocationFailure("Permission denied", startedAt: startedAt)
            finishLocationFailure(.locationPermissionDenied, trigger: trigger)
            return nil
        } catch LocationProviderError.cancelled {
            recordLocationFailure("Request cancelled", startedAt: startedAt)
            finishLocationFailure(.idle, trigger: trigger)
            return nil
        } catch {
            recordLocationFailure("\(error)", startedAt: startedAt)
            finishLocationFailure(.locationUnavailable, trigger: trigger)
            return nil
        }
    }

    private struct CachedWeather {
        let forecast: NormalizedForecast
        let age: TimeInterval
    }

    private enum CachedWeatherLookup {
        case usable(CachedWeather)
        case expired
        case unavailable

        var isExpired: Bool {
            if case .expired = self { return true }
            return false
        }
    }

    private func discardMismatchedForecast(for location: LocationIdentity) {
        guard let forecast = latestForecast,
              !loader.matchesForecastLocation(forecast, location: location) else { return }
        latestForecast = nil
        state = .loading
        diagnostics.clearEvaluation()
    }

    private func cachedWeather(for location: LocationIdentity) async -> CachedWeatherLookup {
        let currentTime = now()
        switch await loader.cachedWeather(for: location, at: currentTime) {
        case .valid(let forecast, let age, let distance):
            latestForecast = forecast
            latestWeatherTrigger = "Cache policy"
            latestWeatherOutcome = "Usable saved forecast"
            latestWeatherCacheStatus = "\(RecommendationDiagnosticText.ageText(age)) old; location separation \(RecommendationDiagnosticText.distanceText(distance))"
            latestWeatherDuration = nil
            diagnostics.updateWeather(
                forecast,
                provider: loader.weatherProviderName,
                trigger: latestWeatherTrigger,
                outcome: latestWeatherOutcome,
                durationSeconds: nil,
                cacheStatus: latestWeatherCacheStatus
            )
            return .usable(CachedWeather(forecast: forecast, age: age))
        case .expired(_, let age, let distance):
            diagnostics.record(
                category: .cache,
                outcome: .rejected,
                title: "Weather cache",
                detail: "Rejected at \(RecommendationDiagnosticText.ageText(age)) old because the \(RecommendationDiagnosticText.ageText(refreshPolicy.maximumWeatherAge)) usable limit was exceeded; location separation \(RecommendationDiagnosticText.distanceText(distance))."
            )
            return .expired
        case .unavailable(let reason):
            diagnostics.record(
                category: .cache,
                outcome: .rejected,
                title: "Weather cache",
                detail: RecommendationDiagnosticText.weatherCacheReason(reason)
            )
            return .unavailable
        }
    }

    private func finishWeatherFailure(
        fallback: CachedWeather?,
        otherwise fallbackState: State,
        whenExpired expiredState: State,
        trigger: LoadTrigger
    ) {
        let currentTime = now()
        if let fallback {
            let age = max(0, currentTime.timeIntervalSince(fallback.forecast.metadata.fetchedAt))
            guard refreshPolicy.isWeatherUsable(fetchedAt: fallback.forecast.metadata.fetchedAt, at: currentTime) else {
                diagnostics.record(
                    category: .cache,
                    outcome: .rejected,
                    title: "Weather fallback",
                    detail: "The saved forecast crossed the \(RecommendationDiagnosticText.ageText(refreshPolicy.maximumWeatherAge)) limit while the request was running."
                )
                applyRetryCooldownIfNeeded(for: trigger)
                state = expiredState
                return
            }

            refreshPolicy.recordRefreshFailure(at: currentTime)
            latestForecast = fallback.forecast
            latestWeatherTrigger = "Fallback after live request failure"
            latestWeatherOutcome = "Reused cached forecast"
            latestWeatherCacheStatus = "Refresh failed; using \(RecommendationDiagnosticText.ageText(age))-old saved weather"
            latestWeatherDuration = nil
            diagnostics.updateWeather(
                fallback.forecast,
                provider: loader.weatherProviderName,
                trigger: latestWeatherTrigger,
                outcome: latestWeatherOutcome,
                durationSeconds: nil,
                cacheStatus: latestWeatherCacheStatus
            )
            diagnostics.record(
                category: .cache,
                outcome: .reused,
                title: "Weather fallback",
                detail: "Refresh failed; retained the \(RecommendationDiagnosticText.ageText(age))-old saved forecast. Manual refresh is available again in \(RecommendationDiagnosticText.countdownText(refreshPolicy.failureCooldown))."
            )
            guard let cached = makePresentation(
                from: fallback.forecast,
                at: currentTime,
                isUsingSavedWeather: true,
                isRefreshing: false,
                refreshFailed: true
            ) else {
                state = fallbackState
                return
            }
            state = .result(cached)
            return
        }

        applyRetryCooldownIfNeeded(for: trigger)
        state = expiredState
    }

    private func makePresentation(
        from forecast: NormalizedForecast,
        at currentTime: Date,
        isUsingSavedWeather: Bool,
        isRefreshing: Bool,
        refreshFailed: Bool
    ) -> DailyRecommendationPresentation? {
        guard let output = presentationBuilder.build(
            from: forecast,
            for: selectedItems,
            at: currentTime,
            isUsingSavedWeather: isUsingSavedWeather,
            isRefreshing: isRefreshing,
            refreshFailed: refreshFailed,
            refreshAvailableAt: refreshPolicy.refreshAvailableAt(fetchedAt: forecast.metadata.fetchedAt)
        ) else {
            diagnostics.record(
                category: .evaluation,
                outcome: .failed,
                title: "Forecast evaluation",
                detail: "Timezone or remaining-day coverage requirements were not met."
            )
            return nil
        }
        if let evaluation = output.jacketEvaluation {
            diagnostics.updateEvaluation(forecast: forecast, evaluation: evaluation, periods: output.jacketPeriods)
        } else {
            diagnostics.clearEvaluation()
        }
        let itemResults = output.presentation.itemResults
        diagnostics.record(
            category: .evaluation,
            outcome: .success,
            title: "Recommendation periods",
            detail: "Evaluated \(output.remainingHourCount) remaining hours; \(itemResults.filter { $0.evaluation != nil }.count) of \(itemResults.count) selected items have daily advice. Jacket diagnostics retain their own protective policy."
        )
        return output.presentation
    }

    private func automaticRefreshIfNeeded() async {
        guard let forecast = latestForecast else { return }
        let currentTime = now()
        if refreshPolicy.isWeatherUsable(fetchedAt: forecast.metadata.fetchedAt, at: currentTime), let current = state.result,
           let window = ForecastEvaluationWindow(forecast: forecast, now: currentTime),
           current.evaluationHour != window.interval.start,
           let updated = makePresentation(
                from: forecast, at: currentTime, isUsingSavedWeather: current.isUsingSavedWeather,
                isRefreshing: current.isRefreshing, refreshFailed: current.refreshFailed
           ) {
            state = .result(updated)
        }
        guard !isRequestInFlight else { return }
        switch refreshPolicy.automaticAction(fetchedAt: forecast.metadata.fetchedAt, at: currentTime) {
        case .wait:
            return
        case .refresh:
            await performLoad(trigger: .automatic, forceLiveWeather: true)
        case .expire:
            diagnostics.record(
                category: .cache,
                outcome: .rejected,
                title: "Weather recommendation expired",
                detail: "The displayed saved forecast crossed the \(RecommendationDiagnosticText.ageText(refreshPolicy.maximumWeatherAge)) usable limit."
            )
            state = .weatherDataExpired
        }
    }

    private func finishLocationFailure(_ failureState: State, trigger: LoadTrigger) {
        guard let forecast = latestForecast,
              refreshPolicy.isWeatherUsable(fetchedAt: forecast.metadata.fetchedAt, at: now()),
              let current = state.result
        else {
            applyRetryCooldownIfNeeded(for: trigger)
            state = failureState
            return
        }

        refreshPolicy.recordRefreshFailure(at: now())
        state = .result(DailyRecommendationPresentation(
            periods: current.periods,
            hours: current.hours,
            weatherFetchedAt: current.weatherFetchedAt,
            isUsingSavedWeather: true,
            isRefreshing: false,
            refreshFailed: true,
            refreshAvailableAt: refreshPolicy.failureCooldownUntil ?? current.refreshAvailableAt,
            dayParts: current.dayParts,
            displayHours: current.displayHours,
            itemResults: current.itemResults,
            itemPlanningResults: current.itemPlanningResults,
            evaluationHour: current.evaluationHour
        ))
    }

    private func applyRetryCooldownIfNeeded(for trigger: LoadTrigger) {
        guard trigger == .retry || trigger == .manual else { return }
        refreshPolicy.recordRetryFailure(at: now())
        diagnostics.record(
            category: .session,
            outcome: .rejected,
            title: "Retry cooldown",
            detail: "Another retry is available in \(RecommendationDiagnosticText.countdownText(refreshPolicy.failureCooldown))."
        )
    }

    private func recordRefreshBlocked(title: String, detail: String) {
        diagnostics.record(
            category: .weather,
            outcome: .rejected,
            title: title,
            detail: detail
        )
    }

    private func resolveLocality(for location: LocationIdentity) {
        guard localityLocation != location else { return }
        localityLocation = location
        locality = "Finding locality…"
        Task { [weak self, localityResolver] in
            let resolved = await localityResolver.locality(for: location)
            guard let self, self.localityLocation == location else { return }
            self.locality = resolved ?? "Locality unavailable"
        }
    }

    private func recordLocationFailure(_ detail: String, startedAt: Date) {
        diagnostics.record(
            category: .error,
            outcome: .failed,
            title: "Location request",
            detail: detail,
            durationSeconds: max(0, now().timeIntervalSince(startedAt))
        )
    }

    private func recordWeatherFailure(_ detail: String, startedAt: Date) {
        diagnostics.record(
            category: .error,
            outcome: .failed,
            title: "Weather request",
            detail: detail,
            durationSeconds: max(0, now().timeIntervalSince(startedAt))
        )
    }
}

nonisolated private extension Duration {
    var timeInterval: TimeInterval {
        let components = self.components
        return TimeInterval(components.seconds)
            + TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000
    }
}

@MainActor
private extension RecommendationViewModel.State {
    var result: DailyRecommendationPresentation? {
        guard case .result(let result) = self else { return nil }
        return result
    }
}
