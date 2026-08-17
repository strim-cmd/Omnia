package com.omnia.common

/**
 * Immutable semantic version triplet. Mirrors OmniaFoundation.SemanticVersion.
 * Comparable and displayable.
 */
data class SemanticVersion(
    val major: Int,
    val minor: Int,
    val patch: Int,
) : Comparable<SemanticVersion>, java.io.Serializable {

    init {
        require(major >= 0) { "major must be non-negative" }
        require(minor >= 0) { "minor must be non-negative" }
        require(patch >= 0) { "patch must be non-negative" }
    }

    override fun compareTo(other: SemanticVersion): Int {
        val majorCmp = major.compareTo(other.major)
        if (majorCmp != 0) return majorCmp
        val minorCmp = minor.compareTo(other.minor)
        if (minorCmp != 0) return minorCmp
        return patch.compareTo(other.patch)
    }

    override fun toString(): String = "$major.$minor.$patch"

    companion object {
        val zero = SemanticVersion(0, 0, 0)

        fun parse(value: String): SemanticVersion {
            val parts = value.split(".")
            require(parts.size == 3) { "SemanticVersion must have exactly 3 dot-separated components, got: $value" }
            return SemanticVersion(
                major = parts[0].toInt(),
                minor = parts[1].toInt(),
                patch = parts[2].toInt(),
            )
        }
    }
}
