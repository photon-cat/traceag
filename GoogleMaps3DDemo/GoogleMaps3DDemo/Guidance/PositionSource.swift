// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import CoreLocation
import Combine
import QuartzCore

#if canImport(UIKit)
import UIKit
#endif

#if os(iOS)
import ExternalAccessory
#endif

// MARK: - Position Update

/// Position and heading data from a position source
struct PositionUpdate {
    let coordinate: CLLocationCoordinate2D
    let heading: Double  // radians, 0 = North
    let speed: Double    // m/s
    let timestamp: Date
    let accuracy: Double?  // horizontal accuracy in meters (nil for simulator)
    let verticalAccuracy: Double?  // vertical accuracy in meters
    let altitude: Double?  // meters above sea level
}

// MARK: - GNSS Status

/// Status information about the GNSS source
struct GNSSStatus {
    let isExternalGNSS: Bool       // True if likely using external receiver
    let horizontalAccuracy: Double  // meters
    let verticalAccuracy: Double?   // meters
    let updateRate: Double          // Hz (updates per second)
    let satelliteCount: Int?        // Number of satellites (if available)
    let fixType: GNSSFixType
    let sourceName: String          // "Internal GPS", "External GNSS", etc.

    var qualityDescription: String {
        if horizontalAccuracy < 1.0 {
            return "RTK/Excellent"
        } else if horizontalAccuracy < 2.5 {
            return "DGPS/Good"
        } else if horizontalAccuracy < 5.0 {
            return "Standard"
        } else {
            return "Poor"
        }
    }
}

enum GNSSFixType: String {
    case none = "No Fix"
    case gps = "GPS"
    case dgps = "DGPS"
    case rtk = "RTK"
    case unknown = "Unknown"
}

// MARK: - Position Source Type

enum PositionSourceType: String, CaseIterable {
    case simulator = "Simulator"
    case gnss = "Device GNSS"
}

// MARK: - Position Source Protocol

/// Protocol for position input sources
protocol PositionSource: AnyObject {
    /// Publisher for position updates
    var positionPublisher: AnyPublisher<PositionUpdate, Never> { get }

    /// Publisher for GNSS status updates
    var statusPublisher: AnyPublisher<GNSSStatus, Never> { get }

    /// Current position (may be nil if not yet received)
    var currentPosition: PositionUpdate? { get }

    /// Current GNSS status
    var currentStatus: GNSSStatus? { get }

    /// Whether the source is currently active
    var isActive: Bool { get }

    /// Start providing position updates
    func start()

    /// Stop providing position updates
    func stop()

    /// Source type identifier
    var sourceType: PositionSourceType { get }
}

// MARK: - Simulator Position Source

/// Simulated position source with configurable start location and speed
class SimulatorPositionSource: PositionSource {
    // MARK: - Configuration

    var initialCoordinate: CLLocationCoordinate2D
    var speed: Double  // m/s
    var heading: Double = 0  // radians

    // MARK: - Steering (for manual control)

    var steeringInput: Double = 0  // -1 to 1 (left to right)
    var turnRate: Double = 1.5     // radians per second

    // MARK: - State

    private(set) var currentPosition: PositionUpdate?
    private(set) var isActive: Bool = false

    private var currentCoordinate: CLLocationCoordinate2D
    private var currentHeading: Double = 0

    // MARK: - Publishers

    private let positionSubject = PassthroughSubject<PositionUpdate, Never>()
    var positionPublisher: AnyPublisher<PositionUpdate, Never> {
        positionSubject.eraseToAnyPublisher()
    }

    private let statusSubject = PassthroughSubject<GNSSStatus, Never>()
    var statusPublisher: AnyPublisher<GNSSStatus, Never> {
        statusSubject.eraseToAnyPublisher()
    }

    var currentStatus: GNSSStatus? {
        GNSSStatus(
            isExternalGNSS: false,
            horizontalAccuracy: 0.0,
            verticalAccuracy: nil,
            updateRate: 60.0,
            satelliteCount: nil,
            fixType: .unknown,
            sourceName: "Simulator"
        )
    }

