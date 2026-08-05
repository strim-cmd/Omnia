# Stack Context

Working summary of the Omnia technology stack and its constraints.

Source documents: project `README.md` and `Documentation/`.

## Language

- Swift 6

## User Interface

- SwiftUI (native Apple UI framework)

## Platforms

- iOS
- iPadOS
- macOS

## Communication

- OpenAI-compatible HTTP API
- Streaming responses

## Data

- Local conversation and connection storage
- No remote storage of user data

## Dependency Policy

- Native Apple APIs are preferred over third-party libraries.
- A third-party dependency must justify itself: the problem it solves, why Apple's APIs are insufficient, and its maintenance and security costs.

## License

- MIT

## Related Documents

- `context/ARCHITECTURE.md`
- `standards/SWIFT.md`
- `standards/SECURITY.md`
