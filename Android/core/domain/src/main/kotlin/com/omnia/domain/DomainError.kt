package com.omnia.domain

import com.omnia.common.AppError

/**
 * Root error type for the domain layer. Branches are added as the domain grows
 * in later milestones; the M1 seed only needs the base type.
 */
sealed class DomainError(message: String, cause: Throwable? = null) : AppError(message, cause)
