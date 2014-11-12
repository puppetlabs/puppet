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

    retry_exceptions = options[:retry_exceptions] || Hash.new
    retries = options[:retries]

    failures = 0

    begin
      yield
    rescue Exception => e
      # If we were given exceptions to catch,
      # catch the excptions we care about and retry.
      # All others fail hard

      if retries == 0
        raise RetryException::RetriesExceeded, "#{retries} exceeded", e.backtrace
      end

      if retry_exceptions.keys.include?(e.class)
        Puppet.info("Caught exception #{e.class}:#{e}")
        Puppet.info(retry_exceptions[e.class])
      elsif !retry_exceptions.keys.empty?
        # If the exceptions is not in the list of retry_exceptions re-raise.
        raise e
      end

      failures += 1
      retries -= 1

      # Increase the amount of time that we sleep after every
      # failed retry attempt.
      sleep (((2 ** failures) -1) * 0.1)

      retry

    end
  end
end
