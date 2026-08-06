// OmniaApp — the application shell and Composition Root.
//
// The application-edge package of Omnia (DES-013): the Composition Root, the
// storage layout, the first-run bootstrap, the runtime provider adapter
// binding, and the app-shell launch. It is the only place where Infrastructure
// implementations are referenced (ARC-006, ARC-009): it assembles the object
// graph — the file repositories over the platform Application Support storage
// root, the secure credential storage, the application services of DES-011,
// the provider lifecycle and selection services, and the presentation surfaces
// of DES-012 — and wires it to the running state in `prepare()`. `AppLaunch`
// sequences the launch (compose then bootstrap, DES-013 §3.5) as
// platform-independent logic; the SwiftUI executable target hosts it behind
// platform availability (DES-013 §3.6). The package depends on the five Omnia
// packages and nothing else (ARC-009); the app executable is the only client
// of this package.