    // MARK: - Update Loop

    #if os(iOS)
    private var displayLink: CADisplayLink?
    #else
    private var timer: Timer?
    #endif
    private var lastUpdateTime: CFTimeInterval = 0

    let sourceType: PositionSourceType = .simulator

    // MARK: - Initialization

    init(initialCoordinate: CLLocationCoordinate2D, speed: Double = 3.0) {
        self.initialCoordinate = initialCoordinate
        self.currentCoordinate = initialCoordinate
        self.speed = speed
    }

    // MARK: - Control

    func start() {
        guard !isActive else { return }
        isActive = true

        #if os(iOS)
        displayLink = CADisplayLink(target: self, selector: #selector(update))
        displayLink?.add(to: .main, forMode: .common)
        #else
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.timerUpdate()
        }
        #endif
        lastUpdateTime = CACurrentMediaTime()
    }

    func stop() {
        #if os(iOS)
        displayLink?.invalidate()
        displayLink = nil
        #else
        timer?.invalidate()
        timer = nil
        #endif
        isActive = false
    }

    func reset() {
        currentCoordinate = initialCoordinate
        currentHeading = heading
        steeringInput = 0
    }

    func setHeading(_ newHeading: Double) {
        currentHeading = newHeading
        heading = newHeading
    }

    // MARK: - Update

    #if os(iOS)
    @objc private func update(link: CADisplayLink) {
        let currentTime = link.timestamp
        performUpdate(currentTime: currentTime)
    }
    #else
    private func timerUpdate() {
        let currentTime = CACurrentMediaTime()
        performUpdate(currentTime: currentTime)
    }
    #endif

    private func performUpdate(currentTime: CFTimeInterval) {
        let deltaTime = min(currentTime - lastUpdateTime, 0.1)
        lastUpdateTime = currentTime

        // Apply steering
        currentHeading -= steeringInput * turnRate * deltaTime

        // Normalize heading
        while currentHeading > .pi { currentHeading -= 2 * .pi }
        while currentHeading < -.pi { currentHeading += 2 * .pi }

        // Move forward
        let distance = speed * deltaTime

        // Convert to coordinate deltas using WGS84
        let meters = WGS84Converter.metersPerDegree(atLatitude: currentCoordinate.latitude)
        let dLat = distance * cos(currentHeading) / meters.lat
        let dLon = distance * sin(currentHeading) / meters.lon

        currentCoordinate = CLLocationCoordinate2D(
            latitude: currentCoordinate.latitude + dLat,
            longitude: currentCoordinate.longitude + dLon
        )

        // Publish update
        let update = PositionUpdate(
            coordinate: currentCoordinate,
            heading: currentHeading,
            speed: speed,
            timestamp: Date(),
            accuracy: nil,
            verticalAccuracy: nil,
            altitude: 350.0  // Simulated altitude
        )

        currentPosition = update
        positionSubject.send(update)
    }
}

// MARK: - GNSS Position Source

/// Real device GNSS position source using CoreLocation
/// Supports external GNSS receivers like Garmin GLO 2 via Bluetooth
/// External receivers are automatically used by CoreLocation when connected
class GNSSPositionSource: NSObject, PositionSource, CLLocationManagerDelegate {
    // MARK: - State

    private(set) var currentPosition: PositionUpdate?
    private(set) var currentStatus: GNSSStatus?
    private(set) var isActive: Bool = false
    private var pendingStart: Bool = false

    // MARK: - CoreLocation

    private let locationManager = CLLocationManager()
    private var lastLocation: CLLocation?
    private var lastCompassHeading: Double = 0  // radians

    // MARK: - Update Rate Tracking

    private var updateTimestamps: [Date] = []
    private let updateRateWindow: TimeInterval = 2.0  // Calculate rate over 2 seconds
    private var calculatedUpdateRate: Double = 0

    // MARK: - External GNSS Detection

    /// Thresholds for detecting external GNSS
    /// External receivers typically have better accuracy and higher update rates
    private let externalAccuracyThreshold: Double = 3.0  // meters
    private let externalUpdateRateThreshold: Double = 5.0  // Hz

