import { CompositeLayer } from '@deck.gl/core'
import { GeoJsonLayer, ScatterplotLayer, TextLayer } from '@deck.gl/layers'
import { createABLineGeoJSON } from '../utils/guidanceUtils'

interface ABLineLayerProps {
    id: string
    pointA: [number, number] | null
    pointB: [number, number] | null
    swathWidth: number
    numSwathsLeft: number
    numSwathsRight: number
    showSwaths: boolean
}

export default class ABLineLayer extends CompositeLayer<any> {
    static layerName = 'ABLineLayer'
    static defaultProps = {
        pointA: null,
        pointB: null,
        swathWidth: 12,
        numSwathsLeft: 5,
        numSwathsRight: 5,
        showSwaths: true
    }

    renderLayers() {
        const props = this.props as ABLineLayerProps
        const { pointA, pointB, swathWidth, numSwathsLeft, numSwathsRight, showSwaths } = props

        if (!pointA) {
            return []
        }

        // If we only have point A, show just point A marker
        if (!pointB) {
            return [
                new ScatterplotLayer({
                    id: `${props.id}-pointA-only`,
                    data: [{ position: pointA }],
                    getPosition: (d: any) => d.position,
                    getFillColor: [0, 180, 0, 255],
                    getRadius: 12,
                    radiusUnits: 'pixels',
                    stroked: true,
                    getLineColor: [255, 255, 255, 255],
                    getLineWidth: 2,
                    lineWidthUnits: 'pixels'
                }),
                new TextLayer({
                    id: `${props.id}-labelA-only`,
                    data: [{ position: pointA, label: 'A' }],
                    getPosition: (d: any) => d.position,
                    getText: (d: any) => d.label,
                    getColor: [255, 255, 255, 255],
                    getSize: 14,
                    getTextAnchor: 'middle',
                    getAlignmentBaseline: 'center',
                    fontWeight: 'bold'
                })
            ]
        }

        const geoJSON = createABLineGeoJSON(
            pointA,
            pointB,
            swathWidth,
            numSwathsLeft,
            numSwathsRight,
            showSwaths
        )

        // Separate features by type
        const abLineFeature = geoJSON.features.find(f => f.properties?.type === 'abline')
        const swathFeatures = geoJSON.features.filter(f => f.properties?.type === 'swath')
        const pointAFeature = geoJSON.features.find(f => f.properties?.type === 'pointA')
        const pointBFeature = geoJSON.features.find(f => f.properties?.type === 'pointB')

        const layers: any[] = []

        // Swath lines (render first, below main line)
        if (showSwaths && swathFeatures.length > 0) {
            layers.push(
                new GeoJsonLayer({
                    id: `${props.id}-swaths`,
                    data: {
                        type: 'FeatureCollection',
                        features: swathFeatures
                    },
                    stroked: true,
                    filled: false,
                    getLineColor: [0, 180, 0, 128],
                    getLineWidth: 1,
                    lineWidthUnits: 'pixels'
                })
            )
        }

        // Main AB line
        if (abLineFeature) {
            layers.push(
                new GeoJsonLayer({
                    id: `${props.id}-abline`,
                    data: {
                        type: 'FeatureCollection',
                        features: [abLineFeature]
                    },
                    stroked: true,
                    filled: false,
                    getLineColor: [0, 200, 0, 255],
                    getLineWidth: 3,
                    lineWidthUnits: 'pixels'
                })
            )
        }

        // Point A marker (green)
        if (pointAFeature) {
            const coords = (pointAFeature.geometry as GeoJSON.Point).coordinates
            layers.push(
                new ScatterplotLayer({
                    id: `${props.id}-pointA`,
                    data: [{ position: coords }],
                    getPosition: (d: any) => d.position,
                    getFillColor: [0, 180, 0, 255],
                    getRadius: 12,
                    radiusUnits: 'pixels',
                    stroked: true,
                    getLineColor: [255, 255, 255, 255],
                    getLineWidth: 2,
                    lineWidthUnits: 'pixels'
                })
            )
            layers.push(
                new TextLayer({
                    id: `${props.id}-labelA`,
                    data: [{ position: coords, label: 'A' }],
                    getPosition: (d: any) => d.position,
                    getText: (d: any) => d.label,
                    getColor: [255, 255, 255, 255],
                    getSize: 14,
                    getTextAnchor: 'middle',
                    getAlignmentBaseline: 'center',
                    fontWeight: 'bold'
                })
            )
        }

        // Point B marker (red)
        if (pointBFeature) {
            const coords = (pointBFeature.geometry as GeoJSON.Point).coordinates
            layers.push(
                new ScatterplotLayer({
                    id: `${props.id}-pointB`,
                    data: [{ position: coords }],
                    getPosition: (d: any) => d.position,
                    getFillColor: [200, 0, 0, 255],
                    getRadius: 12,
                    radiusUnits: 'pixels',
                    stroked: true,
                    getLineColor: [255, 255, 255, 255],
                    getLineWidth: 2,
                    lineWidthUnits: 'pixels'
                })
            )
            layers.push(
                new TextLayer({
                    id: `${props.id}-labelB`,
                    data: [{ position: coords, label: 'B' }],
                    getPosition: (d: any) => d.position,
                    getText: (d: any) => d.label,
                    getColor: [255, 255, 255, 255],
                    getSize: 14,
                    getTextAnchor: 'middle',
                    getAlignmentBaseline: 'center',
                    fontWeight: 'bold'
                })
            )
        }

        return layers
    }
}
