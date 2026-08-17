package com.omnia.domain

data class Workspace(
    val identity: WorkspaceIdentity,
    val name: String,
    val conversationIdentities: Set<ConversationIdentity> = emptySet(),
    val providerIdentities: Set<ProviderIdentity> = emptySet(),
) {
    init {
        require(name.isNotBlank()) { "Workspace name must not be blank" }
    }

    fun contains(conversation: ConversationIdentity): Boolean =
        conversation in conversationIdentities

    fun contains(provider: ProviderIdentity): Boolean =
        provider in providerIdentities

    fun adding(conversation: ConversationIdentity): Workspace =
        copy(conversationIdentities = conversationIdentities + conversation)

    fun removing(conversation: ConversationIdentity): Workspace =
        copy(conversationIdentities = conversationIdentities - conversation)

    fun adding(provider: ProviderIdentity): Workspace =
        copy(providerIdentities = providerIdentities + provider)

    fun removing(provider: ProviderIdentity): Workspace =
        copy(providerIdentities = providerIdentities - provider)
}
