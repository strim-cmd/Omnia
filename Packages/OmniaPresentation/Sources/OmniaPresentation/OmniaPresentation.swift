// OmniaPresentation — the user interface and presentation surfaces.
//
// The Presentation layer package of Omnia (DES-012): the platform-independent
// presentation value types, presentation state, and navigation model, and the
// Apple-platform SwiftUI view layer (built in later phases). It renders the
// frozen application services of DES-011 and owns no business logic (ARC-002,
// ADR-0001). The package depends only on OmniaApplication and OmniaFoundation
// among Omnia packages (ARC-009); the Domain vocabulary it holds is the
// vocabulary exposed through the OmniaApplication public interface (DES-012 §4).
