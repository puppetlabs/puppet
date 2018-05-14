require 'puppet/util/tagging'
require 'puppet/util/classgen'
require 'puppet/util/psych_support'
require 'puppet/network/format_support'
require 'facter'

# Pass feedback to the user.  Log levels are modeled after syslog's, and it is
# expected that that will be the most common log destination.  Supports
# multiple destinations, one of which is a remote server.
class Puppet::Util::Log
  include Puppet::Util
  extend Puppet::Util::ClassGen
  include Puppet::Util::PsychSupport
  include Puppet::Util::Tagging
  include Puppet::Network::FormatSupport

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
    #TRANSLATORS "Log.close_all" is a method name and should not be translated
    raise Puppet::DevError.new(_("Log.close_all failed to close %{destinations}") % { destinations: @destinations.keys.inspect }) if !@destinations.empty?
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
    raise Puppet::DevError, _("Logs require a level") unless hash.include?(:level)
    raise Puppet::DevError, _("Invalid log level %{level}") % { level: hash[:level] } unless @levels.index(hash[:level])
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

    raise Puppet::DevError, _("Invalid loglevel %{level}") % { level: level } unless @levels.include?(level)

    @loglevel = @levels.index(level)

    # Enable or disable Facter debugging
    Facter.debugging(level == :debug) if Facter.respond_to? :debugging
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

    _, type = @desttypes.find do |name, klass|
      klass.match?(dest)
    end

    if type.respond_to?(:suitable?) and not type.suitable?(dest)
      return
    end

    raise Puppet::DevError, _("Unknown destination type %{dest}") % { dest: dest} unless type

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

  def Log.coerce_string(str)
    return Puppet::Util::CharacterEncoding.convert_to_utf_8(str) if str.valid_encoding?

    # We only select the last 10 callers in the stack to avoid being spammy
    message = _("Received a Log attribute with invalid encoding:%{log_message}") %
        { log_message: Puppet::Util::CharacterEncoding.convert_to_utf_8(str.dump)}
    message += '\n' + _("Backtrace:\n%{backtrace}") % { backtrace: caller[0..10].join("\n") }
    message
  end
  private_class_method :coerce_string

  # Route the actual message. FIXME There are lots of things this method
  # should do, like caching and a bit more.  It's worth noting that there's
  # a potential for a loop here, if the machine somehow gets the destination set as
  # itself.
  def Log.newmessage(msg)
    return if @levels.index(msg.level) < @loglevel

    msg.message = coerce_string(msg.message)
    msg.source = coerce_string(msg.source)

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
    Puppet.notice _("Reopening log files")
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
    obj = allocate
    obj.initialize_from_hash(data)
    obj
  end

  # Log output using scope and level
  #
  # @param [Puppet::Parser::Scope] scope
  # @param [Symbol] level log level
  # @param [Array<Object>] vals the values to log (will be converted to string and joined with space)
  #
  def self.log_func(scope, level, vals)
    # NOTE: 3x, does this: vals.join(" ")
    # New implementation uses the evaluator to get proper formatting per type
    vals = vals.map { |v| Puppet::Pops::Evaluator::EvaluatorImpl.new.string(v, scope) }

    # Bypass Puppet.<level> call since it picks up source from "self" which is not applicable in the 4x
    # Function API.
    # TODO: When a function can obtain the file, line, pos of the call merge those in (3x supports
    #       options :file, :line. (These were never output when calling the 3x logging functions since
    #       3x scope does not know about the calling location at that detailed level, nor do they
    #       appear in a report to stdout/error when included). Now, the output simply uses scope (like 3x)
    #       as this is good enough, but does not reflect the true call-stack, but is a rough estimate
    #       of where the logging call originates from).
    #
    Puppet::Util::Log.create({:level => level, :source => scope, :message => vals.join(" ")})
    nil
  end


  attr_accessor :time, :remote, :file, :line, :pos, :source, :issue_code, :environment, :node, :backtrace
  attr_reader :level, :message

  def initialize(args)
    self.level = args[:level]
    self.message = args[:message]
    self.source = args[:source] || "Puppet"

    @time = Time.now

    if tags = args[:tags]
      tags.each { |t| self.tag(t) }
    end

    # Don't add these unless defined (preserve 3.x API as much as possible)
    [:file, :line, :pos, :issue_code, :environment, :node, :backtrace].each do |attr|
      next unless value = args[attr]
      send(attr.to_s + '=', value)
    end

    Log.newmessage(self)
  end

  def initialize_from_hash(data)
    @level = data['level'].intern
    @message = data['message']
    @source = data['source']
    @tags = Puppet::Util::TagSet.new(data['tags'])
    @time = data['time']
    if @time.is_a? String
      @time = Time.parse(@time)
    end
    # Don't add these unless defined (preserve 3.x API as much as possible)
    %w(file line pos issue_code environment node backtrace).each do |name|
      next unless value = data[name]
      send(name + '=', value)
    end
  end

  def to_hash
    self.to_data_hash
  end

  def to_data_hash
    {
      'level' => @level.to_s,
      'message' => to_s,
      'source' => @source,
      'tags' => @tags.to_a,
      'time' => @time.iso8601(9),
      'file' => @file,
      'line' => @line,
    }
  end

  def to_structured_hash
    hash = {
      'level' => @level,
      'message' => @message,
      'source' => @source,
      'tags' => @tags.to_a,
      'time' => @time.iso8601(9),
    }
    %w(file line pos issue_code environment node backtrace).each do |name|
      attr_name = "@#{name}"
      hash[name] = instance_variable_get(attr_name) if instance_variable_defined?(attr_name)
    end
    hash
  end

  def message=(msg)
    #TRANSLATORS 'Puppet::Util::Log' refers to a Puppet source code class
    raise ArgumentError, _("Puppet::Util::Log requires a message") unless msg
    @message = msg.to_s
  end

  def level=(level)
    #TRANSLATORS 'Puppet::Util::Log' refers to a Puppet source code class
    raise ArgumentError, _("Puppet::Util::Log requires a log level") unless level
    #TRANSLATORS 'Puppet::Util::Log' refers to a Puppet source code class
    raise ArgumentError, _("Puppet::Util::Log requires a symbol or string") unless level.respond_to? "to_sym"
    @level = level.to_sym
    raise ArgumentError, _("Invalid log level %{level}") % { level: @level } unless self.class.validlevel?(@level)

    # Tag myself with my log level
    tag(level)
  end

  # If they pass a source in to us, we make sure it is a string, and
  # we retrieve any tags we can.
  def source=(source)
    if defined?(Puppet::Type) && source.is_a?(Puppet::Type)
      @source = source.path
      merge_tags_from(source)
      self.file = source.file
      self.line = source.line
    else
      @source = source.to_s
    end
  end

  def to_report
    "#{time} #{source} (#{level}): #{to_s}"
  end

  def to_s
    msg = message

    # Issue based messages do not have details in the message. It
    # must be appended here
    unless issue_code.nil?
      msg = _("Could not parse for environment %{environment}: %{msg}") % { environment: environment, msg: msg } unless environment.nil?
      msg += Puppet::Util::Errors.error_location_with_space(file, line, pos)
      msg = _("%{msg} on node %{node}") % { msg: msg, node: node } unless node.nil?
      if @backtrace.is_a?(Array)
        msg += "\n"
        msg += @backtrace.join("\n")
      end
    end
    msg
  end

end

# This is for backward compatibility from when we changed the constant to
# Puppet::Util::Log because the reports include the constant name. It was
# considered for removal but left in due to risk of breakage (PUP-7502).
Puppet::Log = Puppet::Util::Log
