import CoreLocation
import Foundation

@MainActor
protocol LocationClient: AnyObject {
    var locationServicesEnabled: Bool { get }
    var authorizationStatus: CLAuthorizationStatus { get }
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)? { get set }
    var onLocations: (([CLLocation]) -> Void)? { get set }
    var onFailure: ((Error) -> Void)? { get set }

    func requestWhenInUseAuthorization()
    func startUpdatingLocation(desiredAccuracy: CLLocationAccuracy)
    func stopUpdatingLocation()
}

@MainActor
final class SystemLocationClient: NSObject, LocationClient, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?
    var onLocations: (([CLLocation]) -> Void)?
    var onFailure: ((Error) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.allowsBackgroundLocationUpdates = false
    }

    var locationServicesEnabled: Bool {
        CLLocationManager.locationServicesEnabled()
    }

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func startUpdatingLocation(desiredAccuracy: CLLocationAccuracy) {
        manager.desiredAccuracy = desiredAccuracy
        manager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        manager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        onAuthorizationChange?(manager.authorizationStatus)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        onLocations?(locations)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        onFailure?(error)
    }
}

@MainActor
final class CoreLocationProvider: LocationProvider {
    typealias Sleep = @Sendable (Duration) async throws -> Void

    private let client: any LocationClient
    private let config: LocationAcquisitionConfig
    private let sleep: Sleep
    private var continuation: CheckedContinuation<LocationReading, any Error>?
    private var timeoutTask: Task<Void, Never>?

    convenience init(
        config: LocationAcquisitionConfig = AppConfiguration.locationAcquisition,
        sleep: @escaping Sleep = { duration in
            try await Task.sleep(for: duration)
        }
    ) {
        self.init(client: SystemLocationClient(), config: config, sleep: sleep)
    }

    init(
        client: any LocationClient,
        config: LocationAcquisitionConfig = AppConfiguration.locationAcquisition,
        sleep: @escaping Sleep = { duration in
            try await Task.sleep(for: duration)
        }
    ) {
        self.client = client
        self.config = config
        self.sleep = sleep

        client.onAuthorizationChange = { [weak self] status in
            self?.authorizationChanged(to: status)
        }
        client.onLocations = { [weak self] locations in
            self?.received(locations)
        }
        client.onFailure = { [weak self] error in
            self?.failed(with: error)
        }
    }

    func currentLocation() async throws -> LocationReading {
        guard continuation == nil else {
            throw LocationProviderError.unavailable
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: LocationProviderError.cancelled)
                    return
                }

                self.continuation = continuation
                beginRequest()
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.finish(with: .failure(.cancelled))
            }
        }
    }

    private func beginRequest() {
        guard client.locationServicesEnabled else {
            finish(with: .failure(.unavailable))
            return
        }

        authorizationChanged(to: client.authorizationStatus)
    }

    private func authorizationChanged(to status: CLAuthorizationStatus) {
        guard continuation != nil else { return }

        switch status {
        case .notDetermined:
            client.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            startAcquiringLocation()
        case .denied:
            finish(with: .failure(.permissionDenied))
        case .restricted:
            finish(with: .failure(.unavailable))
        @unknown default:
            finish(with: .failure(.unavailable))
        }
    }

    private func startAcquiringLocation() {
        guard timeoutTask == nil else { return }

        client.startUpdatingLocation(desiredAccuracy: config.requestedAccuracyMeters)
        timeoutTask = Task { @MainActor [weak self, config, sleep] in
            do {
                try await sleep(config.timeout)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            self?.finish(with: .failure(.timedOut))
        }
    }

    private func received(_ locations: [CLLocation]) {
        guard let location = locations
            .filter({ $0.horizontalAccuracy >= 0 })
            .sorted(by: { $0.timestamp > $1.timestamp })
            .first(where: { $0.horizontalAccuracy <= config.maximumAcceptedAccuracyMeters })
        else {
            return
        }

        let reading = LocationReading(
            identity: LocationIdentity(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            ),
            accuracyMeters: location.horizontalAccuracy,
            timestamp: location.timestamp
        )
        finish(with: .success(reading))
    }

    private func failed(with error: Error) {
        if let locationError = error as? CLError, locationError.code == .locationUnknown {
            return
        }

        if let locationError = error as? CLError, locationError.code == .denied {
            finish(with: .failure(.permissionDenied))
        } else {
            finish(with: .failure(.unavailable))
        }
    }

    private func finish(with result: Result<LocationReading, LocationProviderError>) {
        guard let continuation else { return }

        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        client.stopUpdatingLocation()
        continuation.resume(with: result.mapError { $0 as any Error })
    }
}
