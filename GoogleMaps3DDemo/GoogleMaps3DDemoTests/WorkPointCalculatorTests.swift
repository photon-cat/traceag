import XCTest
@testable import GoogleMaps3DDemo

final class WorkPointCalculatorTests: XCTestCase {
    func testWorkPointCalculatesOffsetsForNonPivotingImplement() {
        var machine = MachineProfile()
        machine.antennaLongOffset = 0
        machine.antennaLateralOffset = 0
        machine.hitchOffset = 1

        var implement = ImplementProfile()
        implement.isPivoting = false
        implement.workPointOffset = 2

        let calculator = WorkPointCalculator(machine: machine, implement: implement)
        let result = calculator.calculateWorkPoint(
            antennaX: 0,
            antennaZ: 0,
            tractorHeading: 0
        )

        XCTAssertEqual(result.x, 0, accuracy: 0.0001)
        XCTAssertEqual(result.z, -3.0, accuracy: 0.0001)
        XCTAssertEqual(result.heading, 0, accuracy: 0.0001)
    }
}
