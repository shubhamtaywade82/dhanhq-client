# frozen_string_literal: true

module DhanHQ
  # Base error class for all DhanHQ API errors
  class Error < StandardError; end

  # Authentication and access errors
  # Raised when access token cannot be resolved (missing config or provider returned nil).
  class AuthenticationError < Error; end
  # DH-901
  class InvalidAuthenticationError < Error; end
  # DH-902
  class InvalidAccessError < Error; end
  # DH-903
  class UserAccountError < Error; end
  # DH-808
  class AuthenticationFailedError < Error; end
  # DH-807: token expired (detected from API response; use with retry-on-401)
  class TokenExpiredError < Error; end
  # DH-807, DH-809
  class InvalidTokenError < Error; end
  # DH-810
  class InvalidClientIDError < Error; end

  # Rate limits and input validation errors
  # DH-904, 805
  class RateLimitError < Error; end
  # DH-905
  class InputExceptionError < Error; end
  # DH-811, DH-812, DH-813, DH-814
  class InvalidRequestError < Error; end
  # Validation errors for input parameters
  class ValidationError < Error; end

  # Order and market data errors
  class OrderError < Error; end
  # Raised when the API signals an issue with the requested data payload.
  class DataError < Error; end

  # Server and network-related errors
  # DH-908, 800
  class InternalServerError < Error; end
  # DH-1111
  class NoHoldingsError < Error; end
  # DH-909
  class NetworkError < Error; end
  # DH-910
  class OtherError < Error; end
  # 404
  class NotFoundError < Error; end
end
