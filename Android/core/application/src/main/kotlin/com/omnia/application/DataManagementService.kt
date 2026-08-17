package com.omnia.application

/**
 * Clear-all data management service. The Composition Root supplies the
 * concrete ordered cleanup implementation.
 */
class DataManagementService(
    private val clearAllOperation: suspend () -> Unit,
) {
    /**
     * Removes all user chat data, attachment bytes, provider connections
     * and credentials, and app settings.
     */
    suspend fun clearAll() {
        clearAllOperation()
    }
}
