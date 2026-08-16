package com.omnia.common

/**
 * Base application error abstraction. Every domain and application error is a
 * subclass of [AppError], so callers can handle one root type while branches
 * remain typed. Open (not sealed) deliberately: domain/application layers live
 * in their own modules and must be able to extend it.
 */
abstract class AppError(
    message: String,
    cause: Throwable? = null,
) : Exception(message, cause) {

    /** An argument or input value was rejected. */
    class InvalidArgument(message: String, cause: Throwable? = null) : AppError(message, cause)

    /** The requested entity could not be found. */
    class NotFound(message: String, cause: Throwable? = null) : AppError(message, cause)

    /** A required capability is not available right now. */
    class NotAvailable(message: String, cause: Throwable? = null) : AppError(message, cause)

    /** The operation was cancelled by the user or the system. */
    class OperationCancelled(message: String, cause: Throwable? = null) : AppError(message, cause)

    /** An unexpected, unrecoverable failure. */
    class Unexpected(message: String, cause: Throwable? = null) : AppError(message, cause)
}
