import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// HTTP geocoder backed by Photon (photon.komoot.io, OSM data) — CoreLocation's
/// CLGeocoder does not exist on Android. Forward lookup for the store search,
/// English reverse lookup for the eloshowdown community bridge.
final class HTTPGeocoder: @unchecked Sendable {
    static let shared = HTTPGeocoder()

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        self.session = URLSession(configuration: config)
    }

    struct Coordinate: Sendable {
        let latitude: Double
        let longitude: Double
    }

    /// City/place text → coordinate. nil when the text isn't a known place.
    func geocode(_ text: String) async -> Coordinate? {
        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://photon.komoot.io/api/?q=\(encoded)&limit=1")
        else { return nil }
        guard let json = await fetchJSON(url) else { return nil }
        guard let features = json["features"] as? [[String: Any]],
              let geometry = features.first?["geometry"] as? [String: Any],
              let coords = geometry["coordinates"] as? [Double],
              coords.count >= 2
        else { return nil }
        // GeoJSON order: [longitude, latitude]
        return Coordinate(latitude: coords[1], longitude: coords[0])
    }

    /// Coordinate → English city name (for matching eloshowdown communities,
    /// which are English-only slugs).
    func reverseCityEnglish(latitude: Double, longitude: Double) async -> (city: String?, country: String?) {
        guard let url = URL(string: "https://photon.komoot.io/reverse?lat=\(latitude)&lon=\(longitude)&lang=en")
        else { return (nil, nil) }
        guard let json = await fetchJSON(url),
              let features = json["features"] as? [[String: Any]],
              let props = features.first?["properties"] as? [String: Any]
        else { return (nil, nil) }
        let city = (props["city"] as? String) ?? (props["name"] as? String)
        let country = props["country"] as? String
        return (city, country)
    }

    private func fetchJSON(_ url: URL) async -> [String: Any]? {
        var request = URLRequest(url: url)
        request.setValue("Riftcount-Android", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json
    }
}
