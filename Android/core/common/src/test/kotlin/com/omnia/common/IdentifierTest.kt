package com.omnia.common

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

class IdentifierTest {

    @Test
    fun randomIdentifier_isNonEmptyAndUnique() {
        val factory = RandomIdentifierFactory()
        val first = factory.newId()
        val second = factory.newId()
        assert(first.isNotEmpty()) { "identifier must not be empty" }
        assertNotEquals(first, second)
    }

    @Test
    fun sequentialIdentifier_isDeterministic() {
        val factory = SequentialIdentifierFactory(prefix = "item")
        assertEquals("item-0", factory.newId())
        assertEquals("item-1", factory.newId())
        assertEquals("item-2", factory.newId())
    }

    @Test
    fun sequentialIdentifier_instancesDoNotShareState() {
        val a = SequentialIdentifierFactory()
        val b = SequentialIdentifierFactory()
        a.newId()
        assertEquals("id-0", b.newId())
    }
}
