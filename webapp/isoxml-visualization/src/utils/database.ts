/**
 * Database utility for equipment configuration persistence using sql.js
 * Stores data in localStorage as base64-encoded SQLite database
 */

import initSqlJs, { Database } from 'sql.js'

const DB_STORAGE_KEY = 'isoxml_equipment_db'

// Types
export interface AntennaConfig {
    heightToGround: number
    lateralOffset: number
    longitudinalOffset: number
}

export interface VehicleConfig {
    id: string
    name: string
    wheelbase: number
    turningRadius: number
    rearAxleToHitch: number
    antenna: AntennaConfig
}

export interface ImplementConfig {
    id: string
    name: string
    type: 'pivoting' | 'fixed'
    hitchToCenterRotation: number
    hitchToCenterWork: number
    workWidth: number
}

export interface ABLineData {
    id: string
    fieldId: string
    name: string
    pointA: [number, number] | null
    pointB: [number, number] | null
    swathWidth: number
    numSwathsLeft: number
    numSwathsRight: number
}

export interface FieldData {
    id: string
    name: string
    boundary: [number, number][] | null
    abLines: ABLineData[]
}

// Default presets
const DEFAULT_VEHICLES: VehicleConfig[] = [
    {
        id: 'vehicle-preset-1',
        name: 'Generic Tractor',
        wheelbase: 2.5,
        turningRadius: 5.0,
        rearAxleToHitch: 1.5,
        antenna: { heightToGround: 2.5, lateralOffset: 0, longitudinalOffset: 1.0 }
    },
    {
        id: 'vehicle-preset-2',
        name: 'Large Row Crop Tractor',
        wheelbase: 3.0,
        turningRadius: 6.0,
        rearAxleToHitch: 1.8,
        antenna: { heightToGround: 3.0, lateralOffset: 0, longitudinalOffset: 1.2 }
    }
]

const DEFAULT_IMPLEMENTS: ImplementConfig[] = [
    {
        id: 'implement-preset-1',
        name: '40ft Sprayer',
        type: 'pivoting',
        hitchToCenterRotation: 2.0,
        hitchToCenterWork: 5.0,
        workWidth: 12.192
    },
    {
        id: 'implement-preset-2',
        name: '60ft Sprayer',
        type: 'pivoting',
        hitchToCenterRotation: 2.5,
        hitchToCenterWork: 6.0,
        workWidth: 18.288
    },
    {
        id: 'implement-preset-3',
        name: '6-Row Planter',
        type: 'fixed',
        hitchToCenterRotation: 0,
        hitchToCenterWork: 3.0,
        workWidth: 4.572
    }
]

let db: Database | null = null
let sqlPromise: Promise<any> | null = null

/**
 * Initialize sql.js and load/create database
 */
export async function initDatabase(): Promise<void> {
    if (db) return

    if (!sqlPromise) {
        // Load WASM from public folder (copied from node_modules)
        sqlPromise = initSqlJs({
            locateFile: () => '/sql-wasm.wasm'
        })
    }

    const SQL = await sqlPromise

    // Try to load existing database from localStorage
    const savedDb = localStorage.getItem(DB_STORAGE_KEY)
    console.log(`[DB] initDatabase: localStorage has data = ${!!savedDb}`)
    if (savedDb) {
        try {
            const data = Uint8Array.from(atob(savedDb), c => c.charCodeAt(0))
            console.log(`[DB] initDatabase: decoded ${data.length} bytes from localStorage`)
            db = new SQL.Database(data)
            // Verify schema exists (in case of corruption)
            const tables = db.exec("SELECT name FROM sqlite_master WHERE type='table'")
            const tableNames = tables[0]?.values.map(v => v[0]) || []
            console.log(`[DB] initDatabase: found tables: ${tableNames.join(', ')}`)
            if (!tableNames.includes('vehicles') || !tableNames.includes('implements')) {
                console.warn('[DB] initDatabase: schema missing, recreating...')
                db.close()
                db = new SQL.Database()
                createSchema()
                insertDefaults()
                saveDatabase()
            } else {
                // Check for new tables and create if missing (migration)
                if (!tableNames.includes('fields')) {
                    console.log('[DB] initDatabase: creating fields table (migration)')
                    db.run(`
                        CREATE TABLE IF NOT EXISTS fields (
                            id TEXT PRIMARY KEY,
                            name TEXT NOT NULL,
                            boundary TEXT
                        )
                    `)
                    saveDatabase()
                }
                if (!tableNames.includes('ab_lines')) {
                    console.log('[DB] initDatabase: creating ab_lines table (migration)')
                    db.run(`
                        CREATE TABLE IF NOT EXISTS ab_lines (
                            id TEXT PRIMARY KEY,
                            field_id TEXT NOT NULL,
                            name TEXT NOT NULL,
                            point_a TEXT,
                            point_b TEXT,
                            swath_width REAL NOT NULL,
                            num_swaths_left INTEGER NOT NULL,
                            num_swaths_right INTEGER NOT NULL,
                            FOREIGN KEY (field_id) REFERENCES fields(id) ON DELETE CASCADE
                        )
                    `)
                    saveDatabase()
                }
                console.log('[DB] initDatabase: loaded existing database from localStorage')
            }
            return
        } catch (e) {
            console.warn('[DB] initDatabase: failed to load saved database, creating new one:', e)
        }
    }

    // Create new database with schema
    db = new SQL.Database()
    createSchema()
    insertDefaults()
    saveDatabase()
    console.log('[DB] initDatabase: created new database with defaults')
}

