import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// An HTTP request exchanged through the transport seam (DES-010 §3.5).
internal struct ProviderHTTPRequest: Equatable, Sendable {
    var url: URL
    var method: String
    var headers: [String: String]
    var body: Data?
}

/// The body of a successful transport response (DES-010 §3.5).
///
/// The transport validates the HTTP status before returning; a non-2xx status
/// surfaces as `ProviderTransportError.httpStatus` instead.
internal struct ProviderHTTPResponse: Equatable, Sendable {
    var body: Data
}

/// The failures the transport surface reports (DES-010 §3.7).
///
/// Raw platform and HTTP values never leak: every underlying failure is
/// translated into this typed surface, and adapters translate these into the
/// terms the Domain owns (ARC-004, DES-009 §3.9). The `httpStatus` case
/// carries the status code so an adapter can distinguish authentication, rate
/// limit, and availability failures.
internal enum ProviderTransportError: Error, Equatable, Sendable {
    /// The request could not be represented on the wire.
    case invalidRequest
    /// The response was not a valid HTTP response or could not be decoded.
    case invalidResponse
    /// The endpoint answered with a non-2xx status.
    case httpStatus(Int)
    /// The underlying network interaction failed.
    case networkFailure
    /// The network interaction exceeded its timeout.
    case timedOut
}

/// The transport seam: isolates HTTP interaction so the client and its
/// consumers are testable without a network (DES-010 §3.5, ARC-001, ARC-006).
///
/// The seam is internal to the package; its consumers are the provider
/// adapters and the OpenAI-compatible client. Both operations translate
/// underlying failures into `ProviderTransportError`; non-2xx statuses surface
/// as `httpStatus` in both the request and the stream path (ARC-004).
internal protocol ProviderTransport: Sendable {
    /// Sends `request` and returns the response body.
    ///
    /// Throws `ProviderTransportError.httpStatus` on a non-2xx status.
    func send(_ request: ProviderHTTPRequest) async throws -> ProviderHTTPResponse

    /// Streams the response body of `request` as it arrives.
    ///
    /// The stream yields the raw body data and finishes with
    /// `ProviderTransportError` (an `any Error` failure, the only error this
    /// surface throws): `httpStatus` on a non-2xx status and `networkFailure`
    /// when the underlying network interaction fails.
    func stream(_ request: ProviderHTTPRequest) -> AsyncThrowingStream<Data, any Error>
}
