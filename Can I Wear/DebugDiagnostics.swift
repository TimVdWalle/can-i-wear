import CoreLocation
import Foundation
import MapKit
import Observation

nonisolated enum DiagnosticEventCategory: String, Codable, Equatable, Sendable {
    case session
    case location
    case weather
    case cache
    case evaluation
    case place
    case error
}

nonisolated enum DiagnosticEventOutcome: String, Codable, Equatable, Sendable {
    case started
    case success
    case reused
    case rejected
    case failed
    case information
}

nonisolated struct DiagnosticEvent: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let category: DiagnosticEventCategory
    let outcome: DiagnosticEventOutcome
    let title: String
    let detail: String
    let durationSeconds: TimeInterval?

    init(
        id: UUID = UUID(),
        timestamp: Date,
        category: DiagnosticEventCategory,
        outcome: DiagnosticEventOutcome,
        title: String,
        detail: String,
        durationSeconds: TimeInterval? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.category = category
        self.outcome = outcome
        self.title = title
        self.detail = detail
        self.durationSeconds = durationSeconds
    }
}

nonisolated struct DiagnosticLocationSummary: Equatable, Sendable {
    let source: String
    let readingTime: Date
    let ageSeconds: TimeInterval
    let accuracyMeters: Double?
    let cacheStatus: String
}

nonisolated struct DiagnosticWeatherSummary: Equatable, Sendable {
    let provider: String
    let trigger: String
    let outcome: String
    let fetchedAt: Date
    let durationSeconds: TimeInterval?
    let cacheStatus: String
    let timezoneIdentifier: String
    let hourCount: Int
}

@MainActor
protocol PlaceResolving {
    func place(for location: LocationIdentity) async -> String?
}

@MainActor
struct SystemPlaceResolver: PlaceResolving {
    func place(for location: LocationIdentity) async -> String? {
        let coreLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        guard let request = MKReverseGeocodingRequest(location: coreLocation) else { return nil }
        guard let item = try? await request.mapItems.first else { return nil }

        if let representations = item.addressRepresentations {
            if let street = representations.fullAddress(includingRegion: false, singleLine: true),
               !street.isEmpty {
                return street
            }
            if let city = representations.cityWithContext, !city.isEmpty {
                return city
            }
            if let region = representations.regionName, !region.isEmpty {
                return region
            }
        }
        if let address = item.address {
            return address.shortAddress ?? address.fullAddress
        }
        return nil
    }
}

@MainActor
final class DebugSettings {
    static let enabledKey = "debug_enabled"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        Self.registerDefaults(in: defaults)
    }

    static func registerDefaults(in defaults: UserDefaults = .standard) {
        defaults.register(defaults: [enabledKey: false])
    }

    var isEnabled: Bool {
        defaults.synchronize()
        return defaults.bool(forKey: Self.enabledKey)
    }
}

@MainActor
protocol DiagnosticEventPersisting: AnyObject {
    func load() -> [DiagnosticEvent]
    func save(_ events: [DiagnosticEvent])
    func clear()
}

