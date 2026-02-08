import { ISOXMLManager, TAGS } from 'isoxml'
import {
    Partfield,
    GuidanceGroup,
    GuidancePattern,
    GuidancePatternGuidancePatternTypeEnum,
    GuidancePatternGuidancePatternExtensionEnum,
    GuidancePatternGuidancePatternPropagationDirectionEnum,
    GuidancePatternGuidancePatternGNSSMethodEnum,
    LineString,
    LineStringLineStringTypeEnum,
    Point,
    PointPointTypeEnum,
    Polygon,
    PolygonPolygonTypeEnum
} from 'isoxml'
import { calculateBearing } from './guidanceUtils'
import type { Field } from '../commonStores/fieldState'

/**
 * Export guidance pattern (AB line) as ISOXML ZIP file
 * Structure:
 *   Partfield (container for guidance)
 *     -> GuidanceGroup
 *         -> GuidancePattern (AB line type)
 *             -> LineString (with A and B points)
 */
export async function exportGuidanceAsIsoxml(
    pointA: [number, number],  // [lng, lat]
    pointB: [number, number],  // [lng, lat]
    name: string,
    swathWidth?: number,
    numSwathsLeft?: number,
    numSwathsRight?: number
): Promise<Uint8Array> {
    // Create a new ISOXML manager
    const isoxmlManager = new ISOXMLManager({
        fmisTitle: 'Guidance Export',
        fmisVersion: '1.0',
        version: 4
    })

    // Calculate heading from A to B
    const heading = calculateBearing(pointA, pointB)

    // Create Point A
    const pointAEntity = isoxmlManager.createEntityFromAttributes<Point>(TAGS.Point, {
        PointType: PointPointTypeEnum.GuidanceReferenceA,
        PointDesignator: 'A',
        PointNorth: pointA[1],  // latitude
        PointEast: pointA[0]    // longitude
    })

    // Create Point B
    const pointBEntity = isoxmlManager.createEntityFromAttributes<Point>(TAGS.Point, {
        PointType: PointPointTypeEnum.GuidanceReferenceB,
        PointDesignator: 'B',
        PointNorth: pointB[1],  // latitude
        PointEast: pointB[0]    // longitude
    })

    // Create LineString for the guidance pattern
    const lineString = isoxmlManager.createEntityFromAttributes<LineString>(TAGS.LineString, {
        LineStringType: LineStringLineStringTypeEnum.GuidancePattern,
        LineStringDesignator: name,
        LineStringWidth: swathWidth ? Math.round(swathWidth * 1000) : undefined, // mm
        Point: [pointAEntity, pointBEntity]
    })

    // Create GuidancePattern (AB line type)
    const guidancePattern = isoxmlManager.createEntityFromAttributes<GuidancePattern>(TAGS.GuidancePattern, {
        GuidancePatternDesignator: name,
        GuidancePatternType: GuidancePatternGuidancePatternTypeEnum.AB,
        GuidancePatternHeading: heading,
        GuidancePatternExtension: GuidancePatternGuidancePatternExtensionEnum.FromBothFirstAndLastPoint,
        GuidancePatternPropagationDirection: GuidancePatternGuidancePatternPropagationDirectionEnum.BothDirections,
        GuidancePatternGNSSMethod: GuidancePatternGuidancePatternGNSSMethodEnum.DesktopGeneratedData,
        NumberOfSwathsLeft: numSwathsLeft,
        NumberOfSwathsRight: numSwathsRight,
        LineString: [lineString]
    })
    isoxmlManager.registerEntity(guidancePattern)

    // Create GuidanceGroup containing the pattern
    const guidanceGroup = isoxmlManager.createEntityFromAttributes<GuidanceGroup>(TAGS.GuidanceGroup, {
        GuidanceGroupDesignator: `${name} Group`,
        GuidancePattern: [guidancePattern]
    })
    isoxmlManager.registerEntity(guidanceGroup)

    // Create a Partfield to hold the guidance group
    // (GuidanceGroup must be a child of Partfield in ISOXML v4)
    const partfield = isoxmlManager.createEntityFromAttributes<Partfield>(TAGS.Partfield, {
        PartfieldDesignator: `${name} Field`,
        PartfieldArea: 0, // Unknown area
        GuidanceGroup: [guidanceGroup]
    })
    isoxmlManager.registerEntity(partfield)

    // Add partfield to the root element
    if (!isoxmlManager.rootElement.attributes.Partfield) {
        isoxmlManager.rootElement.attributes.Partfield = []
    }
    isoxmlManager.rootElement.attributes.Partfield.push(partfield)

    // Export as ZIP
    return isoxmlManager.saveISOXML()
}

