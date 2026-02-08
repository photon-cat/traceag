// Geodetic utilities for AB line guidance calculations

const EARTH_RADIUS = 6371000 // meters

/**
 * Convert degrees to radians
 */
export function toRadians(degrees: number): number {
    return degrees * (Math.PI / 180)
}

/**
 * Convert radians to degrees
 */
export function toDegrees(radians: number): number {
    return radians * (180 / Math.PI)
}

/**
 * Calculate bearing from point A to point B
 * @param pointA [lng, lat] in degrees
 * @param pointB [lng, lat] in degrees
 * @returns bearing in degrees (0-360)
 */
export function calculateBearing(pointA: [number, number], pointB: [number, number]): number {
    const lat1 = toRadians(pointA[1])
    const lat2 = toRadians(pointB[1])
    const dLng = toRadians(pointB[0] - pointA[0])

    const y = Math.sin(dLng) * Math.cos(lat2)
    const x = Math.cos(lat1) * Math.sin(lat2) - Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLng)

    let bearing = toDegrees(Math.atan2(y, x))
    return (bearing + 360) % 360
}

/**
 * Calculate distance between two points using Haversine formula
 * @param pointA [lng, lat] in degrees
 * @param pointB [lng, lat] in degrees
 * @returns distance in meters
 */
export function calculateDistance(pointA: [number, number], pointB: [number, number]): number {
    const lat1 = toRadians(pointA[1])
    const lat2 = toRadians(pointB[1])
    const dLat = toRadians(pointB[1] - pointA[1])
    const dLng = toRadians(pointB[0] - pointA[0])

    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
              Math.cos(lat1) * Math.cos(lat2) *
              Math.sin(dLng / 2) * Math.sin(dLng / 2)
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

    return EARTH_RADIUS * c
}

/**
 * Calculate destination point given start point, bearing, and distance
 * @param start [lng, lat] in degrees
 * @param bearing in degrees
 * @param distance in meters
 * @returns [lng, lat] destination point
 */
export function destinationPoint(start: [number, number], bearing: number, distance: number): [number, number] {
    const lat1 = toRadians(start[1])
    const lng1 = toRadians(start[0])
    const bearingRad = toRadians(bearing)
    const angularDistance = distance / EARTH_RADIUS

    const lat2 = Math.asin(
        Math.sin(lat1) * Math.cos(angularDistance) +
        Math.cos(lat1) * Math.sin(angularDistance) * Math.cos(bearingRad)
    )

    const lng2 = lng1 + Math.atan2(
        Math.sin(bearingRad) * Math.sin(angularDistance) * Math.cos(lat1),
        Math.cos(angularDistance) - Math.sin(lat1) * Math.sin(lat2)
    )

    return [toDegrees(lng2), toDegrees(lat2)]
}

/**
 * Extend line beyond its endpoints
 * @param pointA [lng, lat] start point
 * @param pointB [lng, lat] end point
 * @param extensionMeters distance to extend in each direction
 * @returns [extendedA, extendedB] new endpoints
 */
export function extendLine(
    pointA: [number, number],
    pointB: [number, number],
    extensionMeters: number
): [[number, number], [number, number]] {
    const bearing = calculateBearing(pointA, pointB)
    const reverseBearing = (bearing + 180) % 360

    const extendedA = destinationPoint(pointA, reverseBearing, extensionMeters)
    const extendedB = destinationPoint(pointB, bearing, extensionMeters)

    return [extendedA, extendedB]
}

/**
 * Offset a line perpendicular to its direction
 * @param pointA [lng, lat] start point
 * @param pointB [lng, lat] end point
 * @param offsetMeters positive = right side, negative = left side
 * @returns [offsetA, offsetB] offset endpoints
 */
export function offsetLine(
    pointA: [number, number],
    pointB: [number, number],
    offsetMeters: number
): [[number, number], [number, number]] {
    const bearing = calculateBearing(pointA, pointB)
    // Perpendicular bearing (right side is +90 degrees)
    const perpBearing = (bearing + 90) % 360

    const offsetA = destinationPoint(pointA, perpBearing, offsetMeters)
    const offsetB = destinationPoint(pointB, perpBearing, offsetMeters)

    return [offsetA, offsetB]
}

/**
 * Generate parallel swath lines
 * @param pointA [lng, lat] AB line start
 * @param pointB [lng, lat] AB line end
 * @param swathWidth width of each swath in meters
 * @param numLeft number of swaths to the left
 * @param numRight number of swaths to the right
 * @param extensionMeters how far to extend lines beyond A-B
 * @returns array of swath lines, each as [[startLng, startLat], [endLng, endLat]]
 */
export function generateSwathLines(
    pointA: [number, number],
    pointB: [number, number],
    swathWidth: number,
    numLeft: number,
    numRight: number,
    extensionMeters: number = 500
): Array<[[number, number], [number, number]]> {
    const swaths: Array<[[number, number], [number, number]]> = []

    // Extend the base AB line
    const [extA, extB] = extendLine(pointA, pointB, extensionMeters)

    // Generate left swaths (negative offset)
    for (let i = 1; i <= numLeft; i++) {
        const offset = -i * swathWidth
        const [swathA, swathB] = offsetLine(extA, extB, offset)
        swaths.push([swathA, swathB])
    }

    // Generate right swaths (positive offset)
    for (let i = 1; i <= numRight; i++) {
        const offset = i * swathWidth
        const [swathA, swathB] = offsetLine(extA, extB, offset)
        swaths.push([swathA, swathB])
    }

    return swaths
}

/**
 * Create GeoJSON FeatureCollection for AB line and swaths
 */
export function createABLineGeoJSON(
    pointA: [number, number],
    pointB: [number, number],
    swathWidth: number,
    numLeft: number,
    numRight: number,
    showSwaths: boolean,
    extensionMeters: number = 500
): GeoJSON.FeatureCollection {
    const features: GeoJSON.Feature[] = []

    // Extend main AB line
    const [extA, extB] = extendLine(pointA, pointB, extensionMeters)

    // Main AB line feature
    features.push({
        type: 'Feature',
        properties: { type: 'abline' },
        geometry: {
            type: 'LineString',
            coordinates: [extA, extB]
        }
    })

    // Point A marker
    features.push({
        type: 'Feature',
        properties: { type: 'pointA', label: 'A' },
        geometry: {
            type: 'Point',
            coordinates: pointA
        }
    })

    // Point B marker
    features.push({
        type: 'Feature',
        properties: { type: 'pointB', label: 'B' },
        geometry: {
            type: 'Point',
            coordinates: pointB
        }
    })

    // Swath lines
    if (showSwaths) {
        const swaths = generateSwathLines(pointA, pointB, swathWidth, numLeft, numRight, extensionMeters)
        swaths.forEach((swath, index) => {
            features.push({
                type: 'Feature',
                properties: { type: 'swath', index },
                geometry: {
                    type: 'LineString',
                    coordinates: swath
                }
            })
        })
    }

    return {
        type: 'FeatureCollection',
        features
    }
}

// Common swath width presets
export const SWATH_PRESETS = [
    { label: '30 ft (9.1m)', value: 9.144 },
    { label: '40 ft (12.2m)', value: 12.192 },
    { label: '60 ft (18.3m)', value: 18.288 },
    { label: '90 ft (27.4m)', value: 27.432 },
    { label: '120 ft (36.6m)', value: 36.576 }
]

// Convert meters to feet
export function metersToFeet(meters: number): number {
    return meters * 3.28084
}

// Convert feet to meters
export function feetToMeters(feet: number): number {
    return feet / 3.28084
}