    // MARK: - Publishers

    private let positionSubject = PassthroughSubject<PositionUpdate, Never>()
    var positionPublisher: AnyPublisher<PositionUpdate, Never> {
        positionSubject.eraseToAnyPublisher()
    }

    private let statusSubject = PassthroughSubject<GNSSStatus, Never>()
    var statusPublisher: AnyPublisher<GNSSStatus, Never> {
        statusSubject.eraseToAnyPublisher()
    }

    let sourceType: PositionSourceType = .gnss

    // MARK: - Initialization

    override init() {
        super.init()
        locationManager.delegate = self

        // Configure for best accuracy - essential for external GNSS
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation

        // Allow background updates if needed
        locationManager.allowsBackgroundLocationUpdates = false

        // Set activity type for agricultural navigation
        // This helps iOS optimize for vehicle movement patterns
        locationManager.activityType = .automotiveNavigation

        // Disable distance filter to get all updates from external GNSS
        // External receivers like GLO 2 provide 10Hz updates
        locationManager.distanceFilter = kCLDistanceFilterNone

        // Fine-grained heading updates
        locationManager.headingFilter = 0.5  // Update every 0.5 degrees

        // Pause updates automatically when stationary to save power
        locationManager.pausesLocationUpdatesAutomatically = false
    }

    // MARK: - Control

    func start() {
        guard !isActive else { return }
        isActive = true

        let status = locationManager.authorizationStatus

        switch status {
        case .notDetermined:
            pendingStart = true
            locationManager.requestWhenInUseAuthorization()

        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()

        case .denied, .restricted:
            print("Location access denied or restricted")
            isActive = false

        @unknown default:
            pendingStart = true
            locationManager.requestWhenInUseAuthorization()
        }
    }

    func stop() {
        locationManager.stopUpdatingLocation()
        #if os(iOS)
        locationManager.stopUpdatingHeading()
        #endif
        isActive = false
        pendingStart = false
        updateTimestamps.removeAll()
    }

