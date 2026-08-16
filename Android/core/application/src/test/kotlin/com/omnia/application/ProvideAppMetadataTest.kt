package com.omnia.application

import org.junit.Assert.assertEquals
import org.junit.Test

class ProvideAppMetadataTest {

    @Test
    fun invoke_returnsInjectedMetadata() {
        val metadata = AppMetadata(
            name = "Omnia",
            marketingVersion = "1.0.1",
            buildNumber = "2",
        )
        val useCase = ProvideAppMetadata(metadata)

        assertEquals(metadata, useCase())
    }

    @Test
    fun versionLabel_joinsVersionAndBuild() {
        val metadata = AppMetadata(name = "Omnia", marketingVersion = "1.0.1", buildNumber = "2")
        assertEquals("1.0.1 (2)", metadata.versionLabel)
    }
}
