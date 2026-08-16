package com.omnia.application

/**
 * Seed use case for the M1 foundation: provides the static app metadata for the
 * About screen. Demonstrates the explicit-use-case pattern (constructor-injected
 * dependencies, a single [invoke]) that later milestones extend with the real
 * send-message and provider use cases.
 */
class ProvideAppMetadata(private val metadata: AppMetadata) {
    operator fun invoke(): AppMetadata = metadata
}
