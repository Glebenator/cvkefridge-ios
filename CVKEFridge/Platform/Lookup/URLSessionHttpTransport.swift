import CVKEFridgeFeatures
import Foundation

/// Sends the requests of the product lookup with `URLSession`. The app needs one GET request for each lookup, so it
/// has no HTTP library. The Android file `data/PlatformHttpTransport.kt` has the same behaviour.
///
/// The session keeps nothing on the disk: no cache, no cookies, and no credentials. Only HTTPS is possible. A
/// cancelled task stops its request.
struct URLSessionHttpTransport: HttpTransport {
    /// The largest number of bytes of an answer that the app reads. An answer with only the fields of the app is much
    /// smaller. A longer answer is cut, so it is not valid JSON, and the lookup gives a server failure.
    private static let maxBodyBytes = 256 * 1024

    private let session: URLSession

    /// - Parameter timeout: The longest time to wait for the server, in seconds.
    init(timeout: TimeInterval = 10) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout * 2
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        session = URLSession(configuration: configuration)
    }

    func get(url: URL, headers: [String: String]) async throws -> HttpResponse {
        guard url.scheme == "https" else {
            preconditionFailure("The product lookup uses only HTTPS")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw HttpTransportError.noConnection
            }
            return HttpResponse(status: http.statusCode, body: data.prefix(Self.maxBodyBytes))
        } catch let error as URLError {
            switch error.code {
            case .cancelled:
                throw CancellationError()
            case .timedOut:
                throw HttpTransportError.timeout
            default:
                throw HttpTransportError.noConnection
            }
        }
    }
}
