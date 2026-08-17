package com.omnia.data.provider

import com.omnia.common.SemanticVersion
import com.omnia.domain.*
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import java.io.File
import java.nio.file.Files

class FileProviderRepositoryTest {

    private lateinit var tempDir: File
    private lateinit var repo: FileProviderRepository

    @Before
    fun setup() {
        tempDir = Files.createTempDirectory("ProviderRepoTests").toFile()
        repo = FileProviderRepository(tempDir)
    }

    @After
    fun teardown() {
        tempDir.deleteRecursively()
    }

    @Test
    fun save_then_load_roundTripsProvider() = runBlocking {
        val provider = makeProvider("prov-1", ProviderState.ready)
        repo.save(provider)

        val loaded = repo.provider(ProviderIdentity("prov-1"))
        assertNotNull(loaded)
        assertEquals("prov-1", loaded!!.identity.id)
        assertEquals(ProviderState.ready, loaded.state)
    }

    @Test
    fun save_then_load_roundTripsEveryLifecycleState() = runBlocking {
        for (state in ProviderState.entries) {
            if (state == ProviderState.removed) continue
            val provider = makeProvider("prov-${state.name}", state)
            repo.save(provider)
            val loaded = repo.provider(ProviderIdentity("prov-${state.name}"))
            assertNotNull(loaded)
            assertEquals(state, loaded!!.state)
        }
    }

    @Test
    fun save_then_load_preservesDeclaredConnection() = runBlocking {
        val provider = Provider.atState(
            ProviderConnection(
                identity = ProviderIdentity("prov-1"),
                capabilities = ProviderCapabilities(setOf(Capability.textGeneration, Capability.streaming)),
                metadata = ProviderMetadata(displayName = "Test Provider"),
                limits = ProviderLimits(maxContextTokens = 4096),
                version = SemanticVersion(1, 2, 3),
            ),
            ProviderState.ready,
        )
        repo.save(provider)

        val loaded = repo.provider(ProviderIdentity("prov-1"))!!
        assertEquals(setOf(Capability.textGeneration, Capability.streaming), loaded.connection.capabilities.capabilities)
        assertEquals("Test Provider", loaded.connection.metadata.displayName)
        assertEquals(4096, loaded.connection.limits.maxContextTokens)
        assertEquals(SemanticVersion(1, 2, 3), loaded.connection.version)
    }

    @Test
    fun save_replacesExistingProviderWithSameIdentity() = runBlocking {
        val first = makeProvider("prov-1", ProviderState.registered)
        repo.save(first)

        val second = makeProvider("prov-1", ProviderState.ready)
        repo.save(second)

        val loaded = repo.provider(ProviderIdentity("prov-1"))!!
        assertEquals(ProviderState.ready, loaded.state)
    }

    @Test
    fun provider_withAbsentIdentityReturnsNull() = runBlocking {
        assertNull(repo.provider(ProviderIdentity("nonexistent")))
    }

    @Test
    fun allProviders_returnsEveryStoredProvider() = runBlocking {
        repo.save(makeProvider("prov-1", ProviderState.ready))
        repo.save(makeProvider("prov-2", ProviderState.registered))

        val all = repo.allProviders()
        assertEquals(2, all.size)
    }

    @Test
    fun allProviders_emptyRepositoryReturnsEmpty() = runBlocking {
        assertTrue(repo.allProviders().isEmpty())
    }

    @Test
    fun allProviders_skipsOneMalformedRecordWithoutDeletingIt() = runBlocking {
        repo.save(makeProvider("prov-1", ProviderState.ready))
        File(tempDir, "malformed.json").writeText("{not valid json!!!")

        val all = repo.allProviders()
        assertEquals(1, all.size)
        assertEquals("prov-1", all[0].identity.id)
        assertTrue(File(tempDir, "malformed.json").exists())
    }

    @Test
    fun delete_removesTheProvider() = runBlocking {
        repo.save(makeProvider("prov-1", ProviderState.ready))
        repo.delete(ProviderIdentity("prov-1"))
        assertNull(repo.provider(ProviderIdentity("prov-1")))
    }

    @Test
    fun delete_absentIdentityIsNotAnError() = runBlocking {
        repo.delete(ProviderIdentity("nonexistent"))
    }

    @Test
    fun delete_isIdempotent() = runBlocking {
        repo.save(makeProvider("prov-1", ProviderState.ready))
        repo.delete(ProviderIdentity("prov-1"))
        repo.delete(ProviderIdentity("prov-1"))
    }

    @Test
    fun removeAll_removesAllJsonFiles() = runBlocking {
        repo.save(makeProvider("prov-1", ProviderState.ready))
        repo.removeAll()
        assertTrue(repo.allProviders().isEmpty())
    }

    @Test
    fun removeAll_preservesNonJsonFiles() = runBlocking {
        repo.save(makeProvider("prov-1", ProviderState.ready))
        File(tempDir, "keep.txt").writeText("not json")
        repo.removeAll()
        assertTrue(repo.allProviders().isEmpty())
        assertTrue(File(tempDir, "keep.txt").exists())
    }

    @Test
    fun freshInstance_loadsPreviouslyPersistedData() = runBlocking {
        repo.save(makeProvider("prov-1", ProviderState.ready))

        val freshRepo = FileProviderRepository(tempDir)
        val loaded = freshRepo.provider(ProviderIdentity("prov-1"))
        assertNotNull(loaded)
        assertEquals(ProviderState.ready, loaded!!.state)
        assertEquals(1, freshRepo.allProviders().size)
    }

    @Test
    fun freshInstance_seesAllProviders() = runBlocking {
        repo.save(makeProvider("prov-1", ProviderState.ready))
        repo.save(makeProvider("prov-2", ProviderState.registered))

        val freshRepo = FileProviderRepository(tempDir)
        assertEquals(2, freshRepo.allProviders().size)
    }

    private fun makeProvider(id: String, state: ProviderState): Provider {
        val connection = ProviderConnection(
            identity = ProviderIdentity(id),
            capabilities = ProviderCapabilities(setOf(Capability.textGeneration)),
            metadata = ProviderMetadata(displayName = "Provider $id"),
            limits = ProviderLimits(),
            version = SemanticVersion(1, 0, 0),
        )
        return Provider.atState(connection, state)
    }
}
