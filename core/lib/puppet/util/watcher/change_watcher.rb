# Watches for changes over time. It only re-examines the values when it is requested to update readings.
# @api private
class Puppet::Util::Watcher::ChangeWatcher
  def self.watch(reader)
    Puppet::Util::Watcher::ChangeWatcher.new(nil, nil, reader).next_reading
  end

  def initialize(previous, current, value_reader)
    @previous = previous
    @current = current
    @value_reader = value_reader
  end

  def changed?
    if uncertain?
      false
    else
      @previous != @current
    end
  end

  def uncertain?
    @previous.nil? || @current.nil?
  end

  def change_current_reading_to(new_value)
    Puppet::Util::Watcher::ChangeWatcher.new(@current, new_value, @value_reader)
  end

  def next_reading
    change_current_reading_to(@value_reader.call)
  end
end
