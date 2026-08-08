/// An input validation failure at the application boundary (DES-011 §3.6).
///
/// The application services and use cases validate input before any domain
/// operation and reject invalid input with this typed error, carrying the
/// reason (ARC-009). The taxonomy is built on the Foundation error abstraction
/// (DES-001 §3.9); the Domain errors are surfaced as they are, never wrapped or
/// redefined (DES-009 §3.9).
public enum ApplicationValidationError: Error, Equatable, Sendable {
    /// Input validation failed; `reason` describes the invalid input.
    case invalid(reason: String)
}