/**
 * Create database schema
 */
function createSchema(): void {
    if (!db) return

    db.run(`
        CREATE TABLE IF NOT EXISTS vehicles (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            wheelbase REAL NOT NULL,
            turning_radius REAL NOT NULL,
            rear_axle_to_hitch REAL NOT NULL,
            antenna_height REAL NOT NULL,
            antenna_lateral REAL NOT NULL,
            antenna_longitudinal REAL NOT NULL
        )
    `)

    db.run(`
        CREATE TABLE IF NOT EXISTS implements (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            hitch_to_rotation REAL NOT NULL,
            hitch_to_work REAL NOT NULL,
            work_width REAL NOT NULL
        )
    `)

    db.run(`
        CREATE TABLE IF NOT EXISTS config (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        )
    `)

    db.run(`
        CREATE TABLE IF NOT EXISTS fields (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            boundary TEXT
        )
    `)

    db.run(`
        CREATE TABLE IF NOT EXISTS ab_lines (
            id TEXT PRIMARY KEY,
            field_id TEXT NOT NULL,
            name TEXT NOT NULL,
            point_a TEXT,
            point_b TEXT,
            swath_width REAL NOT NULL,
            num_swaths_left INTEGER NOT NULL,
            num_swaths_right INTEGER NOT NULL,
            FOREIGN KEY (field_id) REFERENCES fields(id) ON DELETE CASCADE
        )
    `)
}

/**
 * Insert default presets
 */
