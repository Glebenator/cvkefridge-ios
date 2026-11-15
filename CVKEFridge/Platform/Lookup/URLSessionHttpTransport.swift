import CVKEFridgeFeatures
import Foundation

/// Sends the requests of the product lookup with `URLSession`. The app needs one GET request for each lookup, so it
/// has no HTTP library. The Android file `data/PlatformHttpTransport.kt` has the same behaviour, with two
/// corrections: a redirect to a different server is not followed, and the request has a limit for its full time.
///
/// What the transport does for the privacy of the person:
///
/// - It sends a request only with HTTPS, and only to `world.openfoodfacts.org`. It refuses each other URL, and it
///   does not follow a redirect to one. So the barcode goes to Open Food Facts and to no other server.
/// - The session keeps nothing: no cache, no cookies, and no credentials.
/// - The system adds the languages of the person to each request (`Accept-Language`). The transport replaces them
///   with `*`. The language that the lookup needs is in the names of the fields of the URL.
///
/// A cancelled task stops its request. The transport does not send a request again by itself.
struct URLSessionHttpTransport: HttpTransport {
    /// The only server that gets a request.
    static let host = "world.openfoodfacts.org"

    /// The largest number of bytes of an answer that the app reads. An answer with only the fields of the app is much
    /// smaller. A longer answer is cut, so it is not valid JSON, and the lookup gives a server failure.
    static let maxBodyBytes = 256 * 1024

    /// The transport refused the URL. It sent nothing.
    struct RefusedURL: Error, Hashable {}

    private let session: URLSession

    /// - Parameters:
    ///   - timeout: The longest time to wait for the server, in seconds. The full request has two times this time.
    ///   - protocolClasses: For a test: the classes that answer in the place of the network.
    init(timeout: TimeInterval = 10, protocolClasses: [AnyClass]? = nil) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout * 2
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.httpAdditionalHeaders = ["Accept-Language": "*"]
        if let protocolClasses {
            configuration.protocolClasses = protocolClasses
        }
        session = URLSession(configuration: configuration, delegate: RedirectGuard(), delegateQueue: nil)
    }

    /// True for a URL that the transport sends: HTTPS to `host`, on the usual port, with no user name.
    static func allows(_ url: URL?) -> Bool {
        guard let url, url.scheme?.lowercased() == "https", url.host()?.lowercased() == host else {
            return false
        }
        return (url.port ?? 443) == 443 && url.user() == nil && url.password() == nil
    }

    func get(url: URL, headers: [String: String]) async throws -> HttpResponse {
        guard Self.allows(url) else {
            throw RefusedURL()
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.httpShouldHandleCookies = false
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        do {
            // The task of the session stops when this task is cancelled.
            let (bytes, response) = try await session.bytes(for: request)
            guard let http = response as? HTTPURLResponse else {
                bytes.task.cancel()
                throw HttpTransportError.noConnection
            }
            var body = Data()
            for try await byte in bytes {
                body.append(byte)
                if body.count >= Self.maxBodyBytes {
                    // The app does not read the remaining bytes.
                    bytes.task.cancel()
                    break
                }
            }
            return HttpResponse(status: http.statusCode, body: body)
        } catch let error as HttpTransportError {
            throw error
        } catch let error as CancellationError {
            throw error
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as URLError where error.code == .timedOut {
            throw HttpTransportError.timeout
        } catch {
            if Task.isCancelled {
                throw CancellationError()
            }
            // No network, a server name that cannot be found, a connection that is not secure, or a network that
            // blocks the request.
            throw HttpTransportError.noConnection
        }
    }
}

/// Stops a redirect to a URL that the transport does not send. The answer of the request is then the redirect
/// itself, which the lookup reads as a failure of the server.
private final class RedirectGuard: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        URLSessionHttpTransport.allows(request.url) ? request : nil
    }
}
