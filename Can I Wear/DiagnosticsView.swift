import SwiftUI
import UIKit

struct DiagnosticsView: View {
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
