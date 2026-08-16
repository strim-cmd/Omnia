package com.omnia.app

import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Architecture verification: the framework-independent layers (core/common,
 * core/domain, core/application) must contain no Android reference and no
 * reverse dependency on features or the app.
 *
 * The build already enforces this (they are pure JVM modules with no Android
 * classpath), and this test proves it at the bytecode level so a regression
 * fails the unit-test gate.
 */
class ArchitectureVerificationTest {

    private val corePrefixes = listOf(
        "com/omnia/common",
        "com/omnia/domain",
        "com/omnia/application",
    )

    private val forbiddenReferences = listOf(
        "android/",
        "androidx/",
        "com/omnia/feature/",
        "com/omnia/app/",
    )

    @Test
    fun coreLayers_areFrameworkIndependentAndHaveNoReverseDependencies() {
        val classPath = System.getProperty("java.class.path").split(File.pathSeparator)
        val offenders = mutableListOf<String>()
        var examined = 0

        for (entry in classPath) {
            val root = File(entry)
            if (root.isDirectory) {
                examined += scanDirectory(root, offenders)
            } else if (root.isFile && root.extension.equals("jar", ignoreCase = true)) {
                examined += scanJar(root, offenders)
            }
        }

        assertTrue("no core class files were examined; classpath layout assumption is wrong", examined > 0)
        assertTrue(
            "framework-independent core layers reference Android or a higher layer:\n" +
                offenders.joinToString("\n"),
            offenders.isEmpty(),
        )
    }

    private fun scanDirectory(root: File, offenders: MutableList<String>): Int {
        var examined = 0
        for (prefix in corePrefixes) {
            val packageDir = File(root, prefix)
            if (!packageDir.exists()) continue
            packageDir.walkTopDown().filter { it.isFile && it.extension == "class" }.forEach { classFile ->
                examined++
                scanClass(classFile.readBytes(), classFile.absolutePath, offenders)
            }
        }
        return examined
    }

    private fun scanJar(jarFile: File, offenders: MutableList<String>): Int {
        var examined = 0
        java.util.jar.JarFile(jarFile).use { jar ->
            jar.entries().asSequence().forEach { entry ->
                if (entry.isDirectory || !entry.name.endsWith(".class")) return@forEach
                if (corePrefixes.none { entry.name.startsWith(it) }) return@forEach
                examined++
                scanClass(jar.getInputStream(entry).use { it.readBytes() }, entry.name, offenders)
            }
        }
        return examined
    }

    private fun scanClass(bytes: ByteArray, source: String, offenders: MutableList<String>) {
        val text = String(bytes, Charsets.ISO_8859_1)
        for (forbidden in forbiddenReferences) {
            if (text.contains(forbidden)) {
                offenders += "$source -> references '$forbidden'"
            }
        }
    }
}
