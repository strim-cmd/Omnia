---
title: Product Charter
document_id: PRD-000
version: 0.1.0
status: Draft

owner: Founder
project: Omnia

authors:
  - Founder

reviewers:
  - Chief Architect

created: 2026-08-02
last_updated: 2026-08-02

related_documents:
  - README.md
  - Documentation/Product/VISION.md

supersedes: []

tags:
  - product
  - charter
  - vision
  - strategy
---

# Product Charter

> This document defines the purpose, boundaries, principles, and long-term direction of the Omnia project.
>
> Every significant product or architectural decision MUST be consistent with this document.

---

# Executive Summary

Omnia is a native AI workspace designed exclusively for Apple's platforms.

The application is not an AI provider.

It is not another chatbot.

It is not a cloud platform.

Instead, Omnia provides a beautiful, secure, and high-performance interface that allows users to work with any OpenAI-compatible AI provider through a single native application.

The project is built around a simple idea:

> Users should own their AI experience.

That includes:

- their providers;
- their API keys;
- their conversations;
- their prompts;
- their workflows.

Omnia never attempts to become the center of the user's AI ecosystem.

Instead, it becomes the best interface to it.

---

# Purpose

The purpose of Omnia is to remove friction from interacting with modern AI systems.

Today users often need different applications for different providers.

For example:

- ChatGPT for OpenAI
- Claude for Anthropic
- Gemini for Google
- LM Studio for local models
- Ollama for self-hosted models
- OpenRouter for multi-provider routing

Each application has:

- different user interfaces;
- different shortcuts;
- different capabilities;
- different workflows.

Omnia solves this problem by providing one consistent native experience regardless of the selected provider.

---

# Mission

Build the best native AI client for Apple platforms.

Not the largest.

Not the most feature-rich.

The best.

The application should feel like software designed specifically for macOS, iPadOS, and iOS—not a web application wrapped in a native shell.

Every interaction should respect Apple's Human Interface Guidelines while remaining provider-independent.

---

# Vision

Omnia aims to become the reference implementation of a modern native AI workspace.

Users should be able to switch providers in seconds without changing their workflow.

Developers should be able to add support for new providers without redesigning the application.

The architecture should remain maintainable for many years, allowing the project to evolve without accumulating unnecessary complexity.

---

# Core Problem

The current AI ecosystem is fragmented.

Users are forced to choose between ecosystems rather than interfaces.

Changing providers often means changing applications, habits, shortcuts, and workflows.

This creates unnecessary friction and increases vendor lock-in.

Omnia separates the user interface from the AI provider.

The application becomes stable.

The provider becomes interchangeable.

---

# Success Definition

Omnia is considered successful when users no longer think about which provider they are using.

Instead, they simply choose the model that best fits their current task while remaining inside the same application.

The interface becomes permanent.

The provider becomes replaceable.