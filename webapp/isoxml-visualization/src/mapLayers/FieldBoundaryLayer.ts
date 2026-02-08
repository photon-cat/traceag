import { CompositeLayer } from '@deck.gl/core'
import { GeoJsonLayer, ScatterplotLayer } from '@deck.gl/layers'
import type { Field } from '../commonStores/fieldState'

interface FieldBoundaryLayerProps {
    id: string
    fields: Field[]
    activeFieldId: string | null
    boundaryDrawingPoints: [number, number][]
    isDrawingBoundary: boolean
}

export default class FieldBoundaryLayer extends CompositeLayer<any> {
    static layerName = 'FieldBoundaryLayer'
    static defaultProps = {
        fields: [],
        activeFieldId: null,
        boundaryDrawingPoints: [],
        isDrawingBoundary: false
    }

    renderLayers() {
        const props = this.props as FieldBoundaryLayerProps
        const { fields, activeFieldId, boundaryDrawingPoints, isDrawingBoundary } = props
        const layers: any[] = []

        // Render completed field boundaries
        fields.forEach(field => {
            if (field.boundary && field.boundary.length >= 3) {
                const isActive = field.id === activeFieldId

                // Create GeoJSON polygon
                const geoJSON = {
                    type: 'FeatureCollection',
                    features: [{
                        type: 'Feature',
                        properties: { fieldId: field.id, name: field.name },
                        geometry: {
                            type: 'Polygon',
                            coordinates: [field.boundary]
                        }
                    }]
                }

                layers.push(
                    new GeoJsonLayer({
                        id: `${props.id}-boundary-${field.id}`,
                        data: geoJSON,
                        stroked: true,
                        filled: true,
                        getFillColor: isActive ? [100, 149, 237, 40] : [255, 165, 0, 30],  // cornflowerblue / orange
                        getLineColor: isActive ? [100, 149, 237, 255] : [255, 165, 0, 200],
                        getLineWidth: isActive ? 3 : 2,
                        lineWidthUnits: 'pixels'
                    })
                )
            }
        })

        // Render boundary drawing in progress
        if (isDrawingBoundary && boundaryDrawingPoints.length > 0) {
            // Points
            layers.push(
                new ScatterplotLayer({
                    id: `${props.id}-drawing-points`,
                    data: boundaryDrawingPoints.map((point, index) => ({
                        position: point,
                        index
                    })),
                    getPosition: (d: any) => d.position,
                    getFillColor: (d: any) => d.index === 0 ? [0, 200, 0, 255] : [255, 100, 0, 255],
                    getRadius: (d: any) => d.index === 0 ? 10 : 8,
                    radiusUnits: 'pixels',
                    stroked: true,
                    getLineColor: [255, 255, 255, 255],
                    getLineWidth: 2,
                    lineWidthUnits: 'pixels'
                })
            )

            // Lines connecting points
            if (boundaryDrawingPoints.length >= 2) {
                const lineFeatures = []
                for (let i = 0; i < boundaryDrawingPoints.length - 1; i++) {
                    lineFeatures.push({
                        type: 'Feature',
                        properties: {},
                        geometry: {
                            type: 'LineString',
                            coordinates: [boundaryDrawingPoints[i], boundaryDrawingPoints[i + 1]]
                        }
                    })
                }

                // Closing line (dashed) - from last point to first
                if (boundaryDrawingPoints.length >= 3) {
                    lineFeatures.push({
                        type: 'Feature',
                        properties: { closing: true },
                        geometry: {
                            type: 'LineString',
                            coordinates: [
                                boundaryDrawingPoints[boundaryDrawingPoints.length - 1],
                                boundaryDrawingPoints[0]
                            ]
                        }
                    })
                }

                layers.push(
                    new GeoJsonLayer({
                        id: `${props.id}-drawing-lines`,
                        data: {
                            type: 'FeatureCollection',
                            features: lineFeatures.filter(f => !f.properties.closing)
                        },
                        stroked: true,
                        filled: false,
                        getLineColor: [255, 100, 0, 255],
                        getLineWidth: 2,
                        lineWidthUnits: 'pixels'
                    })
                )

                // Closing line (different style)
                const closingFeatures = lineFeatures.filter(f => f.properties.closing)
                if (closingFeatures.length > 0) {
                    layers.push(
                        new GeoJsonLayer({
                            id: `${props.id}-drawing-closing`,
                            data: {
                                type: 'FeatureCollection',
                                features: closingFeatures
                            },
                            stroked: true,
                            filled: false,
                            getLineColor: [255, 100, 0, 128],
                            getLineWidth: 2,
                            lineWidthUnits: 'pixels'
                        })
                    )
                }

                // Preview polygon fill
                if (boundaryDrawingPoints.length >= 3) {
                    const previewGeoJSON = {
                        type: 'FeatureCollection',
                        features: [{
                            type: 'Feature',
                            properties: {},
                            geometry: {
                                type: 'Polygon',
                                coordinates: [[...boundaryDrawingPoints, boundaryDrawingPoints[0]]]
                            }
                        }]
                    }

                    layers.push(
                        new GeoJsonLayer({
                            id: `${props.id}-drawing-preview`,
                            data: previewGeoJSON,
                            stroked: false,
                            filled: true,
                            getFillColor: [255, 100, 0, 30]
                        })
                    )
                }
            }
        }

        return layers
    }
}
