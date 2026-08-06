import OmniaApplication
import OmniaFoundation

/// The navigation presentation surface: the shell that hosts and routes
/// between the conversation and settings surfaces (DES-012 §3.5, Navigation
/// module, ARC-007).
///
/// The surface is the seam through which the conversation and settings
/// presentation surfaces are delivered to the navigation structure (DES-012
/// §3.6, ARC-006). It receives them through its public initializer and hosts
/// them — the shell reaches the conversation and settings surfaces only through
/// these presentation surfaces and never references the application services
/// they host (§3.6). The navigation structure and presentation flow between the
/// destinations — the conversation list opens a conversation and reaches the
/// settings surface — are realized by the view layer with the platform-native
/// Navigation container (ADR-0001), routing through the frozen `NavigationState`
/// model (§3.5, §3.7).
///
/// It composes the frozen surfaces and owns no business logic (ARC-002,
/// ARC-007): the conversation and settings surfaces own their operations, and
/// the surface neither constructs their services nor redefines their behavior.
/// The routes of the navigation model are value types; the current route is
/// presentation state owned at the application edge (ARC-007, DES-012 §3.2).
///
/// The surface never references a concrete Infrastructure implementation and
/// never performs networking, persistence, or credential operations (ARC-002,
/// ADR-0002).
///
/// The surface is a stateless, `Sendable` value type; every operation is
/// deterministic and testable on the Linux build environment (DES-012 §3.7).
public struct NavigationSurface: Sendable {
    /// The conversation list surface the shell hosts — the root destination of
    /// the navigation structure (DES-012 §3.5).
    public let conversationList: ConversationListSurface

    /// The conversation screen surface the shell hosts — the destination a
    /// conversation from the list opens.
    public let conversationScreen: ConversationScreenSurface

    /// The settings surface the shell hosts — the destination the shell reaches
    /// from the conversation list.
    public let settings: SettingsSurface

    /// Creates a navigation surface over the given conversation list,
    /// conversation screen, and settings surfaces, delivered by the Composition
    /// Root (DES-012 §3.6).
    ///
    /// The surface hosts the delivered surfaces; it does not construct their
    /// services (§3.6).
    public init(
        conversationList: ConversationListSurface,
        conversationScreen: ConversationScreenSurface,
        settings: SettingsSurface
    ) {
        self.conversationList = conversationList
        self.conversationScreen = conversationScreen
        self.settings = settings
    }
}
