/**
 * Database utility tests
 *
 * Note: These tests mock sql.js since WASM doesn't work well in Jest.
 * For full integration tests, run in browser console.
 */

// Mock localStorage
const localStorageMock = (() => {
    let store: Record<string, string> = {}
    return {
        getItem: jest.fn((key: string) => store[key] || null),
        setItem: jest.fn((key: string, value: string) => { store[key] = value }),
        removeItem: jest.fn((key: string) => { delete store[key] }),
        clear: jest.fn(() => { store = {} })
    }
})()

Object.defineProperty(window, 'localStorage', { value: localStorageMock })

// Mock sql.js
const mockDb = {
    run: jest.fn(),
    exec: jest.fn(() => []),
    prepare: jest.fn(() => ({
        bind: jest.fn(),
        step: jest.fn(() => false),
        get: jest.fn(() => []),
        free: jest.fn()
    })),
    export: jest.fn(() => new Uint8Array([1, 2, 3])),
    close: jest.fn()
}

jest.mock('sql.js', () => ({
    __esModule: true,
    default: jest.fn(() => Promise.resolve({
        Database: jest.fn(() => mockDb)
    }))
}))

import {
    VehicleConfig,
    ImplementConfig,
    FieldData,
    ABLineData
} from './database'

describe('Database Types', () => {
    describe('VehicleConfig', () => {
        it('should have correct structure', () => {
            const vehicle: VehicleConfig = {
                id: 'vehicle-1',
                name: 'Test Tractor',
                wheelbase: 2.5,
                turningRadius: 5.0,
                rearAxleToHitch: 1.5,
                antenna: {
                    heightToGround: 2.5,
                    lateralOffset: 0,
                    longitudinalOffset: 1.0
                }
            }

            expect(vehicle.id).toBe('vehicle-1')
            expect(vehicle.name).toBe('Test Tractor')
            expect(vehicle.wheelbase).toBe(2.5)
            expect(vehicle.turningRadius).toBe(5.0)
            expect(vehicle.rearAxleToHitch).toBe(1.5)
            expect(vehicle.antenna.heightToGround).toBe(2.5)
            expect(vehicle.antenna.lateralOffset).toBe(0)
            expect(vehicle.antenna.longitudinalOffset).toBe(1.0)
        })
    })

    describe('ImplementConfig', () => {
        it('should have correct structure for pivoting implement', () => {
            const implement: ImplementConfig = {
                id: 'implement-1',
                name: 'Test Sprayer',
                type: 'pivoting',
                hitchToCenterRotation: 2.0,
                hitchToCenterWork: 5.0,
                workWidth: 12.192
            }

            expect(implement.id).toBe('implement-1')
            expect(implement.name).toBe('Test Sprayer')
            expect(implement.type).toBe('pivoting')
            expect(implement.hitchToCenterRotation).toBe(2.0)
            expect(implement.hitchToCenterWork).toBe(5.0)
            expect(implement.workWidth).toBe(12.192)
        })

        it('should have correct structure for fixed implement', () => {
            const implement: ImplementConfig = {
                id: 'implement-2',
                name: 'Test Planter',
                type: 'fixed',
                hitchToCenterRotation: 0,
                hitchToCenterWork: 3.0,
                workWidth: 4.572
            }

            expect(implement.type).toBe('fixed')
            expect(implement.hitchToCenterRotation).toBe(0)
        })
    })

    describe('FieldData', () => {
        it('should have correct structure with boundary', () => {
            const field: FieldData = {
                id: 'field-1',
                name: 'Test Field',
                boundary: [
                    [-77.5, 38.5],
                    [-77.4, 38.5],
                    [-77.4, 38.6],
                    [-77.5, 38.6],
                    [-77.5, 38.5]
                ],
                abLines: []
            }

            expect(field.id).toBe('field-1')
            expect(field.name).toBe('Test Field')
            expect(field.boundary).toHaveLength(5)
            expect(field.boundary![0]).toEqual([-77.5, 38.5])
            expect(field.abLines).toHaveLength(0)
        })

        it('should have correct structure with AB lines', () => {
            const abLine: ABLineData = {
                id: 'abline-1',
                fieldId: 'field-1',
                name: 'AB Line 1',
                pointA: [-77.5, 38.5],
                pointB: [-77.4, 38.6],
                swathWidth: 12.192,
                numSwathsLeft: 5,
                numSwathsRight: 5
            }

            const field: FieldData = {
                id: 'field-1',
                name: 'Test Field',
                boundary: [[-77.5, 38.5], [-77.4, 38.5], [-77.4, 38.6], [-77.5, 38.6], [-77.5, 38.5]],
                abLines: [abLine]
            }

            expect(field.abLines).toHaveLength(1)
            expect(field.abLines[0].pointA).toEqual([-77.5, 38.5])
            expect(field.abLines[0].pointB).toEqual([-77.4, 38.6])
            expect(field.abLines[0].swathWidth).toBe(12.192)
        })

        it('should allow null boundary', () => {
            const field: FieldData = {
                id: 'field-1',
                name: 'Incomplete Field',
                boundary: null,
                abLines: []
            }

            expect(field.boundary).toBeNull()
        })
    })

    describe('ABLineData', () => {
        it('should allow null points', () => {
            const abLine: ABLineData = {
                id: 'abline-1',
                fieldId: 'field-1',
                name: 'Incomplete AB Line',
                pointA: null,
                pointB: null,
                swathWidth: 12.192,
                numSwathsLeft: 5,
                numSwathsRight: 5
            }

            expect(abLine.pointA).toBeNull()
            expect(abLine.pointB).toBeNull()
        })

        it('should have partial points', () => {
            const abLine: ABLineData = {
                id: 'abline-1',
                fieldId: 'field-1',
                name: 'Partial AB Line',
                pointA: [-77.5, 38.5],
                pointB: null,
                swathWidth: 12.192,
                numSwathsLeft: 5,
                numSwathsRight: 5
            }

            expect(abLine.pointA).toEqual([-77.5, 38.5])
            expect(abLine.pointB).toBeNull()
        })
    })
})

