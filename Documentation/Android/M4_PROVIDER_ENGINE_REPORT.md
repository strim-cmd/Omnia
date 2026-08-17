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
- ProviderInspectors return only Domain model identities and typed errors

## M2 Lifecycle Audit Fixes

Applied to `ProviderConnectionService` in `:core:application`:

1. **Rollback-safe `configureValidated`**: On any failure during provider configuration, all partial writes (provider, credential, configuration values) are rolled back. Matches Swift v1 pattern with flag-based tracking.

2. **Rollback-safe `remove`**: Snapshots provider, credential, endpoint, model, and API kind before removal. On failure, restores all removed state. Matches Swift v1 pattern.

3. **Credential snapshot before removal**: `remove()` now fetches the credential from storage before deletion so it can be restored on rollback failure.

## Provider Parity

| Feature | OpenAI-compatible | Gemini |
|---------|------------------|--------|
| GET /models | Bearer token auth | x-goog-api-key header |
| POST /chat/completions | Authorization header | N/A |
| POST /models/{model}:generateContent | N/A | x-goog-api-key header |
| Streaming | stream=true + SSE | streamGenerateContent?alt=sse + SSE |
| Model name normalization | None needed | Strips `models/` prefix |
| System message handling | system role in messages | systemInstruction field |
| Image attachments | data:URL in content parts | inlineData base64 |
| Discovery fallback | 404/405/501 → one-token chat fallback | Models list authoritative |

## Test Coverage

### :core:network Module

| Test Class | Tests | Focus |
|-----------|-------|-------|
| SSEDecoderTest | 18 | CRLF/LF, byte boundaries, multi-line, EOF flush, real-world chunks |
| ProviderErrorMappingTest | 32 | All three error categories, all HTTP status codes, credential errors |
| OpenAIDTOSerializationTest | 8 | Content format (string vs parts), response/chunk deserialization |
| OpenAIMappingTest | 24 | Request/response mapping, streaming updates, error translation, model IDs |
| OpenAICompatibleClientTest | 8 | Non-streaming, streaming, headers, probe, HTTP errors |
| GeminiMappingTest | 17 | System instruction, content parts, model normalization, endpoint URLs |
| GeminiClientTest | 9 | Generate content, streaming, models, API key header, URL building |
| OpenAIProviderAdapterTest | 5 | Contract compliance, error translation, streaming updates |
| ProviderInspectorTest | 9 | Discovery, validation, fallback, model normalization |
| OkHttpProviderTransportTest | 9 | Send, POST body, headers, status codes, streaming, large body |

**Total: ~139 new tests in core:network**

### M3 Existing Tests (unchanged)

All 304 M3 tests continue to pass. No regressions.

## Security Regression

- Transport error taxonomy: Never leaks OkHttp internals, IOException, or stack traces
- CredentialStorageProtocol used for scoped access; raw keys never enter logs
- ProviderErrorMapping maps all transport errors to Domain error categories
- `toString()` on Credential returns `"Credential(<redacted>)"`

## Commits

1. `fa7ba86` — Commit 1: core:network module, transport, SSE decoder, error mapping
2. `e796049` — Commit 2: OpenAI client, DTOs, mapping, streaming
3. `c187013` — Commit 3: Gemini client, DTOs, mapping, streaming
4. `c66d59e` — Commit 4: Provider adapters, inspectors, binding
5. (pending) — Commit 5: Lifecycle audit, composition root, report
