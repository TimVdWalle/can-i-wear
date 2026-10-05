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
            VStack(spacing: 16) {
                Image(systemName: presentation.symbolName)
                    .font(.system(size: 64))
                    .accessibilityHidden(true)
                Text(presentation.title)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text(presentation.reason)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
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
        case .forecastIncomplete:
            failure(
                title: "Today’s forecast is incomplete",
                message: "There isn’t enough reliable weather data for a safe answer."
            )
        }
    }

    private func failure(title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .accessibilityHidden(true)
            Text(title)
                .font(.title2.bold())
            Text(message)
                .foregroundStyle(.secondary)
            Button("Try Again") {
                Task { await model.retry() }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    ContentView(model: RecommendationViewModel(
        initialState: .result(RecommendationPresentation(
            recommendation: HourlyRecommendation(level: .okay, reason: .suitableTemperature)
        ))
    ))
}
