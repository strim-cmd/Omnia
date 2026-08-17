package com.omnia.application

/**
 * Boundary validation error. Application services validate input at the
 * boundary before any domain operation (ARC-009).
 */
sealed class ApplicationValidationError(message: String) : Exception(message) {
    data class Invalid(val reason: String) : ApplicationValidationError("Invalid input: $reason")
}
