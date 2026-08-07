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
/// and `\r\n` line endings are accepted. The parser is stateful across
/// `append` calls: an event split across transport chunks is emitted only when
/// complete, and `finish()` flushes any trailing event at the end of the
/// stream.
internal struct SSEDecoder {
    private var buffer = ""
    private var eventName: String?
    private var dataLines: [String] = []
    private var hasFields = false

    /// Ingests `data` and returns any complete events parsed so far.
    ///
    /// Line endings are normalized to `\n` before splitting: the Unicode
    /// grapheme rules fold a CRLF pair into a single character, so searching
    /// for a bare `\n` would never match it.
    mutating func append(_ data: Data) -> [SSEEvent] {
        buffer += normalizeLineEndings(String(decoding: data, as: UTF8.self))
        var events: [SSEEvent] = []
        while let index = buffer.firstIndex(of: "\n") {
            let line = String(buffer[..<index])
            buffer.removeSubrange(...index)
            events.append(contentsOf: process(line: line))
        }
        return events
    }

    private mutating func normalizeLineEndings(_ input: String) -> String {
        input
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    /// Flushes any event left at the end of the stream.
    mutating func finish() -> [SSEEvent] {
        if !buffer.isEmpty {
            _ = process(line: buffer)
            buffer = ""
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
}
