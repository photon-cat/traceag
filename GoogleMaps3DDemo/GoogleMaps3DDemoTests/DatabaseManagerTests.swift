import XCTest
@testable import GoogleMaps3DDemo

final class DatabaseManagerTests: XCTestCase {
    private var dbPath: String = ""
    private var database: DatabaseManager?

    override func setUp() {
        super.setUp()
        dbPath = NSTemporaryDirectory().appending("gnss_test_\(UUID().uuidString).sqlite")
        database = DatabaseManager(path: dbPath)
    }

    override func tearDown() {
        database = nil
        if FileManager.default.fileExists(atPath: dbPath) {
            try? FileManager.default.removeItem(atPath: dbPath)
        }
        super.tearDown()
    }

    func testCreateAndFetchCustomer() {
        guard let database else {
            XCTFail("Database not initialized")
            return
        }

        let customer = database.createCustomer(name: "Test Customer")
        XCTAssertNotNil(customer)

        let customers = database.getAllCustomers()
        XCTAssertEqual(customers.count, 1)
        XCTAssertEqual(customers.first?.name, "Test Customer")
    }

    func testCreateFarmAndPartfield() {
        guard let database else {
            XCTFail("Database not initialized")
            return
        }

        let customer = database.createCustomer(name: "Test Customer")
        let farmer = database.createFarmer(customerId: customer?.id ?? "", firstName: "T", lastName: "Farmer")
        let farm = database.createFarm(farmerId: farmer?.id ?? "", name: "Farm 1")

        XCTAssertNotNil(farm)

        let boundary = [
            BoundaryPoint(latitude: 0, longitude: 0),
            BoundaryPoint(latitude: 0, longitude: 0.001),
            BoundaryPoint(latitude: 0.001, longitude: 0.001)
        ]

        let partfield = database.createPartfield(
            farmId: farm?.id ?? "",
            name: "Field 1",
            season: "2025",
            cropType: "Corn",
            boundary: boundary
        )

        XCTAssertNotNil(partfield)
        let fields = database.getPartfieldsForFarm(farm?.id ?? "")
        XCTAssertEqual(fields.count, 1)
        XCTAssertEqual(fields.first?.name, "Field 1")
    }
}