    private func startLocationUpdates() {
        locationManager.startUpdatingLocation()
        #if os(iOS)
        if CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()
        }
        #endif
        print("GNSS: Started location updates")
    }

    // MARK: - Update Rate Calculation

    private func updateUpdateRate() {
        let now = Date()
        updateTimestamps.append(now)

        // Remove timestamps older than window
        updateTimestamps = updateTimestamps.filter {
            now.timeIntervalSince($0) <= updateRateWindow
        }

        // Calculate update rate
        if updateTimestamps.count > 1 {
            calculatedUpdateRate = Double(updateTimestamps.count - 1) / updateRateWindow
        }
    }

    // MARK: - External GNSS Detection

    private func detectExternalGNSS(accuracy: Double) -> Bool {
        // External GNSS typically has:
        // 1. Better accuracy (< 3m with SBAS/DGPS)
        // 2. Higher update rate (5-10 Hz vs 1 Hz internal)
        let hasGoodAccuracy = accuracy < externalAccuracyThreshold
        let hasHighUpdateRate = calculatedUpdateRate >= externalUpdateRateThreshold

        return hasGoodAccuracy && hasHighUpdateRate
    }

    private func determineFixType(accuracy: Double) -> GNSSFixType {
        if accuracy < 0 {
            return .none
        } else if accuracy < 1.0 {
            return .rtk
        } else if accuracy < 3.0 {
            return .dgps
        } else {
            return .gps
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // Track update rate
        updateUpdateRate()

        // Determine heading:
        // 1. Use GPS course if available and moving (course >= 0 and speed > 0.5 m/s)
        // 2. Fall back to compass heading
        // 3. Calculate from position delta as last resort
        var heading: Double

        if location.course >= 0 && location.speed > 0.5 {
            // GPS course is valid (in degrees, clockwise from north)
            heading = location.course * .pi / 180
        } else if lastCompassHeading != 0 {
            // Use compass heading when stationary or course unavailable
            heading = lastCompassHeading
        } else if let last = lastLocation {
            // Calculate from position change
            let dLat = location.coordinate.latitude - last.coordinate.latitude
            let dLon = location.coordinate.longitude - last.coordinate.longitude
            if abs(dLat) > 0.0000001 || abs(dLon) > 0.0000001 {
                heading = atan2(dLon, dLat)
            } else {
                heading = currentPosition?.heading ?? 0
            }
        } else {
            heading = 0
        }

        lastLocation = location

        // Create position update with all available data
        let update = PositionUpdate(
            coordinate: location.coordinate,
            heading: heading,
            speed: max(0, location.speed),
            timestamp: location.timestamp,
            accuracy: location.horizontalAccuracy,
            verticalAccuracy: location.verticalAccuracy >= 0 ? location.verticalAccuracy : nil,
            altitude: location.altitude
        )

        currentPosition = update
        positionSubject.send(update)

        // Update GNSS status
        let isExternal = detectExternalGNSS(accuracy: location.horizontalAccuracy)
        let fixType = determineFixType(accuracy: location.horizontalAccuracy)

        let status = GNSSStatus(
            isExternalGNSS: isExternal,
            horizontalAccuracy: location.horizontalAccuracy,
            verticalAccuracy: location.verticalAccuracy >= 0 ? location.verticalAccuracy : nil,
            updateRate: calculatedUpdateRate,
            satelliteCount: nil,  // Not available via CoreLocation
            fixType: fixType,
            sourceName: isExternal ? "External GNSS" : "Internal GPS"
        )

        currentStatus = status
        statusSubject.send(status)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // Store compass heading for use when GPS course is unavailable
        // trueHeading is relative to true north (requires location), magneticHeading is to magnetic north
        if newHeading.trueHeading >= 0 {
            lastCompassHeading = newHeading.trueHeading * .pi / 180
        } else if newHeading.magneticHeading >= 0 {
            lastCompassHeading = newHeading.magneticHeading * .pi / 180
        }

        // If we have a current position but were stationary, update with compass heading
        if let pos = currentPosition, pos.speed < 0.5 {
            let update = PositionUpdate(
                coordinate: pos.coordinate,
                heading: lastCompassHeading,
                speed: pos.speed,
                timestamp: Date(),
                accuracy: pos.accuracy,
                verticalAccuracy: pos.verticalAccuracy,
                altitude: pos.altitude
            )
            currentPosition = update
            positionSubject.send(update)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("GNSS error: \(error.localizedDescription)")

        // Update status to show error
        let status = GNSSStatus(
            isExternalGNSS: false,
            horizontalAccuracy: -1,
            verticalAccuracy: nil,
            updateRate: 0,
            satelliteCount: nil,
            fixType: .none,
            sourceName: "Error"
        )
        currentStatus = status
        statusSubject.send(status)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            if pendingStart || isActive {
                pendingStart = false
                startLocationUpdates()
            }

        case .denied, .restricted:
            print("Location authorization denied")
            isActive = false
            pendingStart = false

        default:
            break
        }
    }
}

// MARK: - GPS Device Info

/// Information about a connected GPS device
struct GPSDeviceInfo: Identifiable, Equatable {
    let id: String
    let name: String
    let manufacturer: String
    let modelNumber: String
    let serialNumber: String
    let isConnected: Bool
    let protocolStrings: [String]

    var displayName: String {
        if !manufacturer.isEmpty && manufacturer != "Unknown" {
            return "\(manufacturer) \(name)"
        }
        return name
    }

    static func == (lhs: GPSDeviceInfo, rhs: GPSDeviceInfo) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - GPS Device Manager

#if os(iOS)
/// Manages discovery and connection to external GPS accessories via External Accessory framework
/// Supports MFi GPS devices like Garmin GLO 2, Bad Elf GPS Pro+, etc.
class GPSDeviceManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published var connectedDevices: [GPSDeviceInfo] = []
    @Published var selectedDeviceId: String?
    @Published var isScanning: Bool = false

    // MARK: - Singleton

    static let shared = GPSDeviceManager()

    // MARK: - Known GPS Protocol Strings

