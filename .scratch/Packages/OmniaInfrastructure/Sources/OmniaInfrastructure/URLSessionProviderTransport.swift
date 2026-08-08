import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The `ProviderTransport` over `URLSession` (DES-010 §3.5).
///
/// The request and response paths translate every underlying failure into
/// `ProviderTransportError`; raw `URLError` or `NSError` values never leave the
/// transport (ARC-004, DES-009 §3.9). On Apple platforms streaming uses
/// `URLSession.bytes(for:)`; on the Linux build — where that API is
/// unavailable — it uses a `URLSessionDataDelegate`-based streaming task, so
/// the same contract holds on every platform (ARC-005).
internal struct URLSessionProviderTransport: ProviderTransport {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send(_ request: ProviderHTTPRequest) async throws -> ProviderHTTPResponse {
        let urlRequest: URLRequest
        do {
            urlRequest = try Self.urlRequest(from: request)
        } catch {
            throw ProviderTransportError.invalidRequest
        }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw ProviderTransportError.networkFailure
        }
        let statusCode: Int
        guard let http = response as? HTTPURLResponse else {
            throw ProviderTransportError.invalidResponse
        }
        statusCode = http.statusCode
        guard (200..<300).contains(statusCode) else {
            throw ProviderTransportError.httpStatus(statusCode)
        }
        return ProviderHTTPResponse(body: data)
    }

    func stream(_ request: ProviderHTTPRequest) -> AsyncThrowingStream<Data, any Error> {
        let urlRequest: URLRequest
        do {
            urlRequest = try Self.urlRequest(from: request)
        } catch {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: ProviderTransportError.invalidRequest)
            }
        }
        #if canImport(FoundationNetworking)
        return Self.delegateStream(urlRequest: urlRequest)
        #else
        return Self.asyncBytesStream(session: session, urlRequest: urlRequest)
        #endif
    }

    private static func urlRequest(from request: ProviderHTTPRequest) throws -> URLRequest {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method
        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }
        urlRequest.httpBody = request.body
        return urlRequest
    }

    #if !canImport(FoundationNetworking)

    private static func asyncBytesStream(
        session: URLSession,
        urlRequest: URLRequest
    ) -> AsyncThrowingStream<Data, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await session.bytes(for: urlRequest)
                    guard let statusCode = (response as? HTTPURLResponse)?.statusCode else {
                        continuation.finish(throwing: ProviderTransportError.invalidResponse)
                        return
                    }
                    guard (200..<300).contains(statusCode) else {
                        continuation.finish(throwing: ProviderTransportError.httpStatus(statusCode))
                        return
                    }
                    for try await chunk in bytes {
                        continuation.yield(Data([chunk]))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: ProviderTransportError.networkFailure)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    #endif

    #if canImport(FoundationNetworking)

    private static func delegateStream(
        urlRequest: URLRequest
    ) -> AsyncThrowingStream<Data, any Error> {
        AsyncThrowingStream { continuation in
            let delegate = StreamingDataTaskDelegate(continuation: continuation)
            let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
            let task = session.dataTask(with: urlRequest)
            delegate.start(session: session, task: task)
            continuation.onTermination = { _ in task.cancel() }
            task.resume()
        }
    }

    /// A per-stream `URLSessionDataDelegate` for the Linux build, where
    /// `URLSession.bytes(for:)` is unavailable.
    ///
    /// The delegate forwards response data to the stream continuation, checks
    /// the HTTP status, and translates completion failures into
    /// `ProviderTransportError` terms. It retains its session and task so they
    /// stay alive for the stream's duration, and releases them when the task
    /// completes. It is `@unchecked Sendable` because its mutable state is only
    /// touched on the session's delegate queue, where the delegate callbacks
    /// run.
    private final class StreamingDataTaskDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
        private let continuation: AsyncThrowingStream<Data, any Error>.Continuation
        private var session: URLSession?
        private var task: URLSessionTask?
        private var statusCode: Int?

        init(continuation: AsyncThrowingStream<Data, any Error>.Continuation) {
            self.continuation = continuation
            super.init()
        }

        func start(session: URLSession, task: URLSessionTask) {
            self.session = session
            self.task = task
        }

        func urlSession(
            _ session: URLSession,
            dataTask: URLSessionDataTask,
            didReceive response: URLResponse,
            completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
        ) {
            guard let http = response as? HTTPURLResponse else {
                completionHandler(.cancel)
                continuation.finish(throwing: ProviderTransportError.invalidResponse)
                return
            }
            if (200..<300).contains(http.statusCode) {
                completionHandler(.allow)
            } else {
                statusCode = http.statusCode
                completionHandler(.cancel)
            }
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            continuation.yield(data)
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            defer {
                self.session = nil
                self.task = nil
            }
            if let statusCode {
                continuation.finish(throwing: ProviderTransportError.httpStatus(statusCode))
                return
            }
            guard let error else {
                continuation.finish()
                return
            }
            if (error as NSError).code == NSURLErrorCancelled {
                continuation.finish()
            } else {
                continuation.finish(throwing: ProviderTransportError.networkFailure)
            }
        }
    }

    #endif
}
