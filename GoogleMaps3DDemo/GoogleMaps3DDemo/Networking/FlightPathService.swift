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

protocol NetworkSession {
    func data(from url: URL) async throws -> (Data, URLResponse)
}

extension URLSession: NetworkSession {}

enum FlightPathServiceError: Error, Equatable {
    case invalidResponse
    case httpStatus(Int)
}

struct FlightPathService {
    var session: NetworkSession
    var decoder: JSONDecoder

    init(session: NetworkSession = URLSession.shared, decoder: JSONDecoder = JSONDecoder()) {
        self.session = session
        self.decoder = decoder
    }

    func fetchFlightPath(from url: URL) async throws -> FlightPathData {
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FlightPathServiceError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw FlightPathServiceError.httpStatus(httpResponse.statusCode)
        }
        return try decoder.decode(FlightPathData.self, from: data)
    }
}
