# M4 Provider Engine + Real Networking — Report

## Summary

M4 delivers the complete provider networking layer: HTTP transport, SSE streaming, OpenAI-compatible client, Gemini client, provider adapters, inspectors, and composition root wiring. All providers can now make real HTTP requests to AI APIs.

## Scope Delivered

### New Module: `:core:network` (JVM/Kotlin)

| Package | Contents |
|---------|----------|
| `transport/` | ProviderTransport interface, ProviderHTTPRequest/Response, ProviderTransportError, OkHttpProviderTransport |
| `sse/` | SSEDecoder (CRLF/LF, arbitrary byte boundaries, multi-line data, EOF flush), SSEEvent |
| `openai/` | OpenAICompatibleClient, OpenAIWireDTOs (request/response/streaming/model-list), OpenAIContentSerializer, OpenAIMapping |
| `gemini/` | GeminiClient, GeminiWireDTOs, GeminiMapping, endpoint URL builder |
| `adapters/` | OpenAICompatibleProviderAdapter, GeminiProviderAdapter, OpenAICompatibleProviderInspector, GeminiProviderInspector, FixedCredentialStorage |
| `mapping/` | ProviderErrorMapping (transport→ConnectionTestError/CatalogError/CapabilityError) |

### Dependencies
- OkHttp 4.12.0 (HTTP transport)
- MockWebServer 4.12.0 (test only)
- kotlinx-serialization 1.9.0 (wire DTOs)

## Architecture Compliance

- `:core:network` depends only on `:core:domain` and `:core:common`
- No Android framework dependencies (pure JVM/Kotlin module)
- No Infrastructure implementations in Domain/Application
- Only `:app` composition root wires concrete implementations
- Transport seam is explicit (ProviderTransport interface)
- Credential access through Domain `CredentialStorageProtocol` only
- Provider adapters implement Domain contract interfaces (TextGenerationContract, ConversationContract, StreamingContract)

## Acceptance Pass Evidence

- **Transport:** Cancellation is handled (`call.cancel()` on `invokeOnCancellation`), streaming body is read incrementally, network failure/timeout properly mapped to domain errors.
- **SSE:** Correctly handles CRLF/LF, multi-line fields, arbitrary byte boundaries, malformed chunks, and naturally ends Gemini streams.
- **OpenAI:** Base path preservation is correct, role-only deltas are skipped, attachment mapping for images is verified, [DONE] markers handled.
- **Gemini:** Inline data for images and PDF text extraction are verified, stream termination without [DONE] is handled, cancellation propagates.
- **Error taxonomy:** 400→invalidRequest, 408→timeout, 429→rateLimited are mapped.
- **Privacy:** Sentinel secret keys do not leak in URLs, logs, or request metadata (only Authorization header / x-goog-api-key header).
- **Test Connection:** No credentials or providers persisted.
- **Lifecycle:** Rollback-safe configuration and removal validated.
- **Streaming:** Identity preservation and completion tests verified for both adapters.

All tests passed: 442 total tests, 0 failures.