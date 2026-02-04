import XCTest
@testable import GoogleMaps3DDemo

final class VehicleConfigurationTests: XCTestCase {
    func testWorkPointOffsetFromAntenna() {
        var machine = MachineProfile()
        machine.antennaLongOffset = 0.5
        machine.antennaLateralOffset = 0.2
        machine.hitchOffset = 1.0

        var implement = ImplementProfile()
        implement.workPointOffset = 2.0

        let config = VehicleConfiguration(machine: machine, implement: implement)
        let offset = config.workPointOffsetFromAntenna()

        XCTAssertEqual(offset.longitudinal, 2.5, accuracy: 0.0001)
        XCTAssertEqual(offset.lateral, -0.2, accuracy: 0.0001)
    }
}
