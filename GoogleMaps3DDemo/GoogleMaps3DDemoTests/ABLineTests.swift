import XCTest
import CoreLocation
@testable import GoogleMaps3DDemo

final class ABLineTests: XCTestCase {
    func testHeadingUsesManualWhenIncomplete() {
        let pointA = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        var line = ABLine(pointA: pointA, heading: .pi / 2)
        XCTAssertEqual(line.heading, .pi / 2, accuracy: 0.0001)
        XCTAssertFalse(line.isComplete)
    }

    func testHeadingAndLengthWhenComplete() {
        let pointA = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let pointB = CLLocationCoordinate2D(latitude: 0, longitude: 1)
        let line = ABLine(pointA: pointA, pointB: pointB)

        XCTAssertTrue(line.isComplete)
        XCTAssertEqual(line.heading, .pi / 2, accuracy: 0.0001)
        XCTAssertNotNil(line.length)
        XCTAssertEqual(line.length ?? 0, 111_194.0, accuracy: 100.0)
    }

    func testGuidanceCrossTrackError() {
        let pointA = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let pointB = CLLocationCoordinate2D(latitude: 0, longitude: 0.001)
        let line = ABLine(pointA: pointA, pointB: pointB)
        let engine = StraightABGuidance(abLine: line, lineSpacing: 10.0, linesDirection: .both)

        let result = engine.calculateGuidance(localX: 10, localZ: 0, vehicleHeading: 0, targetLineIndex: 0)
        XCTAssertEqual(result.crossTrackError, 10.0, accuracy: 0.0001)
        XCTAssertEqual(result.nearestLineIndex, 1)
    }
}
