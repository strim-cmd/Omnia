package com.omnia.data

import java.io.File

/**
 * Deterministic storage layout. Mirrors iOS StorageLayout.platformRoot()
 * with an Android filesDir-rooted equivalent.
 *
 * Structure:
 *   root/
 *   ├── conversations/
 *   ├── providers/
 *   ├── workspaces/
 *   ├── configuration/
 *   └── attachments/
 *
 * Credentials never appear in this tree.
 */
data class StorageLayout(val root: File) {
    val conversationsDir: File get() = File(root, "conversations")
    val providersDir: File get() = File(root, "providers")
    val workspacesDir: File get() = File(root, "workspaces")
    val configurationDir: File get() = File(root, "configuration")
    val attachmentsDir: File get() = File(root, "attachments")

    fun ensureDirectories() {
        conversationsDir.mkdirs()
        providersDir.mkdirs()
        workspacesDir.mkdirs()
        configurationDir.mkdirs()
        attachmentsDir.mkdirs()
    }

    companion object {
        const val ROOT_DIR_NAME = "omnia"

        fun forFilesDir(filesDir: File): StorageLayout {
            return StorageLayout(File(filesDir, ROOT_DIR_NAME))
        }
    }
}
