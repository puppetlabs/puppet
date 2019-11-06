require 'date'
require 'time'

class Puppet::HTTP::RetryAfterHandler
  def initialize(retry_limit, max_sleep)
    @retry_limit = retry_limit
    @max_sleep = max_sleep
  end

  def retry_after?(request, response)
    case response.code
    when 429, 503
      true
    else
      false
    end
  end

  def retry_after_interval(request, response, retries)
    raise Puppet::HTTP::TooManyRetryAfters.new(request.uri) if retries >= @retry_limit

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
      raise Puppet::HTTP::ProtocolError.new(_("Failed to parse Retry-After header '%{retry_after}' as an integer or RFC 2822 date") % { retry_after: retry_after })
    end
  end
end
