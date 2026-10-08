import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: RecommendationViewModel
    @State private var isShowingDiagnostics = false

    init() {
        _model = State(initialValue: RecommendationViewModel())
    }

    init(model: RecommendationViewModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Can I Wear?")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Leather jacket")
                .font(.title2)
                .foregroundStyle(.secondary)

            Spacer()

            content

            Spacer()

            if model.diagnostics.isEnabled {
                Button {
                    isShowingDiagnostics = true
                } label: {
                    Label("Diagnostics", systemImage: "ladybug")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityIdentifier("diagnostics-button")
            }

            Link("Weather data by Open-Meteo", destination: URL(string: "https://open-meteo.com/")!)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .multilineTextAlignment(.center)
        .task {
            model.refreshDebugSetting()
            await model.loadIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            model.refreshDebugSetting()
        }
        .onChange(of: model.diagnostics.isEnabled) { _, enabled in
            if !enabled { isShowingDiagnostics = false }
        }
        .sheet(isPresented: $isShowingDiagnostics) {
            DiagnosticsView(diagnostics: model.diagnostics)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle, .loading:
            ProgressView("Checking today’s weather…")
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
        VStack(spacing: 20) {
            if presentation.periods.count == 1, let period = presentation.periods.first {
                recommendation(period.recommendation, prominent: true)
            } else {
                ForEach(Array(presentation.periods.enumerated()), id: \.offset) { index, period in
                    VStack(spacing: 8) {
                        Text(timeRange(for: period))
                            .font(.headline)
                        recommendation(period.recommendation, prominent: false)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("period-\(index)")
                }
            }

            if let cachedAge = presentation.cachedAge {
                Text("Cached • Updated \(ageDescription(cachedAge)) ago")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("cache-status")
            }
            if presentation.isRefreshing {
                ProgressView("Refreshing…")
                    .font(.footnote)
                    .accessibilityIdentifier("refresh-status")
            }
        }
    }

    private func recommendation(
        _ presentation: RecommendationPresentation,
        prominent: Bool
    ) -> some View {
        VStack(spacing: prominent ? 16 : 8) {
            Image(systemName: presentation.symbolName)
                .font(.system(size: prominent ? 64 : 36))
                .accessibilityHidden(true)
            Text(presentation.title)
                .font(prominent
                    ? .system(.largeTitle, design: .rounded, weight: .bold)
                    : .system(.title2, design: .rounded, weight: .bold))
            Text(presentation.reason)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func timeRange(for period: PeriodPresentation) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone(identifier: period.timezoneIdentifier)
        return "\(formatter.string(from: period.interval.start))–\(formatter.string(from: period.interval.end))"
    }

    private func ageDescription(_ age: TimeInterval) -> String {
        let minutes = max(0, Int(age / 60))
        if minutes < 1 { return "less than 1 minute" }
        return minutes == 1 ? "1 minute" : "\(minutes) minutes"
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
            Button("Try Again") {
                Task { await model.retry() }
            }
            .buttonStyle(.borderedProminent)
        }
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
                    Text("This place is included if you copy the report. Exact coordinates are not shown.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Location") {
                    if let summary = diagnostics.locationSummary {
                        LabeledContent("Source", value: summary.source)
                        LabeledContent("Reading", value: summary.readingTime.formatted(date: .abbreviated, time: .standard))
                        LabeledContent("Age", value: duration(summary.ageSeconds))
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
                        LabeledContent("Fetched", value: summary.fetchedAt.formatted(date: .abbreviated, time: .standard))
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

                Section("Final periods") {
                    if diagnostics.periodDetails.isEmpty {
                        Text("No periods yet.")
                    } else {
                        ForEach(Array(diagnostics.periodDetails.enumerated()), id: \.offset) { _, line in
                            Text(line)
                        }
                    }
                }

                Section("Remaining hourly inputs") {
                    if diagnostics.hourlyDetails.isEmpty {
                        Text("No evaluated hours yet.")
                    } else {
                        ForEach(Array(diagnostics.hourlyDetails.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.footnote.monospaced())
                        }
                    }
                }

                Section("Latest local events (\(diagnostics.events.count)/\(AppConfiguration.maximumDiagnosticEvents))") {
                    if diagnostics.events.isEmpty {
                        Text("No events yet.")
                    } else {
                        ForEach(diagnostics.events.reversed()) { event in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.title)
                                    .font(.headline)
                                Text("\(event.category.rawValue.capitalized) • \(event.outcome.rawValue.capitalized) • \(event.timestamp.formatted(date: .omitted, time: .standard))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(event.detail)
                                    .font(.footnote)
                                if let seconds = event.durationSeconds {
                                    Text("Duration: \(duration(seconds))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
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

    private func measurement(_ value: Double?, unit: String) -> String {
        guard let value, value.isFinite else { return "Unavailable" }
        return "\(value.formatted(.number.precision(.fractionLength(0...1)))) \(unit)"
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
            cachedAge: nil,
            isRefreshing: false
        ))
    ))
}
