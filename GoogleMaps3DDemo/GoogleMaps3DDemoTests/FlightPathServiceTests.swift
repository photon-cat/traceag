import XCTest
@testable import GoogleMaps3DDemo

private struct MockNetworkSession: NetworkSession {
    let data: Data
    let response: URLResponse

    func data(from url: URL) async throws -> (Data, URLResponse) {
        (data, response)
    }
}

final class FlightPathServiceTests: XCTestCase {
    func testFetchFlightPathDecodesResponse() async throws {
        let payload = """
        {"flight":[{"timestamp":1710000000,"latitude":1.0,"longitude":2.0,"altitude":3.0,"bearing":4.0,"speed":5.0}]}
        """
        let data = Data(payload.utf8)
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        let service = FlightPathService(session: MockNetworkSession(data: data, response: response))

        let result = try await service.fetchFlightPath(from: URL(string: "https://example.com")!)

        XCTAssertEqual(result.flight.count, 1)
        XCTAssertEqual(result.flight.first?.longitude, 2.0, accuracy: 0.0001)
    }

    func testFetchFlightPathThrowsForHTTPError() async {
        let data = Data()
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )!
        let service = FlightPathService(session: MockNetworkSession(data: data, response: response))

        do {
            _ = try await service.fetchFlightPath(from: URL(string: "https://example.com")!)
            XCTFail("Expected to throw")
        } catch let error as FlightPathServiceError {
            XCTAssertEqual(error, .httpStatus(500))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
