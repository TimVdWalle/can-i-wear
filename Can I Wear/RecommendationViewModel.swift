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
    private let loadDiagnostics: RecommendationLoadDiagnostics
    private let presentationBuilder: RecommendationPresentationBuilder
    private let itemEngine = MultiItemRecommendationEngine()
    private var refreshPolicy: RefreshPolicy
    private let localityResolver: any LocalityResolving
    private let now: @Sendable () -> Date
    private let automaticRefreshSleep: Sleep
    private let isLifecycleManaged: Bool
    private var latestForecast: NormalizedForecast?
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
        let diagnostics = diagnostics ?? DebugDiagnostics()
        self.diagnostics = diagnostics
        self.loadDiagnostics = RecommendationLoadDiagnostics(
            diagnostics: diagnostics, providerName: weatherProvider.diagnosticName, config: reuseConfig
        )
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
            loadDiagnostics.manualRefreshBlocked()
            return
        }
        let currentTime = now()
        if let cooldown = refreshPolicy.manualRefreshBlockedUntil(at: currentTime) {
            loadDiagnostics.manualRefreshBlocked(remaining: cooldown.timeIntervalSince(currentTime))
            return
        }

        loadDiagnostics.manualRefreshStarted()
        await performLoad(trigger: .manual, forceLiveWeather: false)
    }

    func retry() async {
        guard !isRequestInFlight else {
            loadDiagnostics.retryBlocked()
            return
        }
        let currentTime = now()
        if let retryAvailableAt, retryAvailableAt > currentTime {
            loadDiagnostics.retryBlocked(remaining: retryAvailableAt.timeIntervalSince(currentTime))
            return
        }

        loadDiagnostics.retryRequested()
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
        loadDiagnostics.loadStarted(trigger: trigger.diagnosticText)

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
                loadDiagnostics.weatherRefreshSkipped(cached.forecast, age: cached.age)
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
            loadDiagnostics.cachedWeatherRefreshing(age: cached.age, isManual: trigger == .manual)
        case .expired:
            state = .loading
        case .unavailable:
            if state.result == nil { state = .loading }
        }

        refreshPolicy.recordAttempt(fetchedAt: fallback?.forecast.metadata.fetchedAt, at: now())

        let liveForecast: NormalizedForecast
        let weatherStartedAt = now()
        loadDiagnostics.weatherRequestStarted(trigger: trigger.diagnosticText)
        do {
            liveForecast = try await loader.fetchLiveForecast(for: location.identity)
        } catch WeatherProviderError.cancelled {
            loadDiagnostics.weatherFailed("Request cancelled", duration: max(0, now().timeIntervalSince(weatherStartedAt)))
            finishWeatherFailure(
                fallback: fallback,
                otherwise: .idle,
                whenExpired: .idle,
                trigger: trigger
            )
            return
        } catch {
            loadDiagnostics.weatherFailed(
                RecommendationDiagnosticText.weatherErrorText(error), duration: max(0, now().timeIntervalSince(weatherStartedAt))
            )
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
        refreshPolicy.recordWeatherSuccess()
        loadDiagnostics.liveWeatherReceived(liveForecast, duration: weatherDuration)

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
            loadDiagnostics.selectedItemForecastUnavailable()
            finishWeatherFailure(
                fallback: fallback, otherwise: .forecastIncomplete, whenExpired: .forecastIncomplete, trigger: trigger
            )
            return
        }

        await loader.saveAcceptedForecast(liveForecast)
        loadDiagnostics.weatherSaved()
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
        guard loadDiagnostics.refreshSetting(forecast: latestForecast, at: now()) else { return }
        if let latestForecast {
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
        let cacheRejection: LocationCacheRejectionReason?
        switch await loader.locationSource(reacquire: trigger == .manual, at: now()) {
        case .device(let reason):
            cacheRejection = reason
            if let reason { loadDiagnostics.locationCacheRejected(reason) }
        case .cached(let cachedLocation, let age):
            resolveLocality(for: cachedLocation.identity)
            loadDiagnostics.reusedLocation(cachedLocation, age: age)
            return cachedLocation
        }

        let startedAt = now()
        loadDiagnostics.locationRequestStarted(cacheRejection: cacheRejection)
        do {
            let location = try await loader.acquireLocation()
            let duration = max(0, now().timeIntervalSince(startedAt))
            resolveLocality(for: location.identity)
            loadDiagnostics.acquiredLocation(location, cacheRejection: cacheRejection, at: now(), duration: duration)
            return location
        } catch LocationProviderError.permissionDenied {
            loadDiagnostics.locationFailed("Permission denied", duration: max(0, now().timeIntervalSince(startedAt)))
            finishLocationFailure(.locationPermissionDenied, trigger: trigger)
            return nil
        } catch LocationProviderError.cancelled {
            loadDiagnostics.locationFailed("Request cancelled", duration: max(0, now().timeIntervalSince(startedAt)))
            finishLocationFailure(.idle, trigger: trigger)
            return nil
        } catch {
            loadDiagnostics.locationFailed("\(error)", duration: max(0, now().timeIntervalSince(startedAt)))
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
        loadDiagnostics.clearEvaluation()
    }

    private func cachedWeather(for location: LocationIdentity) async -> CachedWeatherLookup {
        let currentTime = now()
        switch await loader.cachedWeather(for: location, at: currentTime) {
        case .valid(let forecast, let age, let distance):
            latestForecast = forecast
            loadDiagnostics.cachedWeatherFound(forecast, age: age, distance: distance)
            return .usable(CachedWeather(forecast: forecast, age: age))
        case .expired(_, let age, let distance):
            loadDiagnostics.weatherCacheExpired(age: age, distance: distance)
            return .expired
        case .unavailable(let reason):
            loadDiagnostics.weatherCacheUnavailable(reason)
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
                loadDiagnostics.fallbackExpired()
                applyRetryCooldownIfNeeded(for: trigger)
                state = expiredState
                return
            }

            refreshPolicy.recordRefreshFailure(at: currentTime)
            latestForecast = fallback.forecast
            loadDiagnostics.reusedFallback(fallback.forecast, age: age)
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
            loadDiagnostics.evaluationFailed()
            return nil
        }
        loadDiagnostics.evaluated(output, forecast: forecast)
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
            loadDiagnostics.weatherExpired()
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
        loadDiagnostics.retryCooldown()
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
}

@MainActor
private extension RecommendationViewModel.State {
    var result: DailyRecommendationPresentation? {
        guard case .result(let result) = self else { return nil }
        return result
    }
}
