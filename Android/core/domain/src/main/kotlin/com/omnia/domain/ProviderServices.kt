package com.omnia.domain

import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class ProviderLifecycleService {
    private val providers = mutableMapOf<ProviderIdentity, Provider>()
    private val lock = Mutex()

    suspend fun register(connection: ProviderConnection): ProviderIdentity {
        lock.withLock {
            providers[connection.identity] = Provider(connection)
        }
        return connection.identity
    }

    suspend fun provider(identity: ProviderIdentity): Provider? = lock.withLock {
        providers[identity]
    }

    suspend fun state(identity: ProviderIdentity): ProviderState? = lock.withLock {
        providers[identity]?.state
    }

    @Throws(ProviderLifecycleError::class)
    suspend fun transition(identity: ProviderIdentity, newState: ProviderState): Unit = lock.withLock {
        val provider = providers[identity]
            ?: throw ProviderLifecycleError.ProviderNotFound(identity)
        provider.transitionTo(newState)
    }

    suspend fun update(connection: ProviderConnection) {
        lock.withLock {
            val existing = providers[connection.identity]
            if (existing != null) {
                providers[connection.identity] = existing.replacingConnection(connection)
            }
        }
    }

    suspend fun unregister(identity: ProviderIdentity) {
        lock.withLock {
            providers.remove(identity)
        }
    }

    suspend fun allProviders(): List<ProviderIdentity> = lock.withLock {
        providers.keys.toList()
    }

    suspend fun providersReady(capableOf: Capability): List<ProviderIdentity> = lock.withLock {
        providers.values
            .filter { it.state == ProviderState.ready && it.canDeliver(capableOf) }
            .map { it.identity }
            .sortedBy { it.id }
    }
}