/**
 * Export a field boundary as ISOXML Partfield with Polygon
 */
export async function exportBoundaryAsIsoxml(
    coordinates: [number, number][],  // Array of [lng, lat] points forming the polygon
    name: string
): Promise<Uint8Array> {
    const isoxml = await import('isoxml')
    const { PolygonPolygonTypeEnum } = isoxml

    // Create a new ISOXML manager
    const isoxmlManager = new isoxml.ISOXMLManager({
        fmisTitle: 'Boundary Export',
        fmisVersion: '1.0',
        version: 4
    })

    // Create points for the polygon exterior ring
    const points = coordinates.map((coord) => {
        return isoxmlManager.createEntityFromAttributes(isoxml.TAGS.Point, {
            PointType: PointPointTypeEnum.PartfieldReferencePoint,
            PointNorth: coord[1],  // latitude
            PointEast: coord[0]    // longitude
        })
    })

    // Create LineString for exterior ring
    const exteriorRing = isoxmlManager.createEntityFromAttributes(isoxml.TAGS.LineString, {
        LineStringType: LineStringLineStringTypeEnum.PolygonExterior,
        LineStringDesignator: `${name} Boundary`,
        Point: points
    })

    // Create Polygon
    const polygon = isoxmlManager.createEntityFromAttributes(isoxml.TAGS.Polygon, {
        PolygonType: PolygonPolygonTypeEnum.PartfieldBoundary,
        PolygonDesignator: name,
        LineString: [exteriorRing]
    })

    // Calculate approximate area in square meters using shoelace formula
    const areaSquareMeters = calculatePolygonArea(coordinates)

    // Create Partfield
    const partfield = isoxmlManager.createEntityFromAttributes(isoxml.TAGS.Partfield, {
        PartfieldDesignator: name,
        PartfieldArea: Math.round(areaSquareMeters), // Area in square meters
        PolygonnonTreatmentZoneonly: [polygon]
    })
    isoxmlManager.registerEntity(partfield)

    // Add partfield to root element
    if (!isoxmlManager.rootElement.attributes.Partfield) {
        isoxmlManager.rootElement.attributes.Partfield = []
    }
    isoxmlManager.rootElement.attributes.Partfield.push(partfield as any)

    // Export as ZIP
    return isoxmlManager.saveISOXML()
}

/**
 * Export a Field with all its AB lines as ISOXML
 */
