require 'puppet'
require 'puppet/util/classgen'
require 'puppet/util/instance_loader'

class Puppet::Util::Instrumentation
  extend Puppet::Util::ClassGen
  extend Puppet::Util::InstanceLoader

  # we're using a ruby lazy autoloader to prevent a loop when requiring listeners
  # since this class sets up an indirection which is also used in Puppet::Indirector::Indirection
  # which is used to setup indirections...
  autoload :Listener, 'puppet/util/instrumentation/listener'
  autoload :Data, 'puppet/util/instrumentation/data'

  # Set up autoloading and retrieving of instrumentation listeners.
  instance_load :listener, 'puppet/util/instrumentation/listeners'

  class << self
    attr_accessor :listeners, :listeners_of
  end

  # instrumentation layer

  # Triggers an instrumentation
  #
  # Call this method around the instrumentation point
  #   Puppet::Util::Instrumentation.instrument(:my_long_computation) do
  #     ... a long computation
  #   end
  #
  # This will send an event to all the listeners of "my_long_computation".
  # Note: this method uses ruby yield directive to call the instrumented code.
  # It is usually way slower than calling start and stop directly around the instrumented code.
  # For high traffic code path, it is thus advisable to not use this method.
  def self.instrument(label, data = {})
    id = self.start(label, data)
    yield
  ensure
    self.stop(label, id, data)
  end

  # Triggers a "start" instrumentation event
  #
  # Important note:
  #  For proper use, the data hash instance used for start should also
  #  be used when calling stop. The idea is to use the current scope
  #  where start is called to retain a reference to 'data' so that it is possible
  #  to send it back to stop.
  #  This way listeners can match start and stop events more easily.
  def self.start(label, data)
    data[:started] = Time.now
    publish(label, :start, data)
    data[:id] = next_id
  end

  # Triggers a "stop" instrumentation event
  def self.stop(label, id, data)
    data[:finished] = Time.now
    publish(label, :stop, data)
  end

  def self.publish(label, event, data)
    each_listener(label) do |k,l|
      l.notify(label, event, data)
    end
  end

  def self.listeners
    @listeners.values
  end

  def self.each_listener(label)
    @listeners_of[label] ||= @listeners.select do |k,l|
      l.listen_to?(label)
    end.each do |l|
      yield l
    end
  end

  # Adds a new listener
  #
  # Usage:
  #   Puppet::Util::Instrumentation.new_listener(:my_instrumentation, pattern) do
  #
  #     def notify(label, data)
  #       ... do something for data...
  #     end
  #   end
  #
  # It is possible to use a "pattern". The listener will be notified only
  # if the pattern match the label of the event.
  # The pattern can be a symbol, a string or a regex.
  # If no pattern is provided, then the listener will be called for every events
  def self.new_listener(name, options = {}, &block)
    Puppet.debug "new listener called #{name}"
    name = name.intern
    listener = genclass(name, :hash => instance_hash(:listener), :block => block)
    listener.send(:define_method, :name) do
      name
    end
    subscribe(listener.new, options[:label_pattern], options[:event])
  end

  def self.subscribe(listener, label_pattern, event)
    raise "Listener #{listener.name} is already subscribed" if @listeners.include?(listener.name)
    Puppet.debug "registering instrumentation listener #{listener.name}"
    @listeners[listener.name] = Listener.new(listener, label_pattern, event)
    listener.subscribed if listener.respond_to?(:subscribed)
    rehash
  end

  def self.unsubscribe(listener)
    Puppet.warning("#{listener.name} hasn't been registered but asked to be unregistered") unless @listeners.include?(listener.name)
    Puppet.info "unregistering instrumentation listener #{listener.name}"
    @listeners.delete(listener.name)
    listener.unsubscribed if listener.respond_to?(:unsubscribed)
    rehash
  end

  def self.init
    # let's init our probe indirection
    require 'puppet/util/instrumentation/indirection_probe'
    @listeners ||= {}
    @listeners_of ||= {}
    instance_loader(:listener).loadall
  end

  def self.clear
    @listeners = {}
    @listeners_of = {}
    @id = 0
  end

  def self.[](key)
    @listeners[key.intern]
  end

  def self.[]=(key, value)
    @listeners[key.intern] = value
    rehash
  end

  private

  def self.rehash
    @listeners_of = {}
  end

  def self.next_id
    @id = (@id || 0) + 1
  end
end
