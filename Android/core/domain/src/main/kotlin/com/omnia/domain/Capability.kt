package com.omnia.domain

/**
 * Closed capability set matching current Omnia v1.0.0 semantics.
 * Extension points (imageGeneration, audio, etc.) are declared here to
 * establish the taxonomy but are NOT realized product features in v1.
 */
enum class Capability {
    textGeneration,
    conversation,
    streaming,
    vision,
    documentInput,
    imageGeneration,
    embeddings,
    toolCalling,
    structuredOutput,
    audio,
    reasoning;

    companion object {
        /**
         * The three capabilities with a realized contract in v1.0.0.
         * All others are extension points.
         */
        val realized: Set<Capability> = setOf(
            textGeneration,
            conversation,
            streaming,
        )
    }
}
