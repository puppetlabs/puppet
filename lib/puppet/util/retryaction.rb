module Puppet::Util::RetryAction
  class RetryException < Exception; end
  class RetryException::NoBlockGiven < RetryException; end
  class RetryException::NoRetriesGiven < RetryException;end
  class RetryException::RetriesExceeded < RetryException; end

  # Execute the supplied block retrying with exponential backoff.
  #
  # @param [Hash] options the retry options
  # @option options [FixNum] :retries Maximum number of times to retry.
  # @option options [Array<Exception>] :retry_exceptions ([StandardError]) Optional array of exceptions that are allowed to be retried.
  # @yield The block to be executed.
  def self.retry_action(options = {})
    # Retry actions for a specified amount of time. This method will allow the final
    # retry to complete even if that extends beyond the timeout period.
    if !block_given?
      raise RetryException::NoBlockGiven
    end

    retries = options[:retries]
    if retries.nil?
      raise RetryException::NoRetriesGiven
    end

    retry_exceptions = options[:retry_exceptions] || [StandardError]
    failures = 0
    begin
      yield
    rescue *retry_exceptions => e
      if failures >= retries
        raise RetryException::RetriesExceeded, "#{retries} exceeded", e.backtrace
      end

      Puppet.info("Caught exception #{e.class}:#{e} retrying")

      failures += 1

      # Increase the amount of time that we sleep after every
      # failed retry attempt.
      sleep (((2 ** failures) -1) * 0.1)

      retry

    end
  end
end
