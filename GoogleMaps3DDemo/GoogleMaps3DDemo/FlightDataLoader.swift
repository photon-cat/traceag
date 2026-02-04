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

public class FlightDataLoader: ObservableObject {

  @Published var flightPathData: FlightPathData = FlightPathData(flight: [])
  @Published var isLoaded: Bool = false

  private let bundle: Bundle

  public init(bundle: Bundle = .main) {
    self.bundle = bundle
    load("flightpath.json")
  }

  public func load(_ path: String, bundle overrideBundle: Bundle? = nil) {
    let sourceBundle = overrideBundle ?? bundle
    if let url = sourceBundle.url(forResource: path, withExtension: nil) {
      if let data = try? Data(contentsOf: url) {
        let jsondecoder = JSONDecoder()
        do {
          let result = try jsondecoder.decode(FlightPathData.self, from: data)
          flightPathData = result
          isLoaded = true
        } catch {
          print("Error trying to load or parse the JSON file.")
        }
      }
    }
  }
}