    /// Protocol strings used by known GPS devices
    private let knownGPSProtocols = [
        "com.bad-elf.gps",           // Bad Elf GPS devices
        "com.garmin.glo",            // Garmin GLO
        "com.dualav.xgps150",        // Dual XGPS150
        "com.dualav.xgps160",        // Dual XGPS160
        "com.emlid.reachrs",         // Emlid Reach RS
        "com.naviter.oudie",         // Naviter Oudie
    ]

    // MARK: - Initialization

    private override init() {
        super.init()
        setupNotifications()
        refreshConnectedDevices()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup

    private func setupNotifications() {
        // Listen for accessory connection/disconnection
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessoryConnected(_:)),
            name: .EAAccessoryDidConnect,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessoryDisconnected(_:)),
            name: .EAAccessoryDidDisconnect,
            object: nil
        )

        // Start monitoring for accessory changes
        EAAccessoryManager.shared().registerForLocalNotifications()
    }

    // MARK: - Device Discovery

    /// Refresh the list of connected GPS devices
    func refreshConnectedDevices() {
        isScanning = true

        let accessories = EAAccessoryManager.shared().connectedAccessories
        var devices: [GPSDeviceInfo] = []

        // Add internal GPS as first option
        devices.append(GPSDeviceInfo(
            id: "internal",
            name: "Internal GPS",
            manufacturer: "Apple",
            modelNumber: UIDevice.current.model,
            serialNumber: "",
            isConnected: true,
            protocolStrings: []
        ))

        // Check each connected accessory
        for accessory in accessories {
            // Check if this accessory supports any GPS protocols
            let hasGPSProtocol = accessory.protocolStrings.contains { proto in
                knownGPSProtocols.contains { proto.lowercased().contains($0.lowercased()) }
            }

            // Also check if it looks like a GPS based on name
            let nameIndicatesGPS = accessory.name.lowercased().contains("gps") ||
                                   accessory.name.lowercased().contains("glo") ||
                                   accessory.name.lowercased().contains("gnss") ||
                                   accessory.manufacturer.lowercased().contains("garmin") ||
                                   accessory.manufacturer.lowercased().contains("bad elf")

            if hasGPSProtocol || nameIndicatesGPS {
                let device = GPSDeviceInfo(
                    id: "ea_\(accessory.connectionID)",
                    name: accessory.name,
                    manufacturer: accessory.manufacturer,
                    modelNumber: accessory.modelNumber,
                    serialNumber: accessory.serialNumber,
                    isConnected: accessory.isConnected,
                    protocolStrings: accessory.protocolStrings
                )
                devices.append(device)
            }
        }

        DispatchQueue.main.async {
            self.connectedDevices = devices
            self.isScanning = false

            // Auto-select external GPS if available and nothing selected
            if self.selectedDeviceId == nil || self.selectedDeviceId == "internal" {
                if let externalDevice = devices.first(where: { $0.id != "internal" }) {
                    self.selectedDeviceId = externalDevice.id
                    print("GPSDeviceManager: Auto-selected \(externalDevice.displayName)")
                }
            }
        }
    }

    /// Select a GPS device by ID
    func selectDevice(_ deviceId: String) {
        selectedDeviceId = deviceId

        if let device = connectedDevices.first(where: { $0.id == deviceId }) {
            print("GPSDeviceManager: Selected \(device.displayName)")

            // Note: When using CoreLocation, iOS automatically routes through
            // connected MFi GPS accessories. We track selection for UI purposes.
            // For direct NMEA access, you would open an EASession here.
        }
    }

    /// Get the currently selected device info
    var selectedDevice: GPSDeviceInfo? {
        guard let id = selectedDeviceId else { return connectedDevices.first }
        return connectedDevices.first { $0.id == id }
    }

    // MARK: - Notifications

    @objc private func accessoryConnected(_ notification: Notification) {
        print("GPSDeviceManager: Accessory connected")
        refreshConnectedDevices()
    }

    @objc private func accessoryDisconnected(_ notification: Notification) {
        print("GPSDeviceManager: Accessory disconnected")
        refreshConnectedDevices()
    }
}
#endif
