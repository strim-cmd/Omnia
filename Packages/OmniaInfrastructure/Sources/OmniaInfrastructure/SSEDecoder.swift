import Foundation

/// One Server-Sent Event (DES-010 §3.5).
internal struct SSEEvent: Equatable, Sendable {
    /// The event type from an `event:` field, when present.
    var event: String?
    /// The payload from the `data:` fields, joined with newlines.
    var data: String
}

/// A streaming parser for Server-Sent Events (DES-010 §3.5).
///
/// Ingests the raw byte stream of an SSE response and emits complete events.
/// Events are delimited by a blank line; comments (`:`), `event:`, and multi-
/// line `data:` fields are handled per the SSE specification, and both `\n`
/// and `\r\n` line endings are accepted.
///
/// The parser buffers the raw bytes and decodes each complete line — the run
/// between line terminators — as UTF-8, never a partial slice of the stream.
/// Decoding a partial buffer would replace the bytes of a multi-byte UTF-8
/// character split across transport chunks with U+FFFD, corrupting
/// non-ASCII content; buffering bytes and decoding only complete lines keeps
/// the content exact regardless of how the transport chunks the stream. The
/// parser is stateful across `append` calls: an event split across transport
/// chunks is emitted only when complete, and `finish()` flushes any trailing
/// event at the end of the stream.
internal struct SSEDecoder {
    /// The unconsumed raw bytes of the stream.
    private var buffer = Data()
    private var eventName: String?
    private var dataLines: [String] = []
    private var hasFields = false

    /// Ingests `data` and returns any complete events parsed so far.
    mutating func append(_ data: Data) -> [SSEEvent] {
        buffer.append(data)
        var events: [SSEEvent] = []
        while let terminator = Self.lineTerminator(in: buffer) {
            // A trailing carriage return is held until the next byte decides
            // whether it begins a CRLF pair or ends the line alone.
            if buffer[terminator] == 0x0D && terminator == buffer.index(before: buffer.endIndex) {
                break
            }
            let line = Self.decodeLine(in: buffer, terminator: terminator)
            buffer.removeSubrange(buffer.startIndex..<Self.consumedThrough(in: buffer, terminator: terminator))
            events.append(contentsOf: process(line: line))
        }
        return events
    }

    /// Flushes any event left at the end of the stream.
    mutating func finish() -> [SSEEvent] {
        if !buffer.isEmpty {
            _ = process(line: String(decoding: buffer, as: UTF8.self))
            buffer.removeAll(keepingCapacity: false)
        }
        guard hasFields else { return [] }
        return [dispatchEvent()]
    }

    private mutating func process(line: String) -> [SSEEvent] {
        let line = line.hasSuffix("\r") ? String(line.dropLast()) : line
        if line.isEmpty {
            guard hasFields else { return [] }
            return [dispatchEvent()]
        }
        if line.hasPrefix(":") {
            return []
        }
        let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let field = String(parts[0])
        var value = parts.count > 1 ? String(parts[1]) : ""
        if value.hasPrefix(" ") {
            value.removeFirst()
        }
        switch field {
        case "data":
            dataLines.append(value)
            hasFields = true
        case "event":
            eventName = value
            hasFields = true
        default:
            break
        }
        return []
    }

    private mutating func dispatchEvent() -> SSEEvent {
        defer {
            eventName = nil
            dataLines.removeAll()
            hasFields = false
        }
        return SSEEvent(event: eventName, data: dataLines.joined(separator: "\n"))
    }

    /// Returns the index of the next line terminator — `\n` or `\r` — in the
    /// buffer, or `nil` when the buffer holds no terminator yet.
    private static func lineTerminator(in data: Data) -> Data.Index? {
        data.firstIndex { $0 == 0x0A || $0 == 0x0D }
    }

    /// Returns the raw bytes of the line ending at `terminator`. The half-open
    /// range excludes the terminator byte itself, so the `\r` of a `\r\n` pair
    /// is stripped along with any `\n` terminator.
    private static func decodeLine(in data: Data, terminator: Data.Index) -> String {
        String(decoding: data[data.startIndex..<terminator], as: UTF8.self)
    }

    /// Returns the index just past `terminator` and any `\n` that follows a
    /// `\r`, so the terminator is fully consumed from the buffer.
    private static func consumedThrough(in data: Data, terminator: Data.Index) -> Data.Index {
        if data[terminator] == 0x0A {
            return data.index(after: terminator)
        }
        let after = data.index(after: terminator)
        if after < data.endIndex && data[after] == 0x0A {
            return data.index(after: after)
        }
        return after
    }
}
