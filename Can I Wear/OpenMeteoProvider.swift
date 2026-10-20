import Foundation

nonisolated protocol HTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

nonisolated struct URLSessionHTTPClient: HTTPClient {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WeatherProviderError.unavailable
        }
        return (data, httpResponse)
    }
}

nonisolated struct OpenMeteoProvider: WeatherProvider {
    let diagnosticName = "Open-Meteo"
    private let client: any HTTPClient
    private let now: @Sendable () -> Date
    private let decoder: JSONDecoder

    init(
        client: any HTTPClient = URLSessionHTTPClient(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.client = client
        self.now = now
        decoder = JSONDecoder()
    }

    func hourlyForecast(for location: LocationIdentity) async throws -> NormalizedForecast {
        do {
            let request = try Self.makeRequest(for: location)
            let (data, response) = try await client.data(for: request)

            guard (200..<300).contains(response.statusCode) else {
                if response.statusCode == 401 || response.statusCode == 403 {
                    throw WeatherProviderError.unauthorized
                }
                throw WeatherProviderError.unavailable
            }

            let payload = try decoder.decode(OpenMeteoResponse.self, from: data)
            return NormalizedForecast(
                hours: payload.normalizedHours,
                metadata: ForecastMetadata(fetchedAt: now(), location: location)
            )
        } catch is CancellationError {
            throw WeatherProviderError.cancelled
        } catch is URLError {
            throw WeatherProviderError.network
        } catch let error as WeatherProviderError {
            throw error
        } catch {
            throw WeatherProviderError.unavailable
        }
    }

    static func makeRequest(for location: LocationIdentity) throws -> URLRequest {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(location.latitude)),
            URLQueryItem(name: "longitude", value: String(location.longitude)),
            URLQueryItem(
                name: "hourly",
                value: [
                    "temperature_2m",
                    "apparent_temperature",
                    "precipitation_probability",
                    "precipitation",
                    "rain",
                    "showers",
                    "snowfall",
                    "weather_code",
                    "is_day",
                    "cloud_cover",
                    "uv_index",
                    "wind_speed_10m",
                    "wind_gusts_10m"
                ].joined(separator: ",")
            ),
            URLQueryItem(name: "temperature_unit", value: "celsius"),
            URLQueryItem(name: "precipitation_unit", value: "mm"),
            URLQueryItem(name: "wind_speed_unit", value: "kmh"),
            URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "timezone", value: "auto")
        ]

        guard let url = components?.url else {
            throw WeatherProviderError.unavailable
        }

        return URLRequest(url: url)
    }
}

