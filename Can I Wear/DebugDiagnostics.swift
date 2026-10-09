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
    let ageSeconds: TimeInterval
    let durationSeconds: TimeInterval?
    let cacheStatus: String
    let timezoneIdentifier: String
    let hourCount: Int
}

nonisolated enum DiagnosticSeverity: Equatable, Sendable {
    case neutral
    case caution
    case avoid
}

nonisolated struct DiagnosticPeriodDetail: Equatable, Identifiable, Sendable {
    var id: Date { interval.start }

    let interval: DateInterval
    let timezoneIdentifier: String
    let level: RecommendationLevel
    let reason: RecommendationReason
}

nonisolated struct DiagnosticHourlyDetail: Equatable, Identifiable, Sendable {
    var id: Date { timestamp }

    let timestamp: Date
    let timezoneIdentifier: String
    let actualTemperatureCelsius: Double?
    let apparentTemperatureCelsius: Double?
    let selectedTemperatureCelsius: Double?
    let selectedTemperatureSeverity: DiagnosticSeverity
    let precipitationAmountMillimeters: Double?
    let precipitationAmountSeverity: DiagnosticSeverity
    let precipitationType: PrecipitationType?
    let precipitationTypeSeverity: DiagnosticSeverity
    let precipitationChanceFraction: Double?
    let precipitationChanceSeverity: DiagnosticSeverity
    let fogOrMistCondition: FogOrMistCondition?
    let fogOrMistSeverity: DiagnosticSeverity
    let windSpeedKilometersPerHour: Double?
    let windGustKilometersPerHour: Double?
    let level: RecommendationLevel
    let reason: RecommendationReason
}

@MainActor
protocol PlaceResolving {
    func place(for location: LocationIdentity) async -> String?
}

@MainActor
protocol LocalityResolving {
    func locality(for location: LocationIdentity) async -> String?
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
struct SystemLocalityResolver: LocalityResolving {
    func locality(for location: LocationIdentity) async -> String? {
        let coreLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        guard let request = MKReverseGeocodingRequest(location: coreLocation) else { return nil }
        guard let item = try? await request.mapItems.first else { return nil }

        if let representations = item.addressRepresentations {
            if let city = representations.cityName, !city.isEmpty {
                return city
            }
            if let city = representations.cityWithContext, !city.isEmpty {
                return city
            }
            if let region = representations.regionName, !region.isEmpty {
                return region
            }
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
    private(set) var hourlyDetails: [DiagnosticHourlyDetail] = []
    private(set) var periodDetails: [DiagnosticPeriodDetail] = []
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
            ageSeconds: max(0, now().timeIntervalSince(forecast.metadata.fetchedAt)),
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
            let amount = hour?.precipitationAmountMillimeters
            let chance = hour?.precipitationChanceFraction
            return DiagnosticHourlyDetail(
                timestamp: evaluated.timestamp,
                timezoneIdentifier: hour?.timezoneIdentifier ?? evaluation.timezoneIdentifier,
                actualTemperatureCelsius: hour?.actualTemperatureCelsius,
                apparentTemperatureCelsius: hour?.apparentTemperatureCelsius,
                selectedTemperatureCelsius: selected,
                selectedTemperatureSeverity: Self.temperatureSeverity(selected),
                precipitationAmountMillimeters: amount,
                precipitationAmountSeverity: amount.map {
                    $0 > AppConfiguration.jacketRules.maximumDryPrecipitationAmountMillimeters
                        ? .avoid : .neutral
                } ?? .neutral,
                precipitationType: hour?.precipitationType,
                precipitationTypeSeverity: Self.precipitationTypeSeverity(hour?.precipitationType),
                precipitationChanceFraction: chance,
                precipitationChanceSeverity: Self.precipitationChanceSeverity(chance),
                fogOrMistCondition: hour?.fogOrMistCondition,
                fogOrMistSeverity: hour?.fogOrMistCondition?.isLeatherMoistureHazard == true
                    ? .avoid : .neutral,
                windSpeedKilometersPerHour: hour?.windSpeedKilometersPerHour,
                windGustKilometersPerHour: hour?.windGustKilometersPerHour,
                level: evaluated.recommendation.level,
                reason: evaluated.recommendation.reason
            )
        }
        periodDetails = periods.map {
            DiagnosticPeriodDetail(
                interval: $0.interval,
                timezoneIdentifier: $0.timezoneIdentifier,
                level: $0.recommendation.level,
                reason: $0.recommendation.reason
            )
        }
    }

