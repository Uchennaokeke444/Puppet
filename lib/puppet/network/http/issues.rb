# frozen_string_literal: true

module Puppet::Network::HTTP::Issues
  NO_INDIRECTION_REMOTE_REQUESTS = :NO_INDIRECTION_REMOTE_REQUESTS
  HANDLER_NOT_FOUND = :HANDLER_NOT_FOUND
  RESOURCE_NOT_FOUND = :RESOURCE_NOT_FOUND
  ENVIRONMENT_NOT_FOUND = :ENVIRONMENT_NOT_FOUND
  RUNTIME_ERROR = :RUNTIME_ERROR
  MISSING_HEADER_FIELD = :MISSING_HEADER_FIELD
  UNSUPPORTED_FORMAT = :UNSUPPORTED_FORMAT
  UNSUPPORTED_METHOD = :UNSUPPORTED_METHOD
  FAILED_AUTHORIZATION = :FAILED_AUTHORIZATION
  UNSUPPORTED_MEDIA_TYPE = :UNSUPPORTED_MEDIA_TYPE
end
