import SwiftUI
import UIKit

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
        #if DEBUG
        // Development installs expose the local diagnostics shortcut by default.
        // The release build remains controlled by the opt-in Settings switch.
        UserDefaults.standard.set(true, forKey: DebugSettings.enabledKey)
        #endif
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
                        itemDetail(itemPresentation(item, from: presentation), legacy: presentation, isDetail: true)
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
                .padding(.top, 24)
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
            HStack(alignment: .firstTextBaseline) {
                Text("Can I Wear")
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Button { isShowingItemSelection = true } label: {
                    Image(systemName: "gearshape").font(.title2).frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Configure items")
                .accessibilityIdentifier("configure-items")
            }
            if homePresentationMode == .guided {
                Text("Today’s weather, interpreted for each item.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("home-purpose")
            }
            HStack(spacing: 8) {
                LocationPinIcon()
                    .accessibilityHidden(true)
                Text(model.locality ?? "Current location")
            }
                .font(.headline)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("weather-locality")
        }
    }

    private var footer: some View {
        ZStack {
            Link(destination: URL(string: "https://open-meteo.com/")!) {
                Text("Weather provided by Open-Meteo")
                    .font(.footnote)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .multilineTextAlignment(.center)
                    .contentShape(Rectangle())
            }
            .tint(.secondary)

            if model.diagnostics.isEnabled {
                HStack {
                    Spacer()
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
            }
        }
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
                Text("Your items today").font(.title3.bold()).accessibilityAddTraits(.isHeader)
                ForEach(selection.selectedItems, id: \.self) { item in
                    let itemPresentation = itemPresentation(item, from: presentation)
                    Button { detailItem = item } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            ItemSummaryView(
                                presentation: itemPresentation, isOverview: true,
                                qualifier: itemPresentation.heroQualifier(dayParts: itemDayParts(item, from: presentation))
                            )
                            if itemPresentation.evaluation != nil {
                                itemPeriods(itemPresentation.id, from: presentation, isOverview: true)
                            }
                        }
                        .padding(12)
                        .background(HomeStyle.card, in: RoundedRectangle(cornerRadius: HomeStyle.cardRadius))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(itemPresentation.overviewAccessibilityLabel(
                            dayParts: itemDayParts(item, from: presentation)
                        ))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("View periods and hourly details")
                    .accessibilityIdentifier("item-card-\(item.rawValue)")
                }
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
        _ item: ItemHomePresentation, legacy: DailyRecommendationPresentation, isDetail: Bool = false
    ) -> some View {
        let qualifier = item.heroQualifier(dayParts: isDetail ? [] : legacy.dayParts)
        VStack(alignment: .leading, spacing: 14) {
            ItemSummaryView(presentation: item, qualifier: qualifier)
                .padding(16)
                .background(HomeStyle.card, in: RoundedRectangle(cornerRadius: HomeStyle.cardRadius))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(item.heroAccessibilityLabel(qualifier: qualifier))
                .accessibilityIdentifier("recommendation-hero")
            if let evaluation = item.evaluation {
                if homePresentationMode == .guided {
                    Text(item.id == .leatherJacket ? "When can I wear it?" : "Advice through the day")
                        .font(.title3.bold()).accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("day-parts-heading")
                }
                if item.id == .leatherJacket, !legacy.hours.isEmpty {
                    if isDetail {
                        itemPeriods(item.id, from: legacy)
                    } else {
                        DayPartsView(dayParts: legacy.dayParts)
                    }
                    Divider().padding(.vertical, 2)
                    HourlySuitabilityView(presentation: legacy)
                } else {
                    itemPeriods(item.id, from: legacy)
                    Divider().padding(.vertical, 2)
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

private struct DiagnosticsView: View {
    @Environment(\.dismiss) private var dismiss
    let diagnostics: DebugDiagnostics
    @State private var didCopy = false

    var body: some View {
        NavigationStack {
            List {
                Section("Place used for weather") {
                    Text(diagnostics.place)
                        .accessibilityIdentifier("diagnostics-place")
                }

                Section("Location") {
                    if let summary = diagnostics.locationSummary {
                        LabeledContent("Source", value: summary.source)
                        LabeledContent("Reading", value: timestamp(summary.readingTime))
                        LabeledContent(
                            "Age",
                            value: age(max(
                                summary.ageSeconds,
                                Date().timeIntervalSince(summary.readingTime)
                            ))
                        )
                        LabeledContent("Accuracy", value: measurement(summary.accuracyMeters, unit: "m"))
                        Text(summary.cacheStatus)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No location diagnostics yet.")
                    }
                }

                Section("Weather") {
                    if let summary = diagnostics.weatherSummary {
                        LabeledContent("Provider", value: summary.provider)
                        LabeledContent("Trigger", value: summary.trigger)
                        LabeledContent("Outcome", value: summary.outcome)
                        LabeledContent("Fetched", value: timestamp(summary.fetchedAt))
                        LabeledContent(
                            "Age",
                            value: age(max(
                                summary.ageSeconds,
                                Date().timeIntervalSince(summary.fetchedAt)
                            ))
                        )
                        LabeledContent("Duration", value: summary.durationSeconds.map(duration) ?? "Unavailable")
                        LabeledContent("Timezone", value: summary.timezoneIdentifier)
                        LabeledContent("Hours received", value: "\(summary.hourCount)")
                        Text(summary.cacheStatus)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No weather diagnostics yet.")
                    }
                }

                Section("Leather Jacket · final periods") {
                    if diagnostics.periodDetails.isEmpty {
                        Text("No periods yet.")
                    } else {
                        ForEach(diagnostics.periodDetails) { period in
                            periodRow(period)
                        }
                    }
                }

                Section("Leather Jacket · remaining hourly inputs") {
                    if diagnostics.hourlyDetails.isEmpty {
                        Text("No evaluated hours yet.")
                    } else {
                        ForEach(diagnostics.hourlyDetails) { hour in
                            hourlyRow(hour)
                        }
                    }
                }

                Section {
                    if diagnostics.events.isEmpty {
                        Text("No events yet.")
                    } else {
                        ForEach(diagnostics.events.reversed()) { event in
                            eventRow(event)
                        }
                    }
                } header: {
                    Text("Activity history (\(diagnostics.events.count)/\(AppConfiguration.maximumDiagnosticEvents))")
                } footer: {
                    Text("Newest first. This shows what the app checked, why it fetched or reused data, and whether each step succeeded. Turning debug off clears this history.")
                }

                Section {
                    Button {
                        UIPasteboard.general.string = diagnostics.readableReport
                        didCopy = true
                    } label: {
                        Label(didCopy ? "Report Copied" : "Copy Report", systemImage: "doc.on.doc")
                    }
                    .accessibilityIdentifier("copy-diagnostics-report")
                } footer: {
                    Text("The report stays local unless you choose to paste or share it. It contains the place shown above, but not exact coordinates.")
                }
            }
            .navigationTitle("Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("diagnostics-sheet")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func duration(_ seconds: TimeInterval) -> String {
        "\(max(0, seconds).formatted(.number.precision(.fractionLength(0...2)))) s"
    }

    private func age(_ seconds: TimeInterval) -> String {
        let seconds = max(0, seconds)
        guard seconds >= 60 else { return "\(Int(seconds.rounded(.down))) s" }
        let minutes = Int((seconds / 60).rounded(.down))
        return minutes == 1 ? "1 min" : "\(minutes) min"
    }

    private func measurement(_ value: Double?, unit: String) -> String {
        guard let value, value.isFinite else { return "Unavailable" }
        return "\(value.formatted(.number.precision(.fractionLength(0...1)))) \(unit)"
    }

    private func percentage(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "Unavailable" }
        return value.formatted(.percent.precision(.fractionLength(0)))
    }

    private func timestamp(_ date: Date, timezoneIdentifier: String? = nil) -> String {
        let timezone = timezoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        let formatter = DateFormatter()
        formatter.timeZone = timezone
        formatter.dateFormat = calendar.isDate(date, inSameDayAs: Date())
            ? "HH:mm:ss"
            : "EEE d MMM, HH:mm:ss"
        return formatter.string(from: date)
    }

    private func timeRange(_ period: DiagnosticPeriodDetail) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: period.timezoneIdentifier)
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: period.interval.start)) → \(formatter.string(from: period.interval.end))"
    }

    private func periodRow(_ period: DiagnosticPeriodDetail) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(timeRange(period))
                    .font(.headline.monospacedDigit())
                Spacer()
                Text(levelText(period.level))
                    .font(.subheadline.bold())
                    .foregroundStyle(levelColor(period.level))
            }
            Text(reasonText(period.reason))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }

    private func hourlyRow(_ hour: DiagnosticHourlyDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(timestamp(hour.timestamp, timezoneIdentifier: hour.timezoneIdentifier))
                    .font(.headline.monospacedDigit())
                Spacer()
                Text(levelText(hour.level))
                    .font(.subheadline.bold())
                    .foregroundStyle(levelColor(hour.level))
            }

            Text(reasonText(hour.reason))
                .font(.footnote)
                .foregroundStyle(.secondary)

            diagnosticGroup("Temperature") {
                diagnosticValue("Actual", measurement(hour.actualTemperatureCelsius, unit: "°C"))
                diagnosticValue("Feels like", measurement(hour.apparentTemperatureCelsius, unit: "°C"))
                diagnosticValue(
                    "Used by rules",
                    measurement(hour.selectedTemperatureCelsius, unit: "°C"),
                    severity: hour.selectedTemperatureSeverity
                )
            }

            diagnosticGroup("Moisture") {
                diagnosticValue(
                    "Amount",
                    measurement(hour.precipitationAmountMillimeters, unit: "mm"),
                    severity: hour.precipitationAmountSeverity
                )
                diagnosticValue(
                    "Chance",
                    percentage(hour.precipitationChanceFraction),
                    severity: hour.precipitationChanceSeverity
                )
                diagnosticValue(
                    "Type",
                    precipitationText(hour.precipitationType),
                    severity: hour.precipitationTypeSeverity
                )
                diagnosticValue(
                    "Fog or mist",
                    fogText(hour.fogOrMistCondition),
                    severity: hour.fogOrMistSeverity
                )
            }

            diagnosticGroup("Wind · informational for Leather Jacket") {
                diagnosticValue("Speed", measurement(hour.windSpeedKilometersPerHour, unit: "km/h"))
                diagnosticValue("Gust", measurement(hour.windGustKilometersPerHour, unit: "km/h"))
            }
        }
        .padding(.vertical, 6)
    }

    private func eventRow(_ event: DiagnosticEvent) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Label(eventCategoryText(event.category), systemImage: eventCategorySymbol(event.category))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(timestamp(event.timestamp))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline) {
                Text(event.title)
                    .font(.headline)
                Spacer()
                Text(eventOutcomeText(event.outcome))
                    .font(.caption.bold())
                    .foregroundStyle(eventOutcomeColor(event.outcome))
            }
            Text(event.detail)
                .font(.footnote)
            if let seconds = event.durationSeconds {
                LabeledContent("Duration", value: duration(seconds))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }

    private func diagnosticGroup<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func diagnosticValue(
        _ label: String,
        _ value: String,
        severity: DiagnosticSeverity = .neutral
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(severity == .neutral ? .regular : .semibold)
                .foregroundStyle(severityColor(severity))
                .multilineTextAlignment(.trailing)
        }
        .font(.footnote)
    }

    private func levelText(_ level: RecommendationLevel) -> String {
        switch level {
        case .okay: "OK"
        case .caution: "CAUTION"
        case .avoid: "AVOID"
        }
    }

    private func levelColor(_ level: RecommendationLevel) -> Color {
        switch level {
        case .okay: .green
        case .caution: .orange
        case .avoid: .red
        }
    }

    private func severityColor(_ severity: DiagnosticSeverity) -> Color {
        switch severity {
        case .neutral: .primary
        case .caution: .orange
        case .avoid: .red
        }
    }

    private func reasonText(_ reason: RecommendationReason) -> String {
        switch reason {
        case .suitableTemperature: "Suitable temperature"
        case .warmTemperature: "Warm temperature"
        case .excessiveHeat: "Excessive heat"
        case .precipitationRisk: "Precipitation risk"
        case .precipitation: "Precipitation"
        case .fogOrMist: "Fog or mist"
        case .incompleteForecast: "Incomplete forecast"
        }
    }

    private func precipitationText(_ type: PrecipitationType?) -> String {
        guard let type else { return "Unavailable" }
        return type.rawValue.capitalized
    }

    private func fogText(_ condition: FogOrMistCondition?) -> String {
        switch condition {
        case .some(.none): "None"
        case .some(.mist): "Mist"
        case .some(.fog): "Fog"
        case .some(.depositingRimeFog): "Depositing rime fog"
        case nil: "Unavailable"
        }
    }

    private func eventCategoryText(_ category: DiagnosticEventCategory) -> String {
        switch category {
        case .session: "App"
        case .location: "Location"
        case .weather: "Weather"
        case .cache: "Cache"
        case .evaluation: "Decision"
        case .place: "Place"
        case .error: "Error"
        }
    }

    private func eventCategorySymbol(_ category: DiagnosticEventCategory) -> String {
        switch category {
        case .session: "app"
        case .location: "location"
        case .weather: "cloud.sun"
        case .cache: "archivebox"
        case .evaluation: "checklist"
        case .place: "mappin.and.ellipse"
        case .error: "exclamationmark.triangle"
        }
    }

    private func eventOutcomeText(_ outcome: DiagnosticEventOutcome) -> String {
        switch outcome {
        case .started: "STARTED"
        case .success: "SUCCESS"
        case .reused: "REUSED"
        case .rejected: "REJECTED"
        case .failed: "FAILED"
        case .information: "INFO"
        }
    }

    private func eventOutcomeColor(_ outcome: DiagnosticEventOutcome) -> Color {
        switch outcome {
        case .success, .reused: .green
        case .rejected: .orange
        case .failed: .red
        case .started, .information: .secondary
        }
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
