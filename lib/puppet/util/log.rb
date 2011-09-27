require 'puppet/util/tagging'
require 'puppet/util/classgen'

# Pass feedback to the user.  Log levels are modeled after syslog's, and it is
# expected that that will be the most common log destination.  Supports
# multiple destinations, one of which is a remote server.
class Puppet::Util::Log
  include Puppet::Util
  extend Puppet::Util::ClassGen
  include Puppet::Util::Tagging

  @levels = [:debug,:info,:notice,:warning,:err,:alert,:emerg,:crit]
  @loglevel = 2

  @desttypes = {}

  # Create a new destination type.
  def self.newdesttype(name, options = {}, &block)

    dest = genclass(
      name,
      :parent     => Puppet::Util::Log::Destination,
      :prefix     => "Dest",
      :block      => block,
      :hash       => @desttypes,
      :attributes => options
    )
    dest.match(dest.name)

    dest
  end

  require 'puppet/util/log/destination'
  require 'puppet/util/log/destinations'

  @destinations = {}

  @queued = []

  class << self
    include Puppet::Util
    include Puppet::Util::ClassGen

    attr_reader :desttypes
  end

  # Reset log to basics.  Basically just flushes and closes files and
  # undefs other objects.
  def Log.close(destination)
    if @destinations.include?(destination)
      @destinations[destination].flush if @destinations[destination].respond_to?(:flush)
      @destinations[destination].close if @destinations[destination].respond_to?(:close)
      @destinations.delete(destination)
    end
  end

  def self.close_all
    destinations.keys.each { |dest|
      close(dest)
    }
    raise Puppet::DevError.new("Log.close_all failed to close #{@destinations.keys.inspect}") if !@destinations.empty?
  end

  # Flush any log destinations that support such operations.
  def Log.flush
    @destinations.each { |type, dest|
      dest.flush if dest.respond_to?(:flush)
    }
  end

  def Log.autoflush=(v)
    @destinations.each do |type, dest|
      dest.autoflush = v if dest.respond_to?(:autoflush=)
    end
  end

  # Create a new log message.  The primary role of this method is to
  # avoid creating log messages below the loglevel.
  def Log.create(hash)
    raise Puppet::DevError, "Logs require a level" unless hash.include?(:level)
    raise Puppet::DevError, "Invalid log level #{hash[:level]}" unless @levels.index(hash[:level])
    @levels.index(hash[:level]) >= @loglevel ? Puppet::Util::Log.new(hash) : nil
  end

  def Log.destinations
    @destinations
  end

  # Yield each valid level in turn
  def Log.eachlevel
    @levels.each { |level| yield level }
  end

  # Return the current log level.
  def Log.level
    @levels[@loglevel]
  end

  # Set the current log level.
  def Log.level=(level)
    level = level.intern unless level.is_a?(Symbol)

    raise Puppet::DevError, "Invalid loglevel #{level}" unless @levels.include?(level)

    @loglevel = @levels.index(level)
  end

  def Log.levels
    @levels.dup
  end

  # Create a new log destination.
  def Log.newdestination(dest)
    # Each destination can only occur once.
    if @destinations.find { |name, obj| obj.name == dest }
      return
    end

    name, type = @desttypes.find do |name, klass|
      klass.match?(dest)
    end

    if type.respond_to?(:suitable?) and not type.suitable?(dest)
      return
    end

    raise Puppet::DevError, "Unknown destination type #{dest}" unless type

    begin
      if type.instance_method(:initialize).arity == 1
        @destinations[dest] = type.new(dest)
      else
        @destinations[dest] = type.new
      end
      flushqueue
      @destinations[dest]
    rescue => detail
      puts detail.backtrace if Puppet[:debug]

      # If this was our only destination, then add the console back in.
      newdestination(:console) if @destinations.empty? and (dest != :console and dest != "console")
    end
  end

  # Route the actual message. FIXME There are lots of things this method
  # should do, like caching and a bit more.  It's worth noting that there's
  # a potential for a loop here, if the machine somehow gets the destination set as
  # itself.
  def Log.newmessage(msg)
    return if @levels.index(msg.level) < @loglevel

    queuemessage(msg) if @destinations.length == 0

    @destinations.each do |name, dest|
      threadlock(dest) do
        dest.handle(msg)
      end
    end
  end

  def Log.queuemessage(msg)
    @queued.push(msg)
  end

  def Log.flushqueue
    return unless @destinations.size >= 1
    @queued.each do |msg|
      Log.newmessage(msg)
    end
    @queued.clear
  end

  def Log.sendlevel?(level)
    @levels.index(level) >= @loglevel
  end

  # Reopen all of our logs.
  def Log.reopen
    Puppet.notice "Reopening log files"
    types = @destinations.keys
    @destinations.each { |type, dest|
      dest.close if dest.respond_to?(:close)
    }
    @destinations.clear
    # We need to make sure we always end up with some kind of destination
    begin
      types.each { |type|
        Log.newdestination(type)
      }
    rescue => detail
      if @destinations.empty?
        Log.newdestination(:syslog)
        Puppet.err detail.to_s
      end
    end
  end

  # Is the passed level a valid log level?
  def self.validlevel?(level)
    @levels.include?(level)
  end

  attr_accessor :time, :remote, :file, :line, :source
  attr_reader :level, :message

  def initialize(args)
    self.level = args[:level]
    self.message = args[:message]
    self.source = args[:source] || "Puppet"

    @time = Time.now

    if tags = args[:tags]
      tags.each { |t| self.tag(t) }
    end

    [:file, :line].each do |attr|
      next unless value = args[attr]
      send(attr.to_s + "=", value)
    end

    Log.newmessage(self)
  end

  def message=(msg)
    raise ArgumentError, "Puppet::Util::Log requires a message" unless msg
    @message = msg.to_s
  end

  def level=(level)
    raise ArgumentError, "Puppet::Util::Log requires a log level" unless level
    @level = level.to_sym
    raise ArgumentError, "Invalid log level #{@level}" unless self.class.validlevel?(@level)

    # Tag myself with my log level
    tag(level)
  end

  # If they pass a source in to us, we make sure it is a string, and
  # we retrieve any tags we can.
  def source=(source)
    if source.respond_to?(:source_descriptors)
      descriptors = source.source_descriptors
      @source = descriptors[:path]

      descriptors[:tags].each { |t| tag(t) }

      [:file, :line].each do |param|
        next unless descriptors[param]
        send(param.to_s + "=", descriptors[param])
      end
    else
      @source = source.to_s
    end
  end

  def to_report
    "#{time} #{source} (#{level}): #{to_s}"
  end

  def to_s
    message
  end
end

# This is for backward compatibility from when we changed the constant to Puppet::Util::Log
# because the reports include the constant name.  Apparently the alias was created in
# March 2007, should could probably be removed soon.
Puppet::Log = Puppet::Util::Log