nonisolated private struct OpenMeteoResponse: Decodable {
    let timezone: String?
    let hourly: Hourly

    var normalizedHours: [HourlyWeather] {
        let indicesByTimestamp = Dictionary(grouping: hourly.time.indices, by: { hourly.time[$0] })
        return hourly.time.indices.map { index in
            // Open-Meteo stamps sums/probability/gust maxima at the END of their hour.
            // Match exact UTC timestamps, not neighboring array positions or local clock labels.
            let accumulationIndices = indicesByTimestamp[hourly.time[index] + 3_600] ?? []
            let accumulationIndex = accumulationIndices.count == 1 ? accumulationIndices.first : nil
            return normalizedHour(at: index, accumulationIndex: accumulationIndex)
        }
    }

    private func normalizedHour(at index: Int, accumulationIndex: Int?) -> HourlyWeather {
        let weatherCode = hourly.weatherCode?[safe: index] ?? nil
        let precipitation = accumulatedValue(hourly.precipitation, at: accumulationIndex)
        return HourlyWeather(
            timestamp: Date(timeIntervalSince1970: TimeInterval(hourly.time[index])),
            timezoneIdentifier: timezone,
            actualTemperatureCelsius: hourly.temperature?[safe: index] ?? nil,
            apparentTemperatureCelsius: hourly.apparentTemperature?[safe: index] ?? nil,
            precipitationAmountMillimeters: precipitation,
            precipitationType: accumulationIndex == nil ? nil : Self.precipitationType(
                amount: precipitation,
                rain: accumulatedValue(hourly.rain, at: accumulationIndex) ?? 0,
                showers: accumulatedValue(hourly.showers, at: accumulationIndex) ?? 0,
                snowfall: accumulatedValue(hourly.snowfall, at: accumulationIndex) ?? 0,
                weatherCode: weatherCode
            ),
            precipitationChanceFraction: accumulatedValue(hourly.precipitationProbability, at: accumulationIndex)
                .map { $0 / 100 },
            fogOrMistCondition: Self.fogOrMistCondition(weatherCode: weatherCode),
            windSpeedKilometersPerHour: hourly.windSpeed?[safe: index] ?? nil,
            windGustKilometersPerHour: accumulatedValue(hourly.windGusts, at: accumulationIndex),
            isDaylight: Self.daylight(hourly.isDay?[safe: index] ?? nil),
            skyCondition: Self.skyCondition(
                weatherCode: weatherCode,
                cloudCover: hourly.cloudCover?[safe: index] ?? nil
            ),
            uvIndex: Self.validUVIndex(hourly.uvIndex?[safe: index] ?? nil)
        )
    }

    private func accumulatedValue(_ values: [Double?]?, at index: Int?) -> Double? {
        guard let index else { return nil }
        return values?[safe: index] ?? nil
    }

    private static func daylight(_ value: Int?) -> Bool? {
        switch value {
        case 0: false
        case 1: true
        default: nil
        }
    }

    private static func validUVIndex(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value >= 0 else { return nil }
        return value
    }

    private static func skyCondition(weatherCode: Int?, cloudCover: Double?) -> SkyCondition? {
        switch weatherCode {
        case 0: return .clear
        case 1: return .mainlyClear
        case 2: return .partlyCloudy
        case 3: return .overcast
        case 45, 48: return .fogOrMist
        default: break
        }
        // Rain/snow codes describe precipitation, not sky cover. Use the provider's own
        // cloud categories, without inventing cloudiness or visibility-based fog.
        guard let cloudCover, cloudCover.isFinite, (0...100).contains(cloudCover) else { return nil }
        switch cloudCover {
        case ..<AppConfiguration.openMeteoClearSkyUpperCloudCoverPercent: return .clear
        case ..<AppConfiguration.openMeteoMainlyClearUpperCloudCoverPercent: return .mainlyClear
        case ..<AppConfiguration.openMeteoPartlyCloudyUpperCloudCoverPercent: return .partlyCloudy
        default: return .overcast
        }
    }

    private static func fogOrMistCondition(weatherCode: Int?) -> FogOrMistCondition? {
        guard let weatherCode else { return nil }
        return switch weatherCode {
        case 45: .fog
        case 48: .depositingRimeFog
        default: FogOrMistCondition.none
        }
    }

    private static func precipitationType(
        amount: Double?,
        rain: Double,
        showers: Double,
        snowfall: Double,
        weatherCode: Int?
    ) -> PrecipitationType? {
        if snowfall > 0, rain > 0 || showers > 0 { return .mixed }
        if snowfall > 0 { return .snow }
        if rain > 0 || showers > 0 { return .rain }

        guard let weatherCode else {
            return amount == 0 ? PrecipitationType.none : nil
        }

        switch weatherCode {
        case 51...55:
            return .drizzle
        case 56...57, 66...67:
            return .sleet
        case 61...65, 80...82:
            return .rain
        case 71...77, 85...86:
            return .snow
        case 96, 99:
            return .hail
        default:
            return amount == 0 ? PrecipitationType.none : .unknown
        }
    }

    nonisolated struct Hourly: Decodable {
        let time: [Int]
        let temperature: [Double?]?
        let apparentTemperature: [Double?]?
        let precipitationProbability: [Double?]?
        let precipitation: [Double?]?
        let rain: [Double?]?
        let showers: [Double?]?
        let snowfall: [Double?]?
        let weatherCode: [Int?]?
        let isDay: [Int?]?
        let cloudCover: [Double?]?
        let uvIndex: [Double?]?
        let windSpeed: [Double?]?
        let windGusts: [Double?]?

        enum CodingKeys: String, CodingKey {
            case time
            case temperature = "temperature_2m"
            case apparentTemperature = "apparent_temperature"
            case precipitationProbability = "precipitation_probability"
            case precipitation
            case rain
            case showers
            case snowfall
            case weatherCode = "weather_code"
            case isDay = "is_day"
            case cloudCover = "cloud_cover"
            case uvIndex = "uv_index"
            case windSpeed = "wind_speed_10m"
            case windGusts = "wind_gusts_10m"
        }
    }
}

private extension Array {
    nonisolated subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
