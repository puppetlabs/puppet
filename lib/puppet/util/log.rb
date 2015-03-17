require 'puppet/util/tagging'
require 'puppet/util/classgen'
require 'puppet/network/format_support'

# Pass feedback to the user.  Log levels are modeled after syslog's, and it is
# expected that that will be the most common log destination.  Supports
# multiple destinations, one of which is a remote server.
class Puppet::Util::Log
  include Puppet::Util
  extend Puppet::Util::ClassGen
  include Puppet::Util::Tagging
  include Puppet::Network::FormatSupport

  @levels = [:debug,:info,:notice,:warning,:err,:alert,:emerg,:crit]
  @loglevel = 2

  @desttypes = {}

  # Create a new destination type.
  def self.newdesttype(name, options = {}, parent = nil, &block)

    dest = genclass(
      name,
      :parent     => parent || Puppet::Util::Log::Destination,
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
    level = hash[:level]
    raise Puppet::DevError, "Logs require a level which is a symbol or string" unless level.respond_to? "to_sym"

    level = level.to_sym
    index = @levels.index(level)
    raise Puppet::DevError, "Invalid log level #{level}" if index.nil?

    if index >= @loglevel
      log = Puppet::Util::Log.new(hash)
      newmessage(log)
      log
    else
      nil
    end
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
      Puppet.log_exception(detail)

      # If this was our only destination, then add the console back in.
      newdestination(:console) if @destinations.empty? and (dest != :console and dest != "console")
    end
  end

  def Log.with_destination(destination, &block)
    if @destinations.include?(destination)
      yield
    else
      newdestination(destination)
      begin
        yield
      ensure
        close(destination)
      end
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
      dest.handle(msg)
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

  # Flush the logging queue.  If there are no destinations available,
  #  adds in a console logger before flushing the queue.
  # This is mainly intended to be used as a last-resort attempt
  #  to ensure that logging messages are not thrown away before
  #  the program is about to exit--most likely in a horrific
  #  error scenario.
  # @return nil
  def Log.force_flushqueue()
    if (@destinations.empty? and !(@queued.empty?))
      newdestination(:console)
    end
    flushqueue
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
        Log.setup_default
        Puppet.err detail.to_s
      end
    end
  end

  def self.setup_default
    Log.newdestination(
      (Puppet.features.syslog?   ? :syslog   :
      (Puppet.features.eventlog? ? :eventlog : Puppet[:puppetdlog])))
  end

  # Is the passed level a valid log level?
  def self.validlevel?(level)
    @levels.include?(level)
  end

  def self.from_data_hash(data)
    symkeyed_data = {}
    data.each_pair { |k,v| symkeyed_data[k.to_sym] = v }
    new(symkeyed_data)
  end

  def self.from_pson(data)
    Puppet.deprecation_warning("from_pson is being removed in favour of from_data_hash.")
    self.from_data_hash(data)
  end

  attr_reader :level, :message, :issue_code, :time, :file, :line, :pos, :backtrace, :source, :node, :environment

  def initialize(args)
    level = args[:level]
    raise ArgumentError, "Puppet::Util::Log requires a log level" if level.nil?
    raise ArgumentError, "Puppet::Util::Log requires that log level is a symbol or string" unless level.respond_to? "to_sym"

    level = level.to_sym
    raise ArgumentError, "Invalid log level #{level}" unless self.class.validlevel?(level)
    @level = level
    # Tag myself with my log level
    tag(level)

    message = args[:message]
    raise ArgumentError, "Puppet::Util::Log requires a message" if message.nil?
    @message = message.to_s

    # Avoid setting these instance variables. We don't want them defined unless they exist
    [:backtrace, :environment, :node, :issue_code, :file, :line, :pos].each do |attr|
      value = args[attr]
      instance_variable_set("@#{attr}", value) unless value.nil?
    end

    self.source = args[:source]
    tags = args[:tags]
    tags.each { |t| tag(t) } unless tags.nil?

    time = args[:time]
    time = Time.parse(time) if time.is_a?(String)
    @time = time || Time.now
  end

  def to_hash
    self.to_data_hash
  end

  def to_data_hash
    hash = {
      'level' => @level,
      'message' => @message,
      'source' => @source,
      'tags' => @tags,
      'time' => @time.iso8601(9),
    }
    [:backtrace, :environment, :node, :issue_code, :file, :line, :pos].each do |attr|
      iv = "@#{attr}"
      hash[attr.to_s] = instance_variable_get(iv) if instance_variable_defined?(iv)
    end
    hash
  end

  def to_pson(*args)
    to_data_hash.to_pson(*args)
  end

  # If they pass a source in to us, we make sure it is a string, and
  # we retrieve any tags we can.
  def source=(source)
    if source.respond_to?(:path)
      source.tags.each { |t| tag(t) }
      @file ||= source.file
      @line ||= source.line
      source = source.path
    end
    @source = source.nil? ? 'Puppet' : source.to_s
  end

  def to_report
    "#{time} #{source} (#{level}): #{to_s}"
  end

  def to_s
    msg = @message
    @file = nil if (@file.is_a?(String) && @file.empty?)
    if @file and @line and @pos
      msg = "#{msg} at #{@file}:#{@line}:#{@pos}"
    elsif @file and @line
      msg ="#{msg} at #{@file}:#{@line}"
    elsif @line and @pos
      msg ="#{msg} at line #{@line}:#{@pos}"
    elsif @line
      msg ="#{msg} at line #{@line}"
    elsif @file
      msg ="#{msg} in #{@file}"
    end
    msg = "Could not parse for environment #{@environment}: #{msg}" if @environment
    msg = "#{msg} on node #{@node}" if @node
    msg = ([msg] + @backtrace).join("\n") if @backtrace
    msg
  end
end

# This is for backward compatibility from when we changed the constant to Puppet::Util::Log
# because the reports include the constant name.  Apparently the alias was created in
# March 2007, should could probably be removed soon.
Puppet::Log = Puppet::Util::Log
