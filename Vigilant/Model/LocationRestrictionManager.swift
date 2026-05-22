import Foundation
import CoreLocation
import MapKit

struct LocationRestriction: Identifiable, Codable, Equatable {
    let id: UUID
    var latitude: Double
    var longitude: Double
    var radius: CLLocationDistance
    var appCount: Int
    var createdAt: Date

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(
        id: UUID = UUID(),
        coordinate: CLLocationCoordinate2D,
        radius: CLLocationDistance,
        appCount: Int,
        createdAt: Date = .now
    ) {
        self.id = id
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.radius = radius
        self.appCount = appCount
        self.createdAt = createdAt
    }
}

@MainActor
final class LocationRestrictionManager: NSObject, ObservableObject {

    @Published var currentCoordinate: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var restriction: LocationRestriction?
    @Published var isLocationRestrictionEnabled: Bool = false
    @Published var isInsideRestrictedArea: Bool = false
    @Published var lastError: String?

    private let locationManager = CLLocationManager()
    private let defaults = UserDefaults.standard
    private let restrictionKey = "savedLocationRestriction"
    private let enabledKey = "savedLocationRestrictionEnabled"

    override init() {
        authorizationStatus = locationManager.authorizationStatus
        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 20
        restoreRestriction()
    }

    var canTrackLocation: Bool {
        authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse
    }

    func requestLocationPermission() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            startLocationUpdates()
        case .denied, .restricted:
            lastError = "Location permission is denied. Enable location access in Settings to use location restrictions."
        @unknown default:
            lastError = "Unsupported location authorization status."
        }
    }

    func startLocationUpdates() {
        guard canTrackLocation else {
            requestLocationPermission()
            return
        }

        locationManager.startUpdatingLocation()
    }

    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
    }

    func saveRestriction(
        coordinate: CLLocationCoordinate2D,
        radius: CLLocationDistance,
        appCount: Int
    ) {
        restriction = LocationRestriction(
            coordinate: coordinate,
            radius: max(100, radius),
            appCount: appCount
        )
        isLocationRestrictionEnabled = true
        persistRestriction()
        startLocationUpdates()
        refreshLocationState()
    }

    func clearRestriction() {
        restriction = nil
        isLocationRestrictionEnabled = false
        isInsideRestrictedArea = false
        defaults.removeObject(forKey: restrictionKey)
        defaults.set(false, forKey: enabledKey)
    }

    func updateAppCount(_ appCount: Int) {
        guard var restriction else {
            return
        }

        restriction.appCount = appCount
        self.restriction = restriction
        persistRestriction()
    }

    func refreshLocationState() {
        guard let restriction, let currentCoordinate else {
            isInsideRestrictedArea = false
            return
        }

        let currentLocation = CLLocation(
            latitude: currentCoordinate.latitude,
            longitude: currentCoordinate.longitude
        )
        let restrictedLocation = CLLocation(
            latitude: restriction.latitude,
            longitude: restriction.longitude
        )

        isInsideRestrictedArea = currentLocation.distance(from: restrictedLocation) <= restriction.radius
    }

    private func persistRestriction() {
        guard let restriction else {
            return
        }

        do {
            let data = try JSONEncoder().encode(restriction)
            defaults.set(data, forKey: restrictionKey)
            defaults.set(isLocationRestrictionEnabled, forKey: enabledKey)
        } catch {
            lastError = "Unable to save location restriction: \(error.localizedDescription)"
        }
    }

    private func restoreRestriction() {
        isLocationRestrictionEnabled = defaults.bool(forKey: enabledKey)

        guard let data = defaults.data(forKey: restrictionKey) else {
            return
        }

        do {
            restriction = try JSONDecoder().decode(LocationRestriction.self, from: data)
        } catch {
            lastError = "Unable to restore location restriction: \(error.localizedDescription)"
        }
    }
}

extension LocationRestrictionManager: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus

            if canTrackLocation {
                startLocationUpdates()
            } else if authorizationStatus == .denied || authorizationStatus == .restricted {
                lastError = "Location permission is denied. Enable location access in Settings to use location restrictions."
            }
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else {
            return
        }

        Task { @MainActor in
            currentCoordinate = location.coordinate
            refreshLocationState()
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        Task { @MainActor in
            lastError = "Location update failed: \(error.localizedDescription)"
        }
    }
}