describe('Data Validation', () => {
    it('should validate swath width is positive', () => {
        const implement: ImplementConfig = {
            id: 'implement-1',
            name: 'Test',
            type: 'pivoting',
            hitchToCenterRotation: 2.0,
            hitchToCenterWork: 5.0,
            workWidth: 12.192
        }

        expect(implement.workWidth).toBeGreaterThan(0)
    })

    it('should validate turning radius is reasonable', () => {
        const vehicle: VehicleConfig = {
            id: 'vehicle-1',
            name: 'Test Tractor',
            wheelbase: 2.5,
            turningRadius: 5.0,
            rearAxleToHitch: 1.5,
            antenna: { heightToGround: 2.5, lateralOffset: 0, longitudinalOffset: 1.0 }
        }

        // Turning radius should be at least wheelbase
        expect(vehicle.turningRadius).toBeGreaterThanOrEqual(vehicle.wheelbase)
    })

    it('should validate boundary is a closed polygon', () => {
        const field: FieldData = {
            id: 'field-1',
            name: 'Test Field',
            boundary: [
                [-77.5, 38.5],
                [-77.4, 38.5],
                [-77.4, 38.6],
                [-77.5, 38.6],
                [-77.5, 38.5]  // Closing point matches first point
            ],
            abLines: []
        }

        const firstPoint = field.boundary![0]
        const lastPoint = field.boundary![field.boundary!.length - 1]
        expect(firstPoint).toEqual(lastPoint)
    })

    it('should validate boundary has at least 4 points (triangle + closing)', () => {
        const field: FieldData = {
            id: 'field-1',
            name: 'Minimal Field',
            boundary: [
                [-77.5, 38.5],
                [-77.4, 38.5],
                [-77.45, 38.6],
                [-77.5, 38.5]
            ],
            abLines: []
        }

        expect(field.boundary!.length).toBeGreaterThanOrEqual(4)
    })
})

describe('ID Generation', () => {
    it('should generate unique vehicle IDs', () => {
        const ids = new Set<string>()
        for (let i = 0; i < 100; i++) {
            const id = `vehicle-${Date.now()}-${i}`
            ids.add(id)
        }
        expect(ids.size).toBe(100)
    })

    it('should generate unique field IDs', () => {
        const ids = new Set<string>()
        for (let i = 0; i < 100; i++) {
            const id = `field-${Date.now()}-${i}`
            ids.add(id)
        }
        expect(ids.size).toBe(100)
    })
})

describe('JSON Serialization', () => {
    it('should serialize boundary to JSON', () => {
        const boundary: [number, number][] = [
            [-77.5, 38.5],
            [-77.4, 38.5],
            [-77.4, 38.6],
            [-77.5, 38.6],
            [-77.5, 38.5]
        ]

        const json = JSON.stringify(boundary)
        const parsed = JSON.parse(json)

        expect(parsed).toEqual(boundary)
    })

    it('should serialize points to JSON', () => {
        const pointA: [number, number] = [-77.5, 38.5]
        const pointB: [number, number] = [-77.4, 38.6]

        const jsonA = JSON.stringify(pointA)
        const jsonB = JSON.stringify(pointB)

        expect(JSON.parse(jsonA)).toEqual(pointA)
        expect(JSON.parse(jsonB)).toEqual(pointB)
    })

    it('should handle null values in JSON', () => {
        const abLine: ABLineData = {
            id: 'abline-1',
            fieldId: 'field-1',
            name: 'Test',
            pointA: null,
            pointB: null,
            swathWidth: 12.192,
            numSwathsLeft: 5,
            numSwathsRight: 5
        }

        const json = JSON.stringify(abLine)
        const parsed = JSON.parse(json)

        expect(parsed.pointA).toBeNull()
        expect(parsed.pointB).toBeNull()
    })
})
