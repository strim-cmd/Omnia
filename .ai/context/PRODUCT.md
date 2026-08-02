# Product Context

Summary of what Omnia is, what it is not, and the principles that must govern every product and architectural decision.

Source documents (authoritative):

- `Documentation/Product/VISION.md`
- `Documentation/Product/PRODUCT_CHARTER.md`

## What Omnia Is

- A native AI workspace for Apple platforms (iOS, iPadOS, macOS).
- A client for OpenAI-compatible APIs.
- A privacy-first, local-first application.
- Provider-independent by design.

## What Omnia Is Not

- An AI provider.
- A subscription service.
- A cloud platform or proxy.
- A social network or productivity suite.
- A prompt marketplace.

## Core Idea

Users should own their AI experience:

- their providers,
- their API keys,
- their conversations,
- their prompts,
- their workflows.

Omnia separates the interface from the provider. The interface is stable; the provider is interchangeable.

## Product Principles

1. **User Ownership** — the user owns all data and configuration; Omnia owns none of it.
2. **Privacy by Default** — privacy is the default behavior, not an optional feature.
3. **Native Experience** — every screen and interaction should feel designed by Apple.
4. **Long-Term Maintainability** — decisions optimize for the next five years, not the next release.
5. **Simplicity** — every feature must justify its existence.

## Provider Model

- Works with any OpenAI-compatible endpoint.
- Supports streaming responses.
- Conversations and connections are stored locally.

## Promises

Omnia will never:

- collect analytics by default,
- proxy AI requests,
- store API keys remotely,
- monetize conversations,
- inject advertisements.

## Non-Goals

- Owning user AI accounts.
- Managing billing or subscriptions.
- Routing or aggregating traffic between providers.

## Success Definition

Omnia succeeds when users stop thinking about which provider they are using and simply choose the model that fits the task — inside the same application.

## Related Documents

- `context/PROJECT.md`
- `context/ARCHITECTURE.md`
- `context/STACK.md`