function insertDefaults(): void {
    if (!db) return

    for (const v of DEFAULT_VEHICLES) {
        db.run(
            `INSERT OR IGNORE INTO vehicles VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
            [v.id, v.name, v.wheelbase, v.turningRadius, v.rearAxleToHitch,
             v.antenna.heightToGround, v.antenna.lateralOffset, v.antenna.longitudinalOffset]
        )
    }

    for (const i of DEFAULT_IMPLEMENTS) {
        db.run(
            `INSERT OR IGNORE INTO implements VALUES (?, ?, ?, ?, ?, ?)`,
            [i.id, i.name, i.type, i.hitchToCenterRotation, i.hitchToCenterWork, i.workWidth]
        )
    }

    // Set default active equipment
    db.run(`INSERT OR IGNORE INTO config VALUES ('activeVehicleId', ?)`, [DEFAULT_VEHICLES[0].id])
    db.run(`INSERT OR IGNORE INTO config VALUES ('activeImplementId', ?)`, [DEFAULT_IMPLEMENTS[0].id])
}

/**
 * Save database to localStorage
 */
export function saveDatabase(): void {
    if (!db) {
        console.warn('[DB] saveDatabase: database not initialized')
        return
    }
    try {
        const data = db.export()
        const base64 = btoa(String.fromCharCode(...data))
        localStorage.setItem(DB_STORAGE_KEY, base64)
        console.log(`[DB] saveDatabase: saved ${data.length} bytes to localStorage`)
    } catch (e) {
        console.error('[DB] saveDatabase: failed to save:', e)
    }
}

// Vehicle CRUD operations

export function getAllVehicles(): VehicleConfig[] {
    if (!db) {
        console.log('[DB] getAllVehicles: database not initialized')
        return []
    }
    const result = db.exec('SELECT * FROM vehicles')
    const vehicles = result.length === 0 ? [] : result[0].values.map((row: any[]) => ({
        id: row[0] as string,
        name: row[1] as string,
        wheelbase: row[2] as number,
        turningRadius: row[3] as number,
        rearAxleToHitch: row[4] as number,
        antenna: {
            heightToGround: row[5] as number,
            lateralOffset: row[6] as number,
            longitudinalOffset: row[7] as number
        }
    }))
    console.log(`[DB] getAllVehicles: found ${vehicles.length} vehicles`)
    return vehicles
}

export function getVehicle(id: string): VehicleConfig | null {
    if (!db) return null
    const stmt = db.prepare('SELECT * FROM vehicles WHERE id = ?')
    stmt.bind([id])
    if (stmt.step()) {
        const row = stmt.get()
        stmt.free()
        return {
            id: row[0] as string,
            name: row[1] as string,
            wheelbase: row[2] as number,
            turningRadius: row[3] as number,
            rearAxleToHitch: row[4] as number,
            antenna: {
                heightToGround: row[5] as number,
                lateralOffset: row[6] as number,
                longitudinalOffset: row[7] as number
            }
        }
    }
    stmt.free()
    return null
}

export function saveVehicle(vehicle: VehicleConfig): void {
    if (!db) {
        console.warn('[DB] saveVehicle: database not initialized')
        return
    }
    console.log(`[DB] saveVehicle: saving "${vehicle.name}" (${vehicle.id})`)
    db.run(
        `INSERT OR REPLACE INTO vehicles VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        [vehicle.id, vehicle.name, vehicle.wheelbase, vehicle.turningRadius, vehicle.rearAxleToHitch,
         vehicle.antenna.heightToGround, vehicle.antenna.lateralOffset, vehicle.antenna.longitudinalOffset]
    )
    saveDatabase()
}

export function deleteVehicle(id: string): void {
    if (!db) {
        console.warn('[DB] deleteVehicle: database not initialized')
        return
    }
    console.log(`[DB] deleteVehicle: deleting ${id}`)
    db.run('DELETE FROM vehicles WHERE id = ?', [id])
    saveDatabase()
}

// Implement CRUD operations

export function getAllImplements(): ImplementConfig[] {
    if (!db) {
        console.log('[DB] getAllImplements: database not initialized')
        return []
    }
    const result = db.exec('SELECT * FROM implements')
    const implements_ = result.length === 0 ? [] : result[0].values.map((row: any[]) => ({
        id: row[0] as string,
        name: row[1] as string,
        type: row[2] as 'pivoting' | 'fixed',
        hitchToCenterRotation: row[3] as number,
        hitchToCenterWork: row[4] as number,
        workWidth: row[5] as number
    }))
    console.log(`[DB] getAllImplements: found ${implements_.length} implements`)
    return implements_
}

export function getImplement(id: string): ImplementConfig | null {
    if (!db) return null
    const stmt = db.prepare('SELECT * FROM implements WHERE id = ?')
    stmt.bind([id])
    if (stmt.step()) {
        const row = stmt.get()
        stmt.free()
        return {
            id: row[0] as string,
            name: row[1] as string,
            type: row[2] as 'pivoting' | 'fixed',
            hitchToCenterRotation: row[3] as number,
            hitchToCenterWork: row[4] as number,
            workWidth: row[5] as number
        }
    }
    stmt.free()
    return null
}

export function saveImplement(implement: ImplementConfig): void {
    if (!db) {
        console.warn('[DB] saveImplement: database not initialized')
        return
    }
    console.log(`[DB] saveImplement: saving "${implement.name}" (${implement.id})`)
    db.run(
        `INSERT OR REPLACE INTO implements VALUES (?, ?, ?, ?, ?, ?)`,
        [implement.id, implement.name, implement.type, implement.hitchToCenterRotation,
         implement.hitchToCenterWork, implement.workWidth]
    )
    saveDatabase()
}

export function deleteImplement(id: string): void {
    if (!db) {
        console.warn('[DB] deleteImplement: database not initialized')
        return
    }
    console.log(`[DB] deleteImplement: deleting ${id}`)
    db.run('DELETE FROM implements WHERE id = ?', [id])
    saveDatabase()
}

// Config operations

export function getConfig(key: string): string | null {
    if (!db) return null
    const stmt = db.prepare('SELECT value FROM config WHERE key = ?')
    stmt.bind([key])
    if (stmt.step()) {
        const row = stmt.get()
        stmt.free()
        return row[0] as string
    }
    stmt.free()
    return null
}

export function setConfig(key: string, value: string): void {
    if (!db) {
        console.warn('[DB] setConfig: database not initialized')
        return
    }
    console.log(`[DB] setConfig: ${key} = ${value}`)
    db.run('INSERT OR REPLACE INTO config VALUES (?, ?)', [key, value])
    saveDatabase()
}

export function getActiveVehicleId(): string | null {
    const id = getConfig('activeVehicleId')
    console.log(`[DB] getActiveVehicleId: ${id}`)
    return id
}

export function setActiveVehicleId(id: string): void {
    console.log(`[DB] setActiveVehicleId: ${id}`)
    setConfig('activeVehicleId', id)
}

export function getActiveImplementId(): string | null {
    const id = getConfig('activeImplementId')
    console.log(`[DB] getActiveImplementId: ${id}`)
    return id
}

export function setActiveImplementId(id: string): void {
    console.log(`[DB] setActiveImplementId: ${id}`)
    setConfig('activeImplementId', id)
}

// Generate unique IDs
let vehicleCounter = 100
let implementCounter = 100

export function generateVehicleId(): string {
    return `vehicle-${Date.now()}-${vehicleCounter++}`
}

export function generateImplementId(): string {
    return `implement-${Date.now()}-${implementCounter++}`
}

// Field CRUD operations

export function getAllFields(): FieldData[] {
    if (!db) {
        console.log('[DB] getAllFields: database not initialized')
        return []
    }
    const result = db.exec('SELECT * FROM fields')
    if (result.length === 0) {
        console.log('[DB] getAllFields: no fields found')
        return []
    }

    const fields: FieldData[] = result[0].values.map((row: any[]) => {
        const fieldId = row[0] as string
        const boundary = row[2] ? JSON.parse(row[2] as string) : null

        // Get AB lines for this field
        const abLines = getABLinesForField(fieldId)

        return {
            id: fieldId,
            name: row[1] as string,
            boundary,
            abLines
        }
    })

    console.log(`[DB] getAllFields: found ${fields.length} fields`)
    return fields
}

export function getABLinesForField(fieldId: string): ABLineData[] {
    if (!db) return []

    const stmt = db.prepare('SELECT * FROM ab_lines WHERE field_id = ?')
    stmt.bind([fieldId])

    const abLines: ABLineData[] = []
    while (stmt.step()) {
        const row = stmt.get()
        abLines.push({
            id: row[0] as string,
            fieldId: row[1] as string,
            name: row[2] as string,
            pointA: row[3] ? JSON.parse(row[3] as string) : null,
            pointB: row[4] ? JSON.parse(row[4] as string) : null,
            swathWidth: row[5] as number,
            numSwathsLeft: row[6] as number,
            numSwathsRight: row[7] as number
        })
    }
    stmt.free()
    return abLines
}

export function saveField(field: FieldData): void {
    if (!db) {
        console.warn('[DB] saveField: database not initialized')
        return
    }
    console.log(`[DB] saveField: saving "${field.name}" (${field.id})`)

    const boundaryJson = field.boundary ? JSON.stringify(field.boundary) : null
    db.run(
        'INSERT OR REPLACE INTO fields VALUES (?, ?, ?)',
        [field.id, field.name, boundaryJson]
    )

    // Delete existing AB lines for this field and re-insert
    db.run('DELETE FROM ab_lines WHERE field_id = ?', [field.id])

    for (const abLine of field.abLines) {
        const pointAJson = abLine.pointA ? JSON.stringify(abLine.pointA) : null
        const pointBJson = abLine.pointB ? JSON.stringify(abLine.pointB) : null
        db.run(
            'INSERT INTO ab_lines VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            [abLine.id, field.id, abLine.name, pointAJson, pointBJson,
             abLine.swathWidth, abLine.numSwathsLeft, abLine.numSwathsRight]
        )
    }

    saveDatabase()
}

export function deleteField(id: string): void {
    if (!db) {
        console.warn('[DB] deleteField: database not initialized')
        return
    }
    console.log(`[DB] deleteField: deleting ${id}`)
    db.run('DELETE FROM ab_lines WHERE field_id = ?', [id])
    db.run('DELETE FROM fields WHERE id = ?', [id])
    saveDatabase()
}

export function getActiveFieldId(): string | null {
    const id = getConfig('activeFieldId')
    console.log(`[DB] getActiveFieldId: ${id}`)
    return id
}

export function setActiveFieldId(id: string | null): void {
    console.log(`[DB] setActiveFieldId: ${id}`)
    if (id) {
        setConfig('activeFieldId', id)
    } else {
        // Remove the config entry if null
        if (db) {
            db.run('DELETE FROM config WHERE key = ?', ['activeFieldId'])
            saveDatabase()
        }
    }
}

let fieldCounter = 100
let abLineCounter = 100

export function generateFieldId(): string {
    return `field-${Date.now()}-${fieldCounter++}`
}

export function generateABLineId(): string {
    return `abline-${Date.now()}-${abLineCounter++}`
}
