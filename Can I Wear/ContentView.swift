import SwiftUI

struct ContentView: View {
    @State private var model: RecommendationViewModel

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

            Link("Weather data by Open-Meteo", destination: URL(string: "https://open-meteo.com/")!)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .multilineTextAlignment(.center)
        .task {
            await model.loadIfNeeded()
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
