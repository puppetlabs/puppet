# frozen_string_literal: true

require 'date'
require 'time'

# Parse information relating to responses containing a Retry-After headers
#
# @api private
class Puppet::HTTP::RetryAfterHandler
  # Create a handler to allow the system to sleep between HTTP requests
  #
  # @param [Integer] retry_limit number of retries allowed
  # @param [Integer] max_sleep maximum sleep time allowed
  def initialize(retry_limit, max_sleep)
    @retry_limit = retry_limit
    @max_sleep = max_sleep
  end

  # Does the response from the server tell us to wait until we attempt the next
  # retry?
  #
  # @param [Net::HTTP] request
  # @param [Puppet::HTTP::Response] response
  #
  # @return [Boolean] Return true if the response code is 429 or 503, return
  #   false otherwise
  #
  # @api private
  def retry_after?(request, response)
    case response.code
    when 429, 503
      true
    else
      false
    end
  end

  # The amount of time to wait before attempting a retry
  #
  # @param [Net::HTTP] request
  # @param [Puppet::HTTP::Response] response
  # @param [Integer] retries number of retries attempted so far
  #
  # @return [Integer] the amount of time to wait
  #
  # @raise [Puppet::HTTP::TooManyRetryAfters] raise if we have hit our retry
  #   limit
  #
  # @api private
  def retry_after_interval(request, response, retries)
    raise Puppet::HTTP::TooManyRetryAfters, request.uri if retries >= @retry_limit

    retry_after = response['Retry-After']
    return nil unless retry_after

    seconds = parse_retry_after(retry_after)

    # if retry-after is far in the future, we could end up sleeping repeatedly
    # for 30 minutes, effectively waiting indefinitely, seems like we should wait
    # in total for 30 minutes, in which case this upper limit needs to be enforced
    # by the client.
    [seconds, @max_sleep].min
  end

  private

  def parse_retry_after(retry_after)
    Integer(retry_after)
  rescue TypeError, ArgumentError
    begin
      tm = DateTime.rfc2822(retry_after)
      seconds = (tm.to_time - DateTime.now.to_time).to_i
      [seconds, 0].max
    rescue ArgumentError
      raise Puppet::HTTP::ProtocolError, _("Failed to parse Retry-After header '%{retry_after}' as an integer or RFC 2822 date") % { retry_after: retry_after }
    end
  end
end
