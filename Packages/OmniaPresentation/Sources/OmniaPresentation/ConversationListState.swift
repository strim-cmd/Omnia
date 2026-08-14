import Foundation
import OmniaApplication
import OmniaFoundation

/// The local-calendar activity buckets shown by the conversation list.
public enum ConversationDateGroup: Int, CaseIterable, Equatable, Hashable, Sendable {
    case future
    case today
    case yesterday
    case previousSevenDays
    case older
}

/// One ordered conversation-list section.
public struct ConversationListSection: Equatable, Sendable {
    public let group: ConversationDateGroup
    public let items: [ConversationListItem]

    public init(group: ConversationDateGroup, items: [ConversationListItem]) {
        self.group = group
        self.items = items
    }
}

/// The ready-to-render state of the conversation list: the ordered
/// conversation list items and the empty and error conditions the list
/// presents (DES-012 §3.2, Conversation module, ARC-007).
///
/// The state is owned by the Presentation layer and composed from the
/// `ConversationService` it renders — create, select, and delete (DES-011
/// §3.2, ARC-006). It is session state, never a Domain or Application concept
/// (DES-011 §3.7), immutable, `Equatable` and `Sendable`, and owns no business
/// logic (ARC-002).
///
/// The error condition carries the typed failure the service surfaced — the
/// Domain `RepositoryError`, presented as it is, never wrapped (DES-011 §3.6,
/// DES-009 §3.9); no failure is silent (ARC-001). The state never holds a
/// credential or provider-specific detail (ARC-001, ARC-004, ARC-005).
public struct ConversationListState: Equatable, Sendable {
    /// The ordered conversation list items of the list.
    public let items: [ConversationListItem]
    /// The typed failure of the list operation, when the list is in an error
    /// condition.
    public let failure: RepositoryError?

    /// Creates a conversation list state from the ordered list items and the
    /// optional typed failure.
    public init(
        items: [ConversationListItem],
        failure: RepositoryError? = nil
    ) {
        self.items = items
        self.failure = failure
    }

    /// The empty condition: the list owns no conversations.
    public var isEmpty: Bool {
        items.isEmpty
    }

    /// The error condition: a list operation failed.
    public var hasError: Bool {
        failure != nil
    }

    /// Groups already-sorted rows against the caller's local calendar. Calendar
    /// and clock injection keep midnight, locale/time-zone, old, and future
    /// boundary behavior deterministic in tests.
    public func sections(
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> [ConversationListSection] {
        let buckets = Dictionary(grouping: items) {
            Self.group(for: $0.updatedAt, now: now, calendar: calendar)
        }
        return ConversationDateGroup.allCases.compactMap { group in
            guard let values = buckets[group], !values.isEmpty else { return nil }
            return ConversationListSection(group: group, items: values)
        }
    }

    public static func group(
        for date: Date,
        now: Date,
        calendar: Calendar
    ) -> ConversationDateGroup {
        let today = calendar.startOfDay(for: now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
              let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
              let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today)
        else {
            return .older
        }
        if date >= tomorrow { return .future }
        if date >= today { return .today }
        if date >= yesterday { return .yesterday }
        if date >= sevenDaysAgo { return .previousSevenDays }
        return .older
    }
}
