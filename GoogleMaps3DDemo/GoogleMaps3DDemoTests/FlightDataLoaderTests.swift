import XCTest
@testable import GoogleMaps3DDemo

final class FlightDataLoaderTests: XCTestCase {
    func testLoadsFlightPathFromBundleResource() {
        let bundle = Bundle(for: FlightDataLoaderTests.self)
        let loader = FlightDataLoader(bundle: bundle)

        loader.load("flightpath_test.json", bundle: bundle)

        XCTAssertTrue(loader.isLoaded)
        XCTAssertEqual(loader.flightPathData.flight.count, 1)
        XCTAssertEqual(loader.flightPathData.flight.first?.latitude, 38.06517, accuracy: 0.0001)
    }
}