export async function exportFieldAsIsoxml(field: Field): Promise<Uint8Array> {
    // Create a new ISOXML manager
    const isoxmlManager = new ISOXMLManager({
        fmisTitle: 'Field Export',
        fmisVersion: '1.0',
        version: 4
    })

    // Create guidance patterns for all complete AB lines
    const guidancePatterns: GuidancePattern[] = []

    for (const abLine of field.abLines) {
        if (!abLine.pointA || !abLine.pointB) {
            continue  // Skip incomplete AB lines
        }

        // Calculate heading from A to B
        const heading = calculateBearing(abLine.pointA, abLine.pointB)

        // Create Point A
        const pointAEntity = isoxmlManager.createEntityFromAttributes<Point>(TAGS.Point, {
            PointType: PointPointTypeEnum.GuidanceReferenceA,
            PointDesignator: 'A',
            PointNorth: abLine.pointA[1],  // latitude
            PointEast: abLine.pointA[0]    // longitude
        })

        // Create Point B
        const pointBEntity = isoxmlManager.createEntityFromAttributes<Point>(TAGS.Point, {
            PointType: PointPointTypeEnum.GuidanceReferenceB,
            PointDesignator: 'B',
            PointNorth: abLine.pointB[1],  // latitude
            PointEast: abLine.pointB[0]    // longitude
        })

        // Create LineString for the guidance pattern
        const lineString = isoxmlManager.createEntityFromAttributes<LineString>(TAGS.LineString, {
            LineStringType: LineStringLineStringTypeEnum.GuidancePattern,
            LineStringDesignator: abLine.name,
            LineStringWidth: abLine.swathWidth ? Math.round(abLine.swathWidth * 1000) : undefined, // mm
            Point: [pointAEntity, pointBEntity]
        })

        // Create GuidancePattern (AB line type)
        const guidancePattern = isoxmlManager.createEntityFromAttributes<GuidancePattern>(TAGS.GuidancePattern, {
            GuidancePatternDesignator: abLine.name,
            GuidancePatternType: GuidancePatternGuidancePatternTypeEnum.AB,
            GuidancePatternHeading: heading,
            GuidancePatternExtension: GuidancePatternGuidancePatternExtensionEnum.FromBothFirstAndLastPoint,
            GuidancePatternPropagationDirection: GuidancePatternGuidancePatternPropagationDirectionEnum.BothDirections,
            GuidancePatternGNSSMethod: GuidancePatternGuidancePatternGNSSMethodEnum.DesktopGeneratedData,
            NumberOfSwathsLeft: abLine.numSwathsLeft,
            NumberOfSwathsRight: abLine.numSwathsRight,
            LineString: [lineString]
        })
        isoxmlManager.registerEntity(guidancePattern)
        guidancePatterns.push(guidancePattern)
    }

    if (guidancePatterns.length === 0) {
        throw new Error('No complete AB lines to export')
    }

    // Create GuidanceGroup containing all patterns
    const guidanceGroup = isoxmlManager.createEntityFromAttributes<GuidanceGroup>(TAGS.GuidanceGroup, {
        GuidanceGroupDesignator: `${field.name} Guidance`,
        GuidancePattern: guidancePatterns
    })
    isoxmlManager.registerEntity(guidanceGroup)

    // Create boundary polygon if field has boundary
    let boundaryPolygon: Polygon | undefined
    let fieldArea = 0

    if (field.boundary && field.boundary.length >= 3) {
        // Create points for the boundary
        const boundaryPoints = field.boundary.map((coord, index) => {
            return isoxmlManager.createEntityFromAttributes<Point>(TAGS.Point, {
                PointType: PointPointTypeEnum.PartfieldReferencePoint,
                PointDesignator: `P${index + 1}`,
                PointNorth: coord[1],  // latitude
                PointEast: coord[0]    // longitude
            })
        })

        // Create LineString for exterior ring
        const exteriorRing = isoxmlManager.createEntityFromAttributes<LineString>(TAGS.LineString, {
            LineStringType: LineStringLineStringTypeEnum.PolygonExterior,
            LineStringDesignator: `${field.name} Boundary`,
            Point: boundaryPoints
        })

        // Create Polygon
        boundaryPolygon = isoxmlManager.createEntityFromAttributes<Polygon>(TAGS.Polygon, {
            PolygonType: PolygonPolygonTypeEnum.PartfieldBoundary,
            PolygonDesignator: field.name,
            LineString: [exteriorRing]
        })

        // Calculate area
        fieldArea = Math.round(calculatePolygonArea(field.boundary))
    }

    // Create the Partfield with boundary and guidance
    const partfieldAttrs: any = {
        PartfieldDesignator: field.name,
        PartfieldArea: fieldArea,
        GuidanceGroup: [guidanceGroup]
    }

    // Add polygon if we have a boundary
    if (boundaryPolygon) {
        partfieldAttrs.PolygonnonTreatmentZoneonly = [boundaryPolygon]
    }

    const partfield = isoxmlManager.createEntityFromAttributes<Partfield>(TAGS.Partfield, partfieldAttrs)
    isoxmlManager.registerEntity(partfield)

    // Add partfield to the root element
    if (!isoxmlManager.rootElement.attributes.Partfield) {
        isoxmlManager.rootElement.attributes.Partfield = []
    }
    isoxmlManager.rootElement.attributes.Partfield.push(partfield)

    // Export as ZIP
    return isoxmlManager.saveISOXML()
}

/**
 * Calculate polygon area using spherical excess formula (approximate)
 */
function calculatePolygonArea(coordinates: [number, number][]): number {
    const EARTH_RADIUS = 6371000 // meters

    if (coordinates.length < 3) {
        return 0
    }

    // Convert to radians
    const toRad = (deg: number) => deg * Math.PI / 180

    // Shoelace formula adapted for lat/lng (approximate for small areas)
    let area = 0
    for (let i = 0; i < coordinates.length; i++) {
        const j = (i + 1) % coordinates.length
        const lat1 = toRad(coordinates[i][1])
        const lng1 = toRad(coordinates[i][0])
        const lat2 = toRad(coordinates[j][1])
        const lng2 = toRad(coordinates[j][0])

        area += (lng2 - lng1) * (2 + Math.sin(lat1) + Math.sin(lat2))
    }

    area = Math.abs(area * EARTH_RADIUS * EARTH_RADIUS / 2)
    return area
}
