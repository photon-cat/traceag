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
import SQLite3

/// Thread-safe SQLite database manager for ISOXML agricultural data
final class DatabaseManager {

    // MARK: - Singleton

    static let shared = DatabaseManager()

    // MARK: - Properties

    private var db: OpaquePointer?
    private let dbQueue = DispatchQueue(label: "com.gnss.database", qos: .userInitiated)
    private let dbPath: String

    static func defaultDatabasePath() -> String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("gnss_data.sqlite").path
    }

    // MARK: - Initialization

    private init() {
        self.dbPath = DatabaseManager.defaultDatabasePath()
        openDatabase()
        createTables()
    }

    init(path: String) {
        self.dbPath = path
        openDatabase()
        createTables()
    }

    deinit {
        closeDatabase()
    }

    // MARK: - Database Connection

    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("DatabaseManager: Error opening database at \(dbPath)")
        } else {
            print("DatabaseManager: Database opened at \(dbPath)")
            // Enable foreign keys
            executeSQL("PRAGMA foreign_keys = ON")
        }
    }

    private func closeDatabase() {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }

    // MARK: - Table Creation

    private func createTables() {
        // IdTable for entity ID resolution
        executeSQL("""
            CREATE TABLE IF NOT EXISTS id_table (
                id TEXT PRIMARY KEY,
                entity_type TEXT NOT NULL,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
        """)

        // ISOCustomer - internal account identifier
        executeSQL("""
            CREATE TABLE IF NOT EXISTS customers (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
        """)

        // ISOFarmer
        executeSQL("""
            CREATE TABLE IF NOT EXISTS farmers (
                id TEXT PRIMARY KEY,
                customer_id TEXT NOT NULL,
                first_name TEXT,
                last_name TEXT NOT NULL,
                email TEXT,
                phone TEXT,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
            )
        """)

        // ISOFarm
        executeSQL("""
            CREATE TABLE IF NOT EXISTS farms (
                id TEXT PRIMARY KEY,
                farmer_id TEXT NOT NULL,
                name TEXT NOT NULL,
                address TEXT,
                notes TEXT,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (farmer_id) REFERENCES farmers(id) ON DELETE CASCADE
            )
        """)

        // ISOPartfield (Field)
        executeSQL("""
            CREATE TABLE IF NOT EXISTS partfields (
                id TEXT PRIMARY KEY,
                farm_id TEXT NOT NULL,
                name TEXT NOT NULL,
                area_m2 REAL,
                season TEXT,
                crop_type TEXT,
                notes TEXT,
                boundary_json TEXT,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (farm_id) REFERENCES farms(id) ON DELETE CASCADE
            )
        """)

        // ISOTask
        executeSQL("""
            CREATE TABLE IF NOT EXISTS tasks (
                id TEXT PRIMARY KEY,
                partfield_id TEXT NOT NULL,
                name TEXT NOT NULL,
                task_type TEXT NOT NULL,
                status TEXT DEFAULT 'pending',
                device_id TEXT,
                product_id TEXT,
                notes TEXT,
                started_at TEXT,
                completed_at TEXT,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (partfield_id) REFERENCES partfields(id) ON DELETE CASCADE
            )
        """)

        // Task logs for operation data
        executeSQL("""
            CREATE TABLE IF NOT EXISTS task_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                task_id TEXT NOT NULL,
                timestamp TEXT NOT NULL,
                latitude REAL NOT NULL,
                longitude REAL NOT NULL,
                heading REAL,
                speed REAL,
                data_json TEXT,
                FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
            )
        """)

        // Coverage data for fields
        executeSQL("""
            CREATE TABLE IF NOT EXISTS coverage_data (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                task_id TEXT NOT NULL,
                cell_row INTEGER NOT NULL,
                cell_col INTEGER NOT NULL,
                timestamp TEXT NOT NULL,
                UNIQUE(task_id, cell_row, cell_col),
                FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
            )
        """)

        // Devices (implements, machines)
        executeSQL("""
            CREATE TABLE IF NOT EXISTS devices (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                device_type TEXT NOT NULL,
                config_json TEXT,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
        """)

        // Products (seeds, fertilizers, etc.)
        executeSQL("""
            CREATE TABLE IF NOT EXISTS products (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                product_type TEXT NOT NULL,
                unit TEXT,
                notes TEXT,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
        """)

        print("DatabaseManager: Tables created successfully")
    }

    // MARK: - SQL Execution

    @discardableResult
    private func executeSQL(_ sql: String) -> Bool {
        var errorMessage: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errorMessage) != SQLITE_OK {
            if let error = errorMessage {
                print("DatabaseManager: SQL error: \(String(cString: error))")
                sqlite3_free(errorMessage)
            }
            return false
        }
        return true
    }

    // MARK: - ID Generation

    /// Generates a unique ID with the given prefix (e.g., "PFD" for partfields, "TSK" for tasks)
    func generateId(prefix: String) -> String {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let random = Int.random(in: 1000...9999)
        return "\(prefix)\(timestamp % 100000)\(random)"
    }

    // MARK: - IdTable Operations

    func registerEntity(id: String, type: EntityType) {
        dbQueue.sync {
            let sql = "INSERT OR REPLACE INTO id_table (id, entity_type) VALUES (?, ?)"
            var stmt: OpaquePointer?

            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (type.rawValue as NSString).utf8String, -1, nil)

                if sqlite3_step(stmt) != SQLITE_DONE {
                    print("DatabaseManager: Error registering entity \(id)")
                }
            }
            sqlite3_finalize(stmt)
        }
    }

    func resolveEntityType(id: String) -> EntityType? {
        var result: EntityType?
        dbQueue.sync {
            let sql = "SELECT entity_type FROM id_table WHERE id = ?"
            var stmt: OpaquePointer?

            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)

                if sqlite3_step(stmt) == SQLITE_ROW {
                    if let typeStr = sqlite3_column_text(stmt, 0) {
                        result = EntityType(rawValue: String(cString: typeStr))
                    }
                }
            }
            sqlite3_finalize(stmt)
        }
        return result
    }

    // MARK: - Customer Operations

    func createCustomer(name: String) -> ISOCustomer? {
        let id = generateId(prefix: "CTR")
        var customer: ISOCustomer?

        dbQueue.sync {
            let sql = "INSERT INTO customers (id, name) VALUES (?, ?)"
            var stmt: OpaquePointer?

            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (name as NSString).utf8String, -1, nil)

                if sqlite3_step(stmt) == SQLITE_DONE {
                    customer = ISOCustomer(id: id, name: name)
                    registerEntity(id: id, type: .customer)
                }
            }
            sqlite3_finalize(stmt)
        }
        return customer
    }

    func getCustomer(id: String) -> ISOCustomer? {
        var customer: ISOCustomer?
        dbQueue.sync {
            let sql = "SELECT id, name, created_at FROM customers WHERE id = ?"
            var stmt: OpaquePointer?

            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)

                if sqlite3_step(stmt) == SQLITE_ROW {
                    let customerId = String(cString: sqlite3_column_text(stmt, 0))
                    let name = String(cString: sqlite3_column_text(stmt, 1))
                    customer = ISOCustomer(id: customerId, name: name)
                }
            }
            sqlite3_finalize(stmt)
        }
        return customer
    }

    func getAllCustomers() -> [ISOCustomer] {
        var customers: [ISOCustomer] = []
        dbQueue.sync {
            let sql = "SELECT id, name FROM customers ORDER BY name"
            var stmt: OpaquePointer?

            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let id = String(cString: sqlite3_column_text(stmt, 0))
                    let name = String(cString: sqlite3_column_text(stmt, 1))
                    customers.append(ISOCustomer(id: id, name: name))
                }
            }
            sqlite3_finalize(stmt)
        }
        return customers
    }

    // MARK: - Farmer Operations

    func createFarmer(customerId: String, firstName: String?, lastName: String, email: String? = nil, phone: String? = nil) -> ISOFarmer? {
        let id = generateId(prefix: "FRM")
        var farmer: ISOFarmer?

        dbQueue.sync {
            let sql = "INSERT INTO farmers (id, customer_id, first_name, last_name, email, phone) VALUES (?, ?, ?, ?, ?, ?)"
            var stmt: OpaquePointer?

            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (customerId as NSString).utf8String, -1, nil)
                if let fn = firstName {
                    sqlite3_bind_text(stmt, 3, (fn as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 3)
                }
                sqlite3_bind_text(stmt, 4, (lastName as NSString).utf8String, -1, nil)
                if let e = email {
                    sqlite3_bind_text(stmt, 5, (e as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 5)
                }
                if let p = phone {
                    sqlite3_bind_text(stmt, 6, (p as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 6)
                }

                if sqlite3_step(stmt) == SQLITE_DONE {
                    farmer = ISOFarmer(id: id, customerId: customerId, firstName: firstName, lastName: lastName, email: email, phone: phone)
                    registerEntity(id: id, type: .farmer)
                }
            }
            sqlite3_finalize(stmt)
        }
        return farmer
    }

    func getFarmersForCustomer(_ customerId: String) -> [ISOFarmer] {
        var farmers: [ISOFarmer] = []
        dbQueue.sync {
            let sql = "SELECT id, customer_id, first_name, last_name, email, phone FROM farmers WHERE customer_id = ? ORDER BY last_name"
            var stmt: OpaquePointer?

            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (customerId as NSString).utf8String, -1, nil)

                while sqlite3_step(stmt) == SQLITE_ROW {
                    let id = String(cString: sqlite3_column_text(stmt, 0))
                    let custId = String(cString: sqlite3_column_text(stmt, 1))
                    let firstName = sqlite3_column_text(stmt, 2).map { String(cString: $0) }
                    let lastName = String(cString: sqlite3_column_text(stmt, 3))
                    let email = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
                    let phone = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
                    farmers.append(ISOFarmer(id: id, customerId: custId, firstName: firstName, lastName: lastName, email: email, phone: phone))
                }
            }
            sqlite3_finalize(stmt)
        }
        return farmers
    }

    // MARK: - Farm Operations

    func createFarm(farmerId: String, name: String, address: String? = nil, notes: String? = nil) -> ISOFarm? {
        let id = generateId(prefix: "FRM")
        var farm: ISOFarm?

        dbQueue.sync {
            let sql = "INSERT INTO farms (id, farmer_id, name, address, notes) VALUES (?, ?, ?, ?, ?)"
            var stmt: OpaquePointer?

            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (farmerId as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 3, (name as NSString).utf8String, -1, nil)
                if let a = address {
                    sqlite3_bind_text(stmt, 4, (a as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 4)
                }
                if let n = notes {
                    sqlite3_bind_text(stmt, 5, (n as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 5)
                }

                if sqlite3_step(stmt) == SQLITE_DONE {
                    farm = ISOFarm(id: id, farmerId: farmerId, name: name, address: address, notes: notes)
                    registerEntity(id: id, type: .farm)
                }
            }
            sqlite3_finalize(stmt)
        }
        return farm
    }

    func getFarmsForFarmer(_ farmerId: String) -> [ISOFarm] {
        var farms: [ISOFarm] = []
        dbQueue.sync {
            let sql = "SELECT id, farmer_id, name, address, notes FROM farms WHERE farmer_id = ? ORDER BY name"
            var stmt: OpaquePointer?

            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (farmerId as NSString).utf8String, -1, nil)

                while sqlite3_step(stmt) == SQLITE_ROW {
                    let id = String(cString: sqlite3_column_text(stmt, 0))
                    let fId = String(cString: sqlite3_column_text(stmt, 1))
                    let name = String(cString: sqlite3_column_text(stmt, 2))
                    let address = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
                    let notes = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
                    farms.append(ISOFarm(id: id, farmerId: fId, name: name, address: address, notes: notes))
                }
            }
            sqlite3_finalize(stmt)
        }
        return farms
    }

    // MARK: - Partfield (Field) Operations

    func createPartfield(farmId: String, name: String, season: String? = nil, cropType: String? = nil, boundary: [BoundaryPoint]? = nil) -> ISOPartfield? {
        let id = generateId(prefix: "PFD")
        var partfield: ISOPartfield?

        dbQueue.sync {
            let sql = "INSERT INTO partfields (id, farm_id, name, season, crop_type, boundary_json) VALUES (?, ?, ?, ?, ?, ?)"
            var stmt: OpaquePointer?

            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (farmId as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 3, (name as NSString).utf8String, -1, nil)

                if let s = season {
                    sqlite3_bind_text(stmt, 4, (s as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 4)
                }

                if let c = cropType {
                    sqlite3_bind_text(stmt, 5, (c as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 5)
                }

                if let b = boundary, let jsonData = try? JSONEncoder().encode(b), let jsonStr = String(data: jsonData, encoding: .utf8) {
                    sqlite3_bind_text(stmt, 6, (jsonStr as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 6)
                }

                if sqlite3_step(stmt) == SQLITE_DONE {
                    partfield = ISOPartfield(id: id, farmId: farmId, name: name, season: season, cropType: cropType, boundary: boundary)
                    registerEntity(id: id, type: .partfield)
                }
            }
            sqlite3_finalize(stmt)
        }
        return partfield
    }

    func getPartfield(id: String) -> ISOPartfield? {
        var partfield: ISOPartfield?
        dbQueue.sync {
            let sql = "SELECT id, farm_id, name, area_m2, season, crop_type, notes, boundary_json FROM partfields WHERE id = ?"
            var stmt: OpaquePointer?

            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)

                if sqlite3_step(stmt) == SQLITE_ROW {
                    let pId = String(cString: sqlite3_column_text(stmt, 0))
                    let farmId = String(cString: sqlite3_column_text(stmt, 1))
                    let name = String(cString: sqlite3_column_text(stmt, 2))
                    let area = sqlite3_column_type(stmt, 3) != SQLITE_NULL ? sqlite3_column_double(stmt, 3) : nil
                    let season = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
                    let cropType = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
                    let notes = sqlite3_column_text(stmt, 6).map { String(cString: $0) }

                    var boundary: [BoundaryPoint]?
                    if let jsonStr = sqlite3_column_text(stmt, 7).map({ String(cString: $0) }),
                       let jsonData = jsonStr.data(using: .utf8) {
                        boundary = try? JSONDecoder().decode([BoundaryPoint].self, from: jsonData)
                    }

                    partfield = ISOPartfield(id: pId, farmId: farmId, name: name, areaM2: area, season: season, cropType: cropType, notes: notes, boundary: boundary)
                }
            }
            sqlite3_finalize(stmt)
        }
        return partfield
    }

    func getPartfieldsForFarm(_ farmId: String) -> [ISOPartfield] {
        var partfields: [ISOPartfield] = []
        dbQueue.sync {
            let sql = "SELECT id, farm_id, name, area_m2, season, crop_type, notes, boundary_json FROM partfields WHERE farm_id = ? ORDER BY name"
            var stmt: OpaquePointer?

            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (farmId as NSString).utf8String, -1, nil)

                while sqlite3_step(stmt) == SQLITE_ROW {
                    let id = String(cString: sqlite3_column_text(stmt, 0))
                    let fId = String(cString: sqlite3_column_text(stmt, 1))
                    let name = String(cString: sqlite3_column_text(stmt, 2))
                    let area = sqlite3_column_type(stmt, 3) != SQLITE_NULL ? sqlite3_column_double(stmt, 3) : nil
                    let season = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
                    let cropType = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
                    let notes = sqlite3_column_text(stmt, 6).map { String(cString: $0) }

                    var boundary: [BoundaryPoint]?
                    if let jsonStr = sqlite3_column_text(stmt, 7).map({ String(cString: $0) }),
                       let jsonData = jsonStr.data(using: .utf8) {
                        boundary = try? JSONDecoder().decode([BoundaryPoint].self, from: jsonData)
                    }

                    partfields.append(ISOPartfield(id: id, farmId: fId, name: name, areaM2: area, season: season, cropType: cropType, notes: notes, boundary: boundary))
                }
            }
            sqlite3_finalize(stmt)
        }
        return partfields
    }

    func updatePartfieldBoundary(id: String, boundary: [BoundaryPoint], areaM2: Double) {
        dbQueue.sync {
            let sql = "UPDATE partfields SET boundary_json = ?, area_m2 = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?"
            var stmt: OpaquePointer?

            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                if let jsonData = try? JSONEncoder().encode(boundary), let jsonStr = String(data: jsonData, encoding: .utf8) {
                    sqlite3_bind_text(stmt, 1, (jsonStr as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 1)
                }
                sqlite3_bind_double(stmt, 2, areaM2)
                sqlite3_bind_text(stmt, 3, (id as NSString).utf8String, -1, nil)

                if sqlite3_step(stmt) != SQLITE_DONE {
                    print("DatabaseManager: Error updating partfield boundary")
                }
            }
            sqlite3_finalize(stmt)
        }
    }

    // MARK: - Task Operations

    func createTask(partfieldId: String, name: String, taskType: TaskType, deviceId: String? = nil, productId: String? = nil, notes: String? = nil) -> ISOTask? {
        let id = generateId(prefix: "TSK")
        var task: ISOTask?

        dbQueue.sync {
            let sql = "INSERT INTO tasks (id, partfield_id, name, task_type, device_id, product_id, notes) VALUES (?, ?, ?, ?, ?, ?, ?)"
            var stmt: OpaquePointer?

            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (partfieldId as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 3, (name as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 4, (taskType.rawValue as NSString).utf8String, -1, nil)

                if let d = deviceId {
                    sqlite3_bind_text(stmt, 5, (d as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 5)
                }

                if let p = productId {
                    sqlite3_bind_text(stmt, 6, (p as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 6)
                }

                if let n = notes {
                    sqlite3_bind_text(stmt, 7, (n as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 7)
                }

                if sqlite3_step(stmt) == SQLITE_DONE {
                    task = ISOTask(id: id, partfieldId: partfieldId, name: name, taskType: taskType, status: .pending, deviceId: deviceId, productId: productId, notes: notes)
                    registerEntity(id: id, type: .task)
                }
            }
            sqlite3_finalize(stmt)
        }
        return task
    }

    func getTask(id: String) -> ISOTask? {
        var task: ISOTask?
        dbQueue.sync {
            let sql = "SELECT id, partfield_id, name, task_type, status, device_id, product_id, notes, started_at, completed_at FROM tasks WHERE id = ?"
            var stmt: OpaquePointer?

            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)

                if sqlite3_step(stmt) == SQLITE_ROW {
                    let tId = String(cString: sqlite3_column_text(stmt, 0))
                    let partfieldId = String(cString: sqlite3_column_text(stmt, 1))
                    let name = String(cString: sqlite3_column_text(stmt, 2))
                    let taskTypeStr = String(cString: sqlite3_column_text(stmt, 3))
                    let statusStr = String(cString: sqlite3_column_text(stmt, 4))
                    let deviceId = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
                    let productId = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
                    let notes = sqlite3_column_text(stmt, 7).map { String(cString: $0) }

                    task = ISOTask(
                        id: tId,
                        partfieldId: partfieldId,
                        name: name,
                        taskType: TaskType(rawValue: taskTypeStr) ?? .other,
                        status: TaskStatus(rawValue: statusStr) ?? .pending,
                        deviceId: deviceId,
                        productId: productId,
                        notes: notes
                    )
                }
            }
            sqlite3_finalize(stmt)
        }
        return task
    }

    func getTasksForPartfield(_ partfieldId: String) -> [ISOTask] {
        var tasks: [ISOTask] = []
        dbQueue.sync {
            let sql = "SELECT id, partfield_id, name, task_type, status, device_id, product_id, notes FROM tasks WHERE partfield_id = ? ORDER BY created_at DESC"
            var stmt: OpaquePointer?

            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (partfieldId as NSString).utf8String, -1, nil)

                while sqlite3_step(stmt) == SQLITE_ROW {
                    let id = String(cString: sqlite3_column_text(stmt, 0))
                    let pId = String(cString: sqlite3_column_text(stmt, 1))
                    let name = String(cString: sqlite3_column_text(stmt, 2))
                    let taskTypeStr = String(cString: sqlite3_column_text(stmt, 3))
                    let statusStr = String(cString: sqlite3_column_text(stmt, 4))
                    let deviceId = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
                    let productId = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
                    let notes = sqlite3_column_text(stmt, 7).map { String(cString: $0) }

                    tasks.append(ISOTask(
                        id: id,
                        partfieldId: pId,
                        name: name,
                        taskType: TaskType(rawValue: taskTypeStr) ?? .other,
                        status: TaskStatus(rawValue: statusStr) ?? .pending,
                        deviceId: deviceId,
                        productId: productId,
                        notes: notes
                    ))
                }
            }
            sqlite3_finalize(stmt)
        }
        return tasks
    }

    func updateTaskStatus(id: String, status: TaskStatus) {
        dbQueue.sync {
            var sql: String
            if status == .inProgress {
                sql = "UPDATE tasks SET status = ?, started_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP WHERE id = ?"
            } else if status == .completed {
                sql = "UPDATE tasks SET status = ?, completed_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP WHERE id = ?"
            } else {
                sql = "UPDATE tasks SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?"
            }

            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (status.rawValue as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (id as NSString).utf8String, -1, nil)

                if sqlite3_step(stmt) != SQLITE_DONE {
                    print("DatabaseManager: Error updating task status")
                }
            }
            sqlite3_finalize(stmt)
        }
    }

    // MARK: - Task Log Operations

    func addTaskLog(taskId: String, latitude: Double, longitude: Double, heading: Double?, speed: Double?, data: [String: Any]? = nil) {
        dbQueue.sync {
            let sql = "INSERT INTO task_logs (task_id, timestamp, latitude, longitude, heading, speed, data_json) VALUES (?, ?, ?, ?, ?, ?, ?)"
            var stmt: OpaquePointer?

            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                let timestamp = ISO8601DateFormatter().string(from: Date())

                sqlite3_bind_text(stmt, 1, (taskId as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (timestamp as NSString).utf8String, -1, nil)
                sqlite3_bind_double(stmt, 3, latitude)
                sqlite3_bind_double(stmt, 4, longitude)

                if let h = heading {
                    sqlite3_bind_double(stmt, 5, h)
                } else {
                    sqlite3_bind_null(stmt, 5)
                }

                if let s = speed {
                    sqlite3_bind_double(stmt, 6, s)
                } else {
                    sqlite3_bind_null(stmt, 6)
                }

                if let d = data, let jsonData = try? JSONSerialization.data(withJSONObject: d), let jsonStr = String(data: jsonData, encoding: .utf8) {
                    sqlite3_bind_text(stmt, 7, (jsonStr as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 7)
                }

                if sqlite3_step(stmt) != SQLITE_DONE {
                    print("DatabaseManager: Error adding task log")
                }
            }
            sqlite3_finalize(stmt)
        }
    }

    // MARK: - Coverage Operations

    func addCoverageCell(taskId: String, row: Int, col: Int) {
        dbQueue.sync {
            let sql = "INSERT OR IGNORE INTO coverage_data (task_id, cell_row, cell_col, timestamp) VALUES (?, ?, ?, ?)"
            var stmt: OpaquePointer?

            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                let timestamp = ISO8601DateFormatter().string(from: Date())

                sqlite3_bind_text(stmt, 1, (taskId as NSString).utf8String, -1, nil)
                sqlite3_bind_int(stmt, 2, Int32(row))
                sqlite3_bind_int(stmt, 3, Int32(col))
                sqlite3_bind_text(stmt, 4, (timestamp as NSString).utf8String, -1, nil)

                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }

    func getCoverageCells(taskId: String) -> Set<String> {
        var cells = Set<String>()
        dbQueue.sync {
            let sql = "SELECT cell_row, cell_col FROM coverage_data WHERE task_id = ?"
            var stmt: OpaquePointer?

            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (taskId as NSString).utf8String, -1, nil)

                while sqlite3_step(stmt) == SQLITE_ROW {
                    let row = sqlite3_column_int(stmt, 0)
                    let col = sqlite3_column_int(stmt, 1)
                    cells.insert("\(row)_\(col)")
                }
            }
            sqlite3_finalize(stmt)
        }
        return cells
    }

    func getCoverageCount(taskId: String) -> Int {
        var count = 0
        dbQueue.sync {
            let sql = "SELECT COUNT(*) FROM coverage_data WHERE task_id = ?"
            var stmt: OpaquePointer?

            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (taskId as NSString).utf8String, -1, nil)

                if sqlite3_step(stmt) == SQLITE_ROW {
                    count = Int(sqlite3_column_int(stmt, 0))
                }
            }
            sqlite3_finalize(stmt)
        }
        return count
    }

    // MARK: - Delete Operations

    func deletePartfield(id: String) {
        dbQueue.sync {
            executeSQL("DELETE FROM partfields WHERE id = '\(id)'")
            executeSQL("DELETE FROM id_table WHERE id = '\(id)'")
        }
    }

    func deleteTask(id: String) {
        dbQueue.sync {
            executeSQL("DELETE FROM tasks WHERE id = '\(id)'")
            executeSQL("DELETE FROM id_table WHERE id = '\(id)'")
        }
    }

    func deleteFarm(id: String) {
        dbQueue.sync {
            executeSQL("DELETE FROM farms WHERE id = '\(id)'")
            executeSQL("DELETE FROM id_table WHERE id = '\(id)'")
        }
    }

    func deleteFarmer(id: String) {
        dbQueue.sync {
            executeSQL("DELETE FROM farmers WHERE id = '\(id)'")
            executeSQL("DELETE FROM id_table WHERE id = '\(id)'")
        }
    }
}
