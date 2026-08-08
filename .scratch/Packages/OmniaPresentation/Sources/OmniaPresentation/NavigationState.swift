import OmniaApplication
import OmniaFoundation

/// The ready-to-render state of the navigation surface: the current route of
/// the navigation structure — which surface the shell presents and the
/// presentation flow that produced it (DES-012 §3.2, §3.5, Navigation module,
/// ARC-007).
///
/// The state is owned by the Presentation layer; the navigation model is the
/// set of destinations — the conversation list, the conversation screen, and
/// the settings surface — and the current route (§3.5). It is session state,
/// never a Domain or Application concept (DES-011 §3.7), immutable,
/// `Equatable` and `Sendable`, and owns no business logic (ARC-002). The
/// routes are value types; the current route is presentation state (ARC-007).
public struct NavigationState: Equatable, Sendable {
    /// A destination of the navigation structure (DES-012 §3.5).
    public enum Route: Equatable, Sendable {
        /// The conversation list.
        case conversationList
        /// The conversation screen, presenting the conversation with the
        /// given identity.
        case conversationScreen(conversation: ConversationIdentity)
        /// The settings surface.
        case settings
    }

    /// The current route of the navigation structure.
    public let currentRoute: Route

    /// Creates a navigation state with the given current route.
    public init(currentRoute: Route) {
        self.currentRoute = currentRoute
    }
}
