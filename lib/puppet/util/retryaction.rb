module Puppet::Util::RetryAction
  class RetryException < Exception; end
  class RetryException::NoBlockGiven < RetryException; end
  class RetryException::NoRetriesGiven < RetryException;end
  class RetryException::RetriesExceeded < RetryException; end

  def self.retry_action( parameters = { :retry_exceptions => nil, :retries => nil } )
    # Retry actions for a specified amount of time. This method will allow the final
    # retry to complete even if that extends beyond the timeout period.
    unless block_given?
      raise RetryException::NoBlockGiven
    end

    raise RetryException::NoRetriesGiven if parameters[:retries].nil?
    parameters[:retry_exceptions] ||= Hash.new

    failures = 0

    begin
      yield
    rescue Exception => e
      # If we were giving exceptions to catch,
      # catch the excptions we care about and retry.
      # All others fail hard

      raise RetryException::RetriesExceeded, "#{parameters[:retries]} exceeded", e.backtrace if parameters[:retries] == 0

      if (not parameters[:retry_exceptions].keys.empty?) and parameters[:retry_exceptions].keys.include?(e.class)
        Puppet.info("Caught exception #{e.class}:#{e}")
        Puppet.info(parameters[:retry_exceptions][e.class])
      elsif (not parameters[:retry_exceptions].keys.empty?)
        # If the exceptions is not in the list of retry_exceptions re-raise.
        raise e
      end

      failures += 1
      parameters[:retries] -= 1

      # Increase the amount of time that we sleep after every
      # failed retry attempt.
      sleep (((2 ** failures) -1) * 0.1)

      retry

    end
  end
end
