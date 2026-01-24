"""Custom application exceptions."""


class AquaBillException(Exception):
    """Base exception for AquaBill."""
    pass


class AuthenticationError(AquaBillException):
    """Authentication failed."""
    pass


class AuthorizationError(AquaBillException):
    """User not authorized for this action."""
    pass


class ResourceNotFound(AquaBillException):
    """Resource not found."""
    pass


class ValidationError(AquaBillException):
    """Validation error."""
    pass


class ConflictError(AquaBillException):
    """Conflict detected (e.g., duplicate reading)."""
    pass


class LateSu bmissionError(AquaBillException):
    """Reading submitted outside allowed window."""
    pass


class InvalidReading(AquaBillException):
    """Reading validation failed."""
    pass
