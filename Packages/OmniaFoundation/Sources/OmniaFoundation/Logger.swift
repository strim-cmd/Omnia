import Foundation

/// An ordered, deterministic classification of an event's severity.
///
/// The set is fixed and domain-agnostic. Levels order deterministically and
/// compare consistently with equality (DES-005).
public enum LogLevel: Sendable, CaseIterable, Comparable {
    /// Most verbose; detailed diagnostic tracing.
    case trace
    /// Detailed information useful only during development.
    case debug
    /// General operational information.
    case info
    /// Notable events that are normal but noteworthy.
    case notice
    /// An unexpected condition that does not prevent operation.
    case warning
    /// A failure that requires attention.
    case error
    /// A failure that prevents continued operation.
    case critical

    /// Returns whether `lhs` is less severe than `rhs`.
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.severity < rhs.severity
    }

    private var severity: Int {
        switch self {
        case .trace: 0
        case .debug: 1
        case .info: 2
        case .notice: 3
        case .warning: 4
        case .error: 5
        case .critical: 6
        }
    }
}

/// The name of the emitting source, declared by the module that owns it.
///
/// Contexts group events for diagnostics. The abstraction defines the
/// mechanism; the owning module defines its own contexts, and the abstraction
/// carries no product meaning (DES-005).
public struct LogContext: Sendable, Hashable {
    /// The canonical name of the emitting source.
    public let name: String

    /// Creates a context for the emitting source named `name`.
    public init(_ name: String) {
        self.name = name
    }
}

/// Optional structured attributes attached to an event for diagnostics.
///
/// Metadata is preserved by the interface, is never a source of behavior, and
/// never carries sensitive content (DES-005).
public struct LogMetadata: Sendable, Equatable {
    private let attributes: [String: String]

    /// Creates metadata from `attributes`.
    public init(_ attributes: [String: String] = [:]) {
        self.attributes = attributes
    }

    /// Returns the attribute stored for `key`, if any.
    public subscript(_ key: String) -> String? {
        attributes[key]
    }

    /// The number of attributes attached to the event.
    public var count: Int {
        attributes.count
    }
}

/// A value declared by its owner as not loggable.
///
/// A `Sensitive` value has no public accessor to its underlying value, and
/// every representation is a fixed redaction marker. The interface provides
/// no path by which a sensitive value becomes log content; sensitive values
/// are never emitted in any form (DES-005, ARC-001).
public struct Sensitive<Value: Sendable>: Sendable {
    private let value: Value

    private static var redactionMarker: String { "<redacted>" }

    /// Declares `value` as sensitive and therefore not loggable.
    public init(_ value: Value) {
        self.value = value
    }
}

extension Sensitive: CustomStringConvertible {
    public var description: String { Self.redactionMarker }
}

extension Sensitive: CustomDebugStringConvertible {
    public var debugDescription: String { Self.redactionMarker }
}

/// A single diagnostic record: a level, a message, optional metadata, a
/// timestamp obtained through the Clock, and a context.
///
/// An event carries no identity and no product meaning beyond the event it
/// describes. It is delivered to the logger as provided and preserved intact
/// (DES-005).
public struct LogEvent: Sendable, Equatable {
    /// The event's severity classification.
    public let level: LogLevel
    /// The human-readable text of the event. It never carries sensitive content.
    public let message: String
    /// Optional structured attributes attached for diagnostics.
    public let metadata: LogMetadata
    /// The time the event occurred, obtained through the Clock (DES-003).
    public let timestamp: Instant
    /// The name of the emitting source.
    public let context: LogContext

    /// Creates a diagnostic event.
    ///
    /// `timestamp` must be produced by a Clock (DES-003); an event never reads
    /// system time directly.
    public init(
        level: LogLevel,
        message: String,
        metadata: LogMetadata = LogMetadata(),
        timestamp: Instant,
        context: LogContext
    ) {
        self.level = level
        self.message = message
        self.metadata = metadata
        self.timestamp = timestamp
        self.context = context
    }
}

/// The only path by which content enters a log.
///
/// A logger records diagnostic events. Consumers receive a logger by
/// composition and never construct or acquire one (ARC-006). The interface
/// defines emission and nothing else: destinations, formatting, persistence,
/// filtering, and transport are not part of the contract (DES-005).
public protocol Logger: Sendable {
    /// Records a diagnostic event.
    ///
    /// The event is delivered as provided and preserved intact. Whether a
    /// given level is recorded is the implementation's concern, never the
    /// consumer's.
    func log(_ event: LogEvent)
}
