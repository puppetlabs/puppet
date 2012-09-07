require 'puppet/util/logging'

# Logging utility class that limits the frequency of identical log messages
class Puppet::Util::Log::RateLimitedLogger
  include Puppet::Util::Logging

  def initialize(interval)
    raise ArgumentError, "Logging rate-limit interval must be an integer" unless interval.is_a?(Integer)
    @interval = interval
    @log_record = {}
  end

  # Override the logging entry point to rate-limit it
  def send_log(level, message)
    Puppet::Util::Log.create({:level => level, :message => message}) if should_log?(level, message)
  end

  private

  def should_log?(level, message)
    # Initialize separate records for different levels, and only when needed
    record = (@log_record[level] ||= {})
    last_log = record[message]

    # Skip logging if the time interval since the last logging hasn't elapsed yet
    return false if last_log and within_interval?(last_log)

    # Purge stale entries; do this after the interval check to reduce passes through the cache
    record.delete_if { |key, time| !within_interval?(time) }

    # Reset the beginning of the interval to the current time
    record[message] = Time.now

    true
  end

  def within_interval?(time)
    time + @interval > Time.now
  end
end