@MainActor
final class UserDefaultsDiagnosticEventStore: DiagnosticEventPersisting {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "localDiagnosticEvents") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> [DiagnosticEvent] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([DiagnosticEvent].self, from: data)) ?? []
    }

    func save(_ events: [DiagnosticEvent]) {
        defaults.set(try? JSONEncoder().encode(events), forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}

@MainActor
@Observable
final class DebugDiagnostics {
    private(set) var isEnabled: Bool
    private(set) var place = "Not available"
    private(set) var locationSummary: DiagnosticLocationSummary?
    private(set) var weatherSummary: DiagnosticWeatherSummary?
    private(set) var hourlyDetails: [String] = []
    private(set) var periodDetails: [String] = []
    private(set) var events: [DiagnosticEvent]

    private let settings: DebugSettings
    private let eventStore: any DiagnosticEventPersisting
    private let placeResolver: any PlaceResolving
    private let maximumEvents: Int
    private let now: () -> Date
    private var placeLocation: LocationIdentity?

    init(
        settings: DebugSettings? = nil,
        eventStore: (any DiagnosticEventPersisting)? = nil,
        placeResolver: (any PlaceResolving)? = nil,
        maximumEvents: Int = AppConfiguration.maximumDiagnosticEvents,
        now: @escaping () -> Date = { Date() }
    ) {
        let settings = settings ?? DebugSettings()
        let eventStore = eventStore ?? UserDefaultsDiagnosticEventStore()
        self.settings = settings
        self.eventStore = eventStore
        self.placeResolver = placeResolver ?? SystemPlaceResolver()
        self.maximumEvents = max(1, maximumEvents)
        self.now = now
        isEnabled = settings.isEnabled

        if settings.isEnabled {
            events = Array(eventStore.load().suffix(max(1, maximumEvents)))
        } else {
            events = []
            eventStore.clear()
        }
    }

    func refreshSetting() {
        let enabled = settings.isEnabled
        guard enabled != isEnabled else {
            if !enabled { clear() }
            return
        }

        isEnabled = enabled
        if enabled {
            record(
                category: .session,
                outcome: .information,
                title: "Debug enabled",
                detail: "Local diagnostics are active. Nothing is uploaded."
            )
        } else {
            clear()
        }
    }

    func record(
        category: DiagnosticEventCategory,
        outcome: DiagnosticEventOutcome,
        title: String,
        detail: String,
        durationSeconds: TimeInterval? = nil
    ) {
        guard isEnabled else { return }
        events.append(DiagnosticEvent(
            timestamp: now(),
            category: category,
            outcome: outcome,
            title: title,
            detail: detail,
            durationSeconds: durationSeconds
        ))
        if events.count > maximumEvents {
            events.removeFirst(events.count - maximumEvents)
        }
        eventStore.save(events)
    }

    func updateLocation(
        _ reading: LocationReading,
        source: String,
        ageSeconds: TimeInterval,
        cacheStatus: String
    ) {
        guard isEnabled else { return }
        locationSummary = DiagnosticLocationSummary(
            source: source,
            readingTime: reading.timestamp,
            ageSeconds: max(0, ageSeconds),
            accuracyMeters: reading.accuracyMeters,
            cacheStatus: cacheStatus
        )
        placeLocation = reading.identity
        place = "Looking up place…"

        Task { [weak self] in
            await self?.resolvePlace(for: reading.identity)
        }
    }

    func updateWeather(
        _ forecast: NormalizedForecast,
        provider: String,
        trigger: String,
        outcome: String,
        durationSeconds: TimeInterval?,
        cacheStatus: String
    ) {
        guard isEnabled else { return }
        weatherSummary = DiagnosticWeatherSummary(
            provider: provider,
            trigger: trigger,
            outcome: outcome,
            fetchedAt: forecast.metadata.fetchedAt,
            durationSeconds: durationSeconds,
            cacheStatus: cacheStatus,
            timezoneIdentifier: forecast.hours.compactMap(\.timezoneIdentifier).first ?? "Unavailable",
            hourCount: forecast.hours.count
        )
    }

    func updateEvaluation(
        forecast: NormalizedForecast,
        evaluation: DailyEvaluation,
        periods: [DayPeriod]
    ) {
        guard isEnabled else { return }
        let hoursByTimestamp = Dictionary(
            forecast.hours.map { ($0.timestamp, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        hourlyDetails = evaluation.hours.map { evaluated in
            let hour = hoursByTimestamp[evaluated.timestamp]
            let selected = [hour?.actualTemperatureCelsius, hour?.apparentTemperatureCelsius]
                .compactMap { $0 }
                .filter(\.isFinite)
                .max()
            return "\(Self.timestamp(evaluated.timestamp)): actual \(Self.number(hour?.actualTemperatureCelsius, unit: "°C")), apparent \(Self.number(hour?.apparentTemperatureCelsius, unit: "°C")), selected \(Self.number(selected, unit: "°C")); precipitation \(Self.number(hour?.precipitationAmountMillimeters, unit: " mm")), type \(hour?.precipitationType?.rawValue ?? "unavailable"), chance \(Self.percent(hour?.precipitationChanceFraction)); fog/mist \(hour?.fogOrMistCondition?.rawValue ?? "unavailable"); wind \(Self.number(hour?.windSpeedKilometersPerHour, unit: " km/h")), gust \(Self.number(hour?.windGustKilometersPerHour, unit: " km/h")); decision \(evaluated.recommendation.level.diagnosticText) (\(evaluated.recommendation.reason.diagnosticText))"
        }
        periodDetails = periods.map {
            "\(Self.timestamp($0.interval.start))–\(Self.timestamp($0.interval.end)): \($0.recommendation.level.diagnosticText) (\($0.recommendation.reason.diagnosticText))"
        }
    }

    var readableReport: String {
        var lines = [
            "Can I Wear — Local Diagnostics",
            "Generated: \(Self.timestamp(now()))",
            "Local only: this report is not uploaded.",
            "Place (included in copied report): \(place)",
            ""
        ]

        lines.append("LOCATION")
        if let locationSummary {
            lines.append("Source: \(locationSummary.source)")
            lines.append("Reading: \(Self.timestamp(locationSummary.readingTime)); age \(Self.duration(locationSummary.ageSeconds)); accuracy \(Self.number(locationSummary.accuracyMeters, unit: " m"))")
            lines.append("Cache: \(locationSummary.cacheStatus)")
        } else {
            lines.append("No location diagnostics yet.")
        }

        lines.append("\nWEATHER")
        if let weatherSummary {
            lines.append("Provider: \(weatherSummary.provider)")
            lines.append("Trigger/outcome: \(weatherSummary.trigger) / \(weatherSummary.outcome)")
            lines.append("Fetched: \(Self.timestamp(weatherSummary.fetchedAt)); duration \(Self.optionalDuration(weatherSummary.durationSeconds)); hours \(weatherSummary.hourCount)")
            lines.append("Timezone: \(weatherSummary.timezoneIdentifier)")
            lines.append("Cache: \(weatherSummary.cacheStatus)")
        } else {
            lines.append("No weather diagnostics yet.")
        }

        lines.append("\nFINAL PERIODS")
        lines.append(contentsOf: periodDetails.isEmpty ? ["No periods yet."] : periodDetails)
        lines.append("\nREMAINING HOURLY INPUTS")
        lines.append(contentsOf: hourlyDetails.isEmpty ? ["No evaluated hours yet."] : hourlyDetails)
        lines.append("\nLATEST EVENTS (maximum \(maximumEvents))")
        lines.append(contentsOf: events.map(Self.eventLine))
        return lines.joined(separator: "\n")
    }

    private func resolvePlace(for location: LocationIdentity) async {
        let resolved = await placeResolver.place(for: location)
        guard isEnabled, placeLocation == location else { return }
        place = resolved ?? "City or region unavailable"
        record(
            category: .place,
            outcome: resolved == nil ? .failed : .success,
            title: "Place lookup",
            detail: resolved ?? "No street, city, or region was returned."
        )
    }

    private func clear() {
        events = []
        locationSummary = nil
        weatherSummary = nil
        hourlyDetails = []
        periodDetails = []
        placeLocation = nil
        place = "Not available"
        eventStore.clear()
    }

    private static func eventLine(_ event: DiagnosticEvent) -> String {
        let timing = event.durationSeconds.map { "; \(duration($0))" } ?? ""
        return "\(timestamp(event.timestamp)) [\(event.category.rawValue)/\(event.outcome.rawValue)] \(event.title): \(event.detail)\(timing)"
    }

    private static func timestamp(_ date: Date) -> String {
        date.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false))
    }

    private static func number(_ value: Double?, unit: String) -> String {
        guard let value, value.isFinite else { return "unavailable" }
        return "\(value.formatted(.number.precision(.fractionLength(0...1))))\(unit)"
    }

    private static func percent(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "unavailable" }
        return value.formatted(.percent.precision(.fractionLength(0)))
    }

    private static func duration(_ seconds: TimeInterval) -> String {
        "\(max(0, seconds).formatted(.number.precision(.fractionLength(2)))) s"
    }

    private static func optionalDuration(_ seconds: TimeInterval?) -> String {
        seconds.map(duration) ?? "unavailable"
    }
}

nonisolated private extension RecommendationLevel {
    var diagnosticText: String {
        switch self {
        case .okay: "wear"
        case .caution: "maybe"
        case .avoid: "do not wear"
        }
    }
}

nonisolated private extension RecommendationReason {
    var diagnosticText: String {
        switch self {
        case .suitableTemperature: "suitable temperature"
        case .warmTemperature: "warm temperature"
        case .excessiveHeat: "excessive heat"
        case .precipitationRisk: "precipitation risk"
        case .precipitation: "precipitation"
        case .fogOrMist: "fog or mist"
        case .incompleteForecast: "incomplete forecast"
        }
    }
}
