package com.omnia.common

import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers

/**
 * Provides the coroutine dispatchers used by the application layer.
 *
 * Framework-independent: the JVM substitute maps [main] to [Dispatchers.Default]
 * because there is no Android main looper on the JVM. The app layer replaces it
 * with the Android main dispatcher (kotlinx-coroutines-android). Tests inject a
 * deterministic substitute built on test dispatchers.
 */
interface DispatcherProvider {
    val main: CoroutineDispatcher
    val io: CoroutineDispatcher
    val default: CoroutineDispatcher
    val unconfined: CoroutineDispatcher
}

/** JVM default: [main] falls back to [Dispatchers.Default]. */
object JvmDispatchers : DispatcherProvider {
    override val main: CoroutineDispatcher = Dispatchers.Default
    override val io: CoroutineDispatcher = Dispatchers.IO
    override val default: CoroutineDispatcher = Dispatchers.Default
    override val unconfined: CoroutineDispatcher = Dispatchers.Unconfined
}

/** Maps every slot to a single dispatcher; used by tests for determinism. */
class SingleDispatcherProvider(dispatcher: CoroutineDispatcher) : DispatcherProvider {
    override val main: CoroutineDispatcher = dispatcher
    override val io: CoroutineDispatcher = dispatcher
    override val default: CoroutineDispatcher = dispatcher
    override val unconfined: CoroutineDispatcher = dispatcher
}
