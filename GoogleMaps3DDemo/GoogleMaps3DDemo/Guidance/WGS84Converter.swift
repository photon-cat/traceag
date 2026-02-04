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

import CoreLocation

/// Utility for converting between WGS84 lat/lon and local tangent-plane meters.
struct WGS84Converter {
    let origin: CLLocationCoordinate2D

    /// Returns meters per degree of latitude/longitude at the provided latitude (WGS84).
    static func metersPerDegree(atLatitude latitude: Double) -> (lat: Double, lon: Double) {
        let latRad = latitude * .pi / 180.0
        let metersPerDegreeLat = 111132.954
            - 559.822 * cos(2.0 * latRad)
            + 1.175 * cos(4.0 * latRad)
            - 0.0023 * cos(6.0 * latRad)
        let metersPerDegreeLon = 111132.954 * cos(latRad)
            - 93.5 * cos(3.0 * latRad)
            + 0.118 * cos(5.0 * latRad)
        return (lat: metersPerDegreeLat, lon: metersPerDegreeLon)
    }

    func wgs84ToLocal(_ coord: CLLocationCoordinate2D) -> (x: Double, z: Double) {
        let dLat = coord.latitude - origin.latitude
        let dLon = coord.longitude - origin.longitude
        let meters = Self.metersPerDegree(atLatitude: origin.latitude)
        let x = dLon * meters.lon
        let z = dLat * meters.lat
        return (x, z)
    }

    func localToWGS84(x: Double, z: Double) -> CLLocationCoordinate2D {
        let meters = Self.metersPerDegree(atLatitude: origin.latitude)
        let lat = origin.latitude + z / meters.lat
        let lon = origin.longitude + x / meters.lon
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}
