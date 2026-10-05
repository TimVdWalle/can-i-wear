import CoreLocation
import Foundation
import Testing
@testable import Can_I_Wear

@MainActor
struct CoreLocationProviderTests {
    private let config = LocationAcquisitionConfig(
        requestedAccuracyMeters: 1_000,
        maximumAcceptedAccuracyMeters: 5_000,
        timeout: .seconds(15)
    )

    @Test func returnsFirstUsableLocationAndStopsUpdates() async throws {
        let client = FakeLocationClient(authorizationStatus: .authorizedWhenInUse)
        let provider = CoreLocationProvider(client: client, config: config, sleep: longSleep)
        let request = Task { try await provider.currentLocation() }
        await Task.yield()

        client.send(location: CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 50.85, longitude: 4.35),
            altitude: 0,
            horizontalAccuracy: 25,
            verticalAccuracy: 0,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        ))

        let reading = try await request.value
        #expect(reading.identity == LocationIdentity(latitude: 50.85, longitude: 4.35))
        #expect(reading.accuracyMeters == 25)
        #expect(client.requestedAccuracy == 1_000)
        #expect(client.stopCount == 1)
    }

    @Test func reportsDeniedPermissionWithoutStartingUpdates() async {
        let client = FakeLocationClient(authorizationStatus: .denied)
        let provider = CoreLocationProvider(client: client, config: config, sleep: longSleep)

        await #expect(throws: LocationProviderError.permissionDenied) {
            try await provider.currentLocation()
        }
        #expect(client.startCount == 0)
    }

    @Test func reportsUnavailableServices() async {
        let client = FakeLocationClient(
            locationServicesEnabled: false,
            authorizationStatus: .authorizedWhenInUse
        )
        let provider = CoreLocationProvider(client: client, config: config, sleep: longSleep)

        await #expect(throws: LocationProviderError.unavailable) {
            try await provider.currentLocation()
        }
        #expect(client.startCount == 0)
    }

    @Test func timesOutAndStopsUpdates() async {
        let client = FakeLocationClient(authorizationStatus: .authorizedWhenInUse)
        let provider = CoreLocationProvider(client: client, config: config) { _ in }

        await #expect(throws: LocationProviderError.timedOut) {
            try await provider.currentLocation()
        }
        #expect(client.stopCount == 1)
    }

    @Test func cancellationStopsUpdates() async {
        let client = FakeLocationClient(authorizationStatus: .authorizedWhenInUse)
        let provider = CoreLocationProvider(client: client, config: config, sleep: longSleep)
        let request = Task { try await provider.currentLocation() }
        await Task.yield()

        request.cancel()

        await #expect(throws: LocationProviderError.cancelled) {
            try await request.value
        }
        #expect(client.stopCount == 1)
    }

    private var longSleep: CoreLocationProvider.Sleep {
        { _ in try await Task.sleep(for: .seconds(60)) }
    }
}

@MainActor
private final class FakeLocationClient: LocationClient {
    let locationServicesEnabled: Bool
    var authorizationStatus: CLAuthorizationStatus
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?
    var onLocations: (([CLLocation]) -> Void)?
    var onFailure: ((Error) -> Void)?
    private(set) var requestedAccuracy: CLLocationAccuracy?
    private(set) var startCount = 0
    private(set) var stopCount = 0

    init(
        locationServicesEnabled: Bool = true,
        authorizationStatus: CLAuthorizationStatus
    ) {
        self.locationServicesEnabled = locationServicesEnabled
        self.authorizationStatus = authorizationStatus
    }

    func requestWhenInUseAuthorization() {}

    func startUpdatingLocation(desiredAccuracy: CLLocationAccuracy) {
        requestedAccuracy = desiredAccuracy
        startCount += 1
    }

    func stopUpdatingLocation() {
        stopCount += 1
    }

    func send(location: CLLocation) {
        onLocations?([location])
    }
}
