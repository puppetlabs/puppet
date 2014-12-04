module Puppet::Util::RetryAction
  class RetryException < Exception; end
  class RetryException::NoBlockGiven < RetryException; end
  class RetryException::NoRetriesGiven < RetryException;end
  class RetryException::RetriesExceeded < RetryException; end

  def self.retry_action( options = { :retry_exceptions => nil, :retries => nil } )
    # Retry actions for a specified amount of time. This method will allow the final
    # retry to complete even if that extends beyond the timeout period.
    if !block_given?
      raise RetryException::NoBlockGiven
    end
    if options[:retries].nil?
      raise RetryException::NoRetriesGiven
    end

    retry_exceptions = options[:retry_exceptions] || [StandardError]
    retries = options[:retries]

    failures = 0

    begin
      yield
    rescue *retry_exceptions => e
      if retries == 0
        raise RetryException::RetriesExceeded, "#{retries} exceeded", e.backtrace
      end

      Puppet.info("Caught exception #{e.class}:#{e} retrying")

      failures += 1
      retries -= 1

      # Increase the amount of time that we sleep after every
      # failed retry attempt.
      sleep (((2 ** failures) -1) * 0.1)

      retry

    end
  end
end