    var readableReport: String {
        let generatedAt = now()
        var lines = [
            "Can I Wear — Local Diagnostics",
            "Generated: \(Self.timestamp(generatedAt, relativeTo: generatedAt))",
            "Local only: this report is not uploaded.",
            "Place: \(place)",
            ""
        ]

        lines.append("LOCATION")
        if let locationSummary {
            lines.append("Source: \(locationSummary.source)")
            let currentAge = max(
                locationSummary.ageSeconds,
                generatedAt.timeIntervalSince(locationSummary.readingTime)
            )
            lines.append("Reading: \(Self.timestamp(locationSummary.readingTime, relativeTo: generatedAt)); age \(Self.age(currentAge)); accuracy \(Self.number(locationSummary.accuracyMeters, unit: " m"))")
            lines.append("Cache: \(locationSummary.cacheStatus)")
        } else {
            lines.append("No location diagnostics yet.")
        }

        lines.append("\nWEATHER")
        if let weatherSummary {
            lines.append("Provider: \(weatherSummary.provider)")
            lines.append("Trigger/outcome: \(weatherSummary.trigger) / \(weatherSummary.outcome)")
            let currentAge = max(
                weatherSummary.ageSeconds,
                generatedAt.timeIntervalSince(weatherSummary.fetchedAt)
            )
            lines.append("Fetched: \(Self.timestamp(weatherSummary.fetchedAt, relativeTo: generatedAt)); age \(Self.age(currentAge)); duration \(Self.optionalDuration(weatherSummary.durationSeconds)); hours \(weatherSummary.hourCount)")
            lines.append("Timezone: \(weatherSummary.timezoneIdentifier)")
            lines.append("Cache: \(weatherSummary.cacheStatus)")
        } else {
            lines.append("No weather diagnostics yet.")
        }

        lines.append("\nFINAL PERIODS")
        lines.append(contentsOf: periodDetails.isEmpty ? ["No periods yet."] : periodDetails.map {
            "\(Self.timeRange($0.interval, timezoneIdentifier: $0.timezoneIdentifier)): \($0.level.diagnosticText.uppercased()) — \($0.reason.diagnosticText)"
        })
        lines.append("\nREMAINING HOURLY INPUTS")
        lines.append(contentsOf: hourlyDetails.isEmpty ? ["No evaluated hours yet."] : hourlyDetails.map {
            "\(Self.timestamp($0.timestamp, relativeTo: generatedAt, timezoneIdentifier: $0.timezoneIdentifier)): actual \(Self.number($0.actualTemperatureCelsius, unit: "°C")), feels like \(Self.number($0.apparentTemperatureCelsius, unit: "°C")), used \(Self.number($0.selectedTemperatureCelsius, unit: "°C")); precipitation \(Self.number($0.precipitationAmountMillimeters, unit: " mm")), type \($0.precipitationType?.rawValue ?? "unavailable"), chance \(Self.percent($0.precipitationChanceFraction)); fog/mist \($0.fogOrMistCondition?.rawValue ?? "unavailable"); wind \(Self.number($0.windSpeedKilometersPerHour, unit: " km/h")), gust \(Self.number($0.windGustKilometersPerHour, unit: " km/h")); decision \($0.level.diagnosticText) (\($0.reason.diagnosticText))"
        })
        lines.append("\nACTIVITY HISTORY — NEWEST FIRST (maximum \(maximumEvents))")
        lines.append(contentsOf: events.reversed().map {
            Self.eventLine($0, relativeTo: generatedAt)
        })
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

    private static func eventLine(_ event: DiagnosticEvent, relativeTo reference: Date) -> String {
        let timing = event.durationSeconds.map { "; \(duration($0))" } ?? ""
        return "\(timestamp(event.timestamp, relativeTo: reference)) [\(event.category.rawValue)/\(event.outcome.rawValue)] \(event.title): \(event.detail)\(timing)"
    }

    private static func timestamp(
        _ date: Date,
        relativeTo reference: Date,
        timezoneIdentifier: String? = nil
    ) -> String {
        let timezone = timezoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        let formatter = DateFormatter()
        formatter.timeZone = timezone
        formatter.dateFormat = calendar.isDate(date, inSameDayAs: reference)
            ? "HH:mm:ss"
            : "EEE d MMM, HH:mm:ss"
        return formatter.string(from: date)
    }

    private static func timeRange(_ interval: DateInterval, timezoneIdentifier: String) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: timezoneIdentifier)
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: interval.start))–\(formatter.string(from: interval.end))"
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

    private static func age(_ seconds: TimeInterval) -> String {
        let seconds = max(0, seconds)
        guard seconds >= 60 else {
            return "\(Int(seconds.rounded(.down))) s"
        }
        let minutes = Int((seconds / 60).rounded(.down))
        return minutes == 1 ? "1 min" : "\(minutes) min"
    }

    private static func optionalDuration(_ seconds: TimeInterval?) -> String {
        seconds.map(duration) ?? "unavailable"
    }

    private static func temperatureSeverity(_ temperature: Double?) -> DiagnosticSeverity {
        guard let temperature, temperature.isFinite else { return .neutral }
        if temperature > AppConfiguration.jacketRules.maximumCautionTemperatureCelsius {
            return .avoid
        }
        if temperature > AppConfiguration.jacketRules.maximumOkayTemperatureCelsius {
            return .caution
        }
        return .neutral
    }

    private static func precipitationChanceSeverity(_ chance: Double?) -> DiagnosticSeverity {
        guard let chance, chance.isFinite else { return .neutral }
        if chance >= AppConfiguration.jacketRules.avoidPrecipitationChanceFraction {
            return .avoid
        }
        if chance >= AppConfiguration.jacketRules.cautionPrecipitationChanceFraction {
            return .caution
        }
        return .neutral
    }

    private static func precipitationTypeSeverity(_ type: PrecipitationType?) -> DiagnosticSeverity {
        switch type {
        case .some(.drizzle), .some(.rain), .some(.hail), .some(.snow), .some(.sleet), .some(.mixed):
            .avoid
        case .some(.none), .some(.unknown), nil:
            .neutral
        }
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
