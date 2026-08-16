package com.omnia.common

import java.util.UUID

/**
 * Produces globally unique identifiers. Framework-independent; the default
 * implementation is UUIDv4, the deterministic substitute is [SequentialIdentifierFactory].
 */
interface IdentifierFactory {
    fun newId(): String
}

/** [IdentifierFactory] backed by random UUIDs. */
class RandomIdentifierFactory : IdentifierFactory {
    override fun newId(): String = UUID.randomUUID().toString()
}

/** Deterministic [IdentifierFactory] for tests and previews. */
class SequentialIdentifierFactory(private val prefix: String = "id") : IdentifierFactory {
    private var next = 0
    override fun newId(): String = "$prefix-${next++}"
}
