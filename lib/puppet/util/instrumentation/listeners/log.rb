require 'monitor'

# This is an example instrumentation listener that stores the last
# 20 instrumented probe run time.
Puppet::Util::Instrumentation.new_listener(:log) do

  SIZE = 20

  attr_accessor :last_logs

  def initialize
    @last_logs = {}.extend(MonitorMixin)
  end

  def notify(label, event, data)
    return if event == :start
    log_line = "#{label} took #{data[:finished] - data[:started]}"
    @last_logs.synchronize {
      (@last_logs[label] ||= []) << log_line
      @last_logs[label].shift if @last_logs[label].length > SIZE
    }
  end

  def data
    @last_logs.synchronize {
      @last_logs.dup
    }
  end
end