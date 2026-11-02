import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: RecommendationViewModel
    @State private var isShowingDiagnostics = false
    @State private var guidedHomeEnabled: Bool
    @State private var showHomeIntroduction: Bool
    @State private var selection: ItemSelectionStore
    @State private var isShowingItemSelection = false
    @State private var detailItem: PredefinedItem?
    private let homePresentationModeOverride: HomePresentationMode?

    init() {
        let preferences = AppConfiguration.currentHomePresentationPreferences()
        homePresentationModeOverride = nil
        _guidedHomeEnabled = State(initialValue: preferences.guidedHomeEnabled)
        _showHomeIntroduction = State(initialValue: preferences.showHomeIntroduction)
        _model = State(initialValue: RecommendationViewModel())
        _selection = State(initialValue: ItemSelectionStore())
    }

    init(
        model: RecommendationViewModel,
        homePresentationModeOverride: HomePresentationMode? = nil,
        selection: ItemSelectionStore? = nil
    ) {
        let preferences = AppConfiguration.currentHomePresentationPreferences()
        self.homePresentationModeOverride = homePresentationModeOverride
        _guidedHomeEnabled = State(initialValue: preferences.guidedHomeEnabled)
        _showHomeIntroduction = State(initialValue: preferences.showHomeIntroduction)
        _model = State(initialValue: model)
        _selection = State(initialValue: selection ?? ItemSelectionStore())
    }

    private var homePresentationMode: HomePresentationMode {
        if let homePresentationModeOverride {
            return homePresentationModeOverride
        }
        return guidedHomeEnabled || showHomeIntroduction ? .guided : .compact
    }

    var body: some View {
        Group {
            if selection.isCompleted {
                home
            } else {
                ItemSelectionView(selected: selection.selectedItems, isEditing: false) { items in
                    selection.save(items)
                    model.updateSelectedItems(selection.selectedItems)
                }
            }
        }
        .task(id: selection.isCompleted && scenePhase == .active) {
            guard scenePhase == .active else { return }
            refreshHomePresentationPreference()
            selection.refreshFromSettings()
            if !selection.isCompleted {
                isShowingItemSelection = false
                detailItem = nil
                isShowingDiagnostics = false
            }
            guard selection.isCompleted else { return }
            model.updateSelectedItems(selection.selectedItems)
            await model.appBecameActive()
        }
        .sheet(isPresented: $isShowingItemSelection) {
            ItemSelectionView(selected: selection.selectedItems, isEditing: true) { items in
                selection.save(items)
                model.updateSelectedItems(selection.selectedItems)
                isShowingItemSelection = false
            } onCancel: {
                isShowingItemSelection = false
            }
        }
        .sheet(item: $detailItem) { item in
            NavigationStack {
                ScrollView {
                    if case .result(let presentation) = model.state {
                        itemDetail(itemPresentation(item, from: presentation), legacy: presentation)
                            .padding(16)
                    } else {
                        content.padding(16)
                    }
                }
                .background(HomeStyle.background)
                .navigationTitle(item.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { detailItem = nil } }
                }
                .accessibilityIdentifier("item-detail")
            }
        }
    }

    private var home: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    content
                    footer
                }
                .padding(.horizontal, 16)
                .padding(.top, selection.selectedItems.count > 1 ? 12 : 24)
                .padding(.bottom, 16)
                .frame(maxWidth: 640, minHeight: geometry.size.height, alignment: .topLeading)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.always, axes: .vertical)
            .scrollIndicators(.hidden)
            .refreshable {
                await model.manualRefresh()
            }
            .accessibilityAction(named: "Refresh weather") {
                Task { await model.manualRefresh() }
            }
        }
        .background(HomeStyle.background)
        .onChange(of: model.diagnostics.isEnabled) { _, enabled in
            if !enabled { isShowingDiagnostics = false }
        }
        .sheet(isPresented: $isShowingDiagnostics) {
            DiagnosticsView(diagnostics: model.diagnostics)
        }
    }

    private func refreshHomePresentationPreference() {
        guard homePresentationModeOverride == nil else { return }
        let preferences = AppConfiguration.currentHomePresentationPreferences()
        guidedHomeEnabled = preferences.guidedHomeEnabled
        showHomeIntroduction = preferences.showHomeIntroduction
    }

    private func dismissHomeIntroduction() {
        let preferences = AppConfiguration.setShowHomeIntroduction(false)
        guidedHomeEnabled = preferences.guidedHomeEnabled
        showHomeIntroduction = preferences.showHomeIntroduction
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            if selection.selectedItems.count > 1, case .result = model.state {
                homeTitle
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        homeTitle.fixedSize()
                        Spacer(minLength: 0)
                        locality.fixedSize()
                    }
                    VStack(alignment: .trailing, spacing: 4) {
                        homeTitle.frame(maxWidth: .infinity, alignment: .leading)
                        locality
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            if homePresentationMode == .guided {
                Text("Today’s weather, interpreted for each item.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("home-purpose")
            }
        }
    }

    private var homeTitle: some View {
        Text("Can I Wear")
            .font(.largeTitle.bold())
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("home-title")
    }

    private var locality: some View {
        HStack(spacing: 4) {
            LocationPinIcon().accessibilityHidden(true)
            Text(model.locality ?? "Current location")
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("weather-locality")
    }

    private var configureItems: some View {
        Button { isShowingItemSelection = true } label: {
            Image(systemName: "gearshape")
                .font(.title2).frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Configure items")
        .accessibilityIdentifier("configure-items")
    }

    private var footer: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                weatherAttribution.fixedSize()
                Spacer(minLength: 0)
                footerControls
            }
            VStack(alignment: .trailing, spacing: 4) {
                weatherAttribution.frame(maxWidth: .infinity)
                footerControls
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var weatherAttribution: some View {
        Link(destination: URL(string: "https://open-meteo.com/")!) {
            Text("Weather provided by Open-Meteo")
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 44)
                .multilineTextAlignment(.center)
                .contentShape(Rectangle())
        }
        .tint(.secondary)
        .accessibilityIdentifier("weather-attribution")
    }

    private var footerControls: some View {
        HStack(spacing: 8) {
            if model.diagnostics.isEnabled {
                Button {
                    isShowingDiagnostics = true
                } label: {
                    Image(systemName: "ladybug")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Diagnostics")
                .accessibilityIdentifier("diagnostics-button")
            }
            configureItems
        }
        .foregroundStyle(.secondary)
        // Keep symbols inside their touch targets; attribution still scales fully.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle, .loading:
            ProgressView("Checking today’s weather…")
                .frame(maxWidth: .infinity, minHeight: 220)
                .accessibilityIdentifier("loading-status")
        case .result(let presentation):
            result(presentation)
        case .locationPermissionDenied:
            failure(
                title: "Location access needed",
                message: "Allow location access in Settings, then try again."
            )
        case .locationUnavailable:
            failure(
                title: "Couldn’t get your location",
                message: "Check Location Services and try again."
            )
        case .weatherUnavailable:
            failure(
                title: "Weather unavailable",
                message: "Check your internet connection and try again."
            )
        case .weatherDataExpired:
            failure(
                title: "Weather unavailable",
                message: "The saved forecast is too old to use. Connect to the internet and try again."
            )
        case .forecastIncomplete:
            failure(
                title: "Today’s forecast is incomplete",
                message: "There isn’t enough reliable weather data for a safe answer."
            )
        }
    }

    private func result(_ presentation: DailyRecommendationPresentation) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if homePresentationMode == .guided && showHomeIntroduction {
                HomeIntroductionCard(
                    onGotIt: dismissHomeIntroduction,
                    explanation: selection.selectedItems.count > 1
                        ? "Each item has today’s advice and relevant times. Open an item for periods and hourly details."
                        : "The main result covers today. Dayparts show when it changes, and the reason explains why."
                )
            }
            if selection.selectedItems.count == 1, let item = selection.selectedItems.first {
                itemDetail(itemPresentation(item, from: presentation), legacy: presentation)
            } else {
                ItemOverviewView(
                    items: selection.selectedItems.map { itemPresentation($0, from: presentation) },
                    dayParts: { itemDayParts($0, from: presentation) },
                    missingPlanningContext: { item in
                        item != .leatherJacket && planningEvaluation(item, from: presentation) == nil
                            && presentation.evaluationHour != nil
                    },
                    locality: { locality },
                    onSelect: { detailItem = $0 }
                )
            }
        }
        .task(id: scenePhase == .active ? presentation.weatherFetchedAt : nil) {
            guard scenePhase == .active else { return }
            await model.monitorAutomaticRefreshes()
        }
    }

    private func itemPresentation(_ item: PredefinedItem, from presentation: DailyRecommendationPresentation) -> ItemHomePresentation {
        ItemHomePresentation(result: presentation.itemResults.first { $0.item == item }
            ?? ItemForecastResult(item: item, evaluation: nil))
    }

    @ViewBuilder
    private func itemDetail(
        _ item: ItemHomePresentation, legacy: DailyRecommendationPresentation
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ItemSummaryView(presentation: item, dayParts: itemDayParts(item.id, from: legacy))
                .padding(16)
                .background(HomeStyle.card, in: RoundedRectangle(cornerRadius: HomeStyle.cardRadius))
                .accessibilityIdentifier("recommendation-hero")
            if let evaluation = item.evaluation {
                if homePresentationMode == .guided {
                    Text(item.id == .leatherJacket ? "When can I wear it?" : "Advice through the day")
                        .font(.title3.bold()).accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("day-parts-heading")
                }
                itemPeriods(item.id, from: legacy)
                Divider().padding(.vertical, 2)
                if item.id == .leatherJacket, !legacy.hours.isEmpty {
                    HourlySuitabilityView(presentation: legacy)
                } else {
                    ItemHourlyAdviceView(evaluation: planningEvaluation(item.id, from: legacy) ?? evaluation, currentTime: legacy.evaluationHour)
                }
            }
        }
    }

    private func planningEvaluation(_ item: PredefinedItem, from presentation: DailyRecommendationPresentation) -> ItemDailyEvaluation? {
        presentation.itemPlanningResults.first { $0.item == item }?.evaluation
    }

    private func itemPeriods(
        _ item: PredefinedItem, from presentation: DailyRecommendationPresentation, isOverview: Bool = false
    ) -> some View {
        let planning = planningEvaluation(item, from: presentation)
        return VStack(alignment: .leading, spacing: 6) {
            DayPartsView(dayParts: itemDayParts(item, from: presentation), isOverview: isOverview)
            if item != .leatherJacket, planning == nil, presentation.evaluationHour != nil {
                Text("Earlier periods unavailable in this forecast.")
                    .font(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("item-planning-unavailable-\(item.rawValue)")
            }
        }
    }

    private func itemDayParts(_ item: PredefinedItem, from presentation: DailyRecommendationPresentation) -> [FixedDayPartPresentation] {
        if item == .leatherJacket { return presentation.dayParts }
        guard let evaluation = planningEvaluation(item, from: presentation)
                ?? presentation.itemResults.first(where: { $0.item == item })?.evaluation else { return [] }
        return FixedDayPartPresentation.make(from: evaluation, at: presentation.evaluationHour ?? evaluation.interval.start)
    }

    private func failure(title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .accessibilityHidden(true)
            Text(title)
                .font(.title2.bold())
                .accessibilityIdentifier("failure-title")
            Text(message)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("failure-message")
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                Button(retryTitle(at: timeline.date)) {
                    Task { await model.retry() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(minHeight: 44)
                .disabled(!model.canRetry(at: timeline.date))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(HomeStyle.card, in: RoundedRectangle(cornerRadius: HomeStyle.cardRadius))
        .multilineTextAlignment(.center)
    }

    private func retryTitle(at date: Date) -> String {
        guard let seconds = model.retryCountdown(at: date) else { return "Try Again" }
        return "Try again in \(seconds) s"
    }
}

private struct LocationPinIcon: View {
    var body: some View {
        ZStack {
            Image(systemName: "drop.fill")
                .rotationEffect(.degrees(180))
            Circle()
                .fill(HomeStyle.background)
                .frame(width: 5, height: 5)
                .offset(y: -3)
        }
        .frame(width: 18, height: 24)
    }
}

#Preview {
    ContentView(model: RecommendationViewModel(
        initialState: .result(DailyRecommendationPresentation(
            periods: [
                PeriodPresentation(
                    interval: DateInterval(start: .now, duration: 3_600),
                    timezoneIdentifier: TimeZone.current.identifier,
                    recommendation: RecommendationPresentation(
                        recommendation: HourlyRecommendation(
                            level: .okay,
                            reason: .suitableTemperature
                        )
                    )
                )
            ],
            hours: [HourlySuitabilityPresentation(
                hour: EvaluatedHour(timestamp: .now, recommendation: HourlyRecommendation(
                    level: .okay, reason: .suitableTemperature
                )),
                timezoneIdentifier: TimeZone.current.identifier
            )],
            weatherFetchedAt: .now,
            isUsingSavedWeather: false,
            isRefreshing: false,
            refreshFailed: false,
            refreshAvailableAt: .now.addingTimeInterval(15 * 60)
        ))
    ))
}
