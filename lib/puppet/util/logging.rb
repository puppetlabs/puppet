# A module to make logging a bit easier.
require 'puppet/util/log'
require 'puppet/error'

require 'facter'

module Puppet::Util
module Logging

  def send_log(level, message)
    Puppet::Util::Log.create({:level => level, :source => log_source, :message => message}.merge(log_metadata))
  end

  # Create a method for each log level.
  Puppet::Util::Log.eachlevel do |level|
    # handle debug a special way for performance reasons
    next if level == :debug
    define_method(level) do |args|
      args = args.join(" ") if args.is_a?(Array)
      send_log(level, args)
    end
  end

  # Output a debug log message if debugging is on (but only then)
  # If the output is anything except a static string, give the debug
  # a block - it will be called with all other arguments, and is expected
  # to return the single string result.
  #
  # Use a block at all times for increased performance.
  #
  # @example This takes 40% of the time compared to not using a block
  #  Puppet.debug { "This is a string that interpolated #{x} and #{y} }"
  #
  def debug(*args)
    return nil unless Puppet::Util::Log.level == :debug
    if block_given?
      send_log(:debug, yield(*args))
    else
      send_log(:debug, args.join(" "))
    end
  end

  # Log an exception via Puppet.err.  Will also log the backtrace if Puppet[:trace] is set.
  # Parameters:
  # [exception] an Exception to log
  # [message] an optional String overriding the message to be logged; by default, we log Exception.message.
  #    If you pass a String here, your string will be logged instead.  You may also pass nil if you don't
  #    wish to log a message at all; in this case it is likely that you are only calling this method in order
  #    to take advantage of the backtrace logging.
  def log_exception(exception, message = :default, options = {})
    trace = Puppet[:trace] || options[:trace]
    if message == :default && exception.is_a?(Puppet::ParseErrorWithIssue)
      # Retain all detailed info and keep plain message and stacktrace separate
      backtrace = []
      build_exception_trace(backtrace, exception, trace)
      Puppet::Util::Log.create({
          :level => options[:level] || :err,
          :source => log_source,
          :message => exception.basic_message,
          :issue_code => exception.issue_code,
          :backtrace => backtrace.empty? ? nil : backtrace,
          :file => exception.file,
          :line => exception.line,
          :pos => exception.pos,
          :environment => exception.environment,
          :node => exception.node
        }.merge(log_metadata))
    else
      err(format_exception(exception, message, trace))
    end
  end

  def build_exception_trace(arr, exception, trace = true)
    if trace and exception.backtrace
      exception.backtrace.each do |line|
        arr << line =~ /^(.+):(\d+.*)$/ ? ("#{Pathname($1).realpath}:#{$2}" rescue line) : line
      end
    end
    if exception.respond_to?(:original)
      original =  exception.original
      unless original.nil?
        arr << _('Wrapped exception:')
        arr << original.message
        build_exception_trace(arr, original, trace)
      end
    end
  end
  private :build_exception_trace

  def format_exception(exception, message = :default, trace = true)
    arr = []
    case message
    when :default
      arr << exception.message
    when nil
      # don't log anything if they passed a nil; they are just calling for the optional backtrace logging
    else
      arr << message
    end

    if trace and exception.backtrace
      arr << Puppet::Util.pretty_backtrace(exception.backtrace)
    end
    if exception.respond_to?(:original) and exception.original
      arr << _("Wrapped exception:")
      arr << format_exception(exception.original, :default, trace)
    end
    arr.flatten.join("\n")
  end

  def log_and_raise(exception, message)
    log_exception(exception, message)
    raise exception, message + "\n" + exception.to_s, exception.backtrace
  end

  class DeprecationWarning < Exception; end

  # Logs a warning indicating that the Ruby code path is deprecated.  Note that
  # this method keeps track of the offending lines of code that triggered the
  # deprecation warning, and will only log a warning once per offending line of
  # code.  It will also stop logging deprecation warnings altogether after 100
  # unique deprecation warnings have been logged.  Finally, if
  # Puppet[:disable_warnings] includes 'deprecations', it will squelch all
  # warning calls made via this method.
  #
  # @param message [String] The message to log (logs via warning)
  # @param key [String] Optional key to mark the message as unique. If not
  #   passed in, the originating call line will be used instead.
  def deprecation_warning(message, key = nil)
    issue_deprecation_warning(message, key, nil, nil, true)
  end

  # Logs a warning whose origin comes from Puppet source rather than somewhere
  # internal within Puppet.  Otherwise the same as deprecation_warning()
  #
  # @param message [String] The message to log (logs via warning)
  # @param options [Hash]
  # @option options [String] :file File we are warning from
  # @option options [Integer] :line Line number we are warning from
  # @option options [String] :key (:file + :line) Alternative key used to mark
  #   warning as unique
  #
  # Either :file and :line and/or :key must be passed.
  def puppet_deprecation_warning(message, options = {})
    key = options[:key]
    file = options[:file]
    line = options[:line]
    #TRANSLATORS the literals ":file", ":line", and ":key" should not be translated
    raise Puppet::DevError, _("Need either :file and :line, or :key") if (key.nil?) && (file.nil? || line.nil?)

    key ||= "#{file}:#{line}"
    issue_deprecation_warning(message, key, file, line, false)
  end

  # Logs a (non deprecation) warning once for a given key.
  #
  # @param kind [String] The kind of warning. The
  #   kind must be one of the defined kinds for the Puppet[:disable_warnings] setting.
  # @param message [String] The message to log (logs via warning)
  # @param key [String] Key used to make this warning unique
  # @param file [String,:default,nil] the File related to the warning
  # @param line [Integer,:default,nil] the Line number related to the warning
  #   warning as unique
  # @param level [Symbol] log level to use, defaults to :warning
  #
  # Either :file and :line and/or :key must be passed.
  def warn_once(kind, key, message, file = nil, line = nil, level = :warning)
    return if Puppet[:disable_warnings].include?(kind)
    $unique_warnings ||= {}
    if $unique_warnings.length < 100 then
      if (! $unique_warnings.has_key?(key)) then
        $unique_warnings[key] = message
        call_trace = if file == :default and line == :default
                       # Suppress the file and line number output
                       ''
                     else
                       error_location_str = Puppet::Util::Errors.error_location(file, line)
                       if error_location_str.empty?
                         '\n   ' + _('(file & line not available)')
                       else
                         "\n   %{error_location}" % { error_location: error_location_str }
                       end
                     end
        send_log(level, "#{message}#{call_trace}")
      end
    end
  end

  def get_deprecation_offender()
    # we have to put this in its own method to simplify testing; we need to be able to mock the offender results in
    # order to test this class, and our framework does not appear to enjoy it if you try to mock Kernel.caller
    #
    # let's find the offending line;  we need to jump back up the stack a few steps to find the method that called
    #  the deprecated method
    if Puppet[:trace]
      caller()[2..-1]
    else
      [caller()[2]]
    end
  end

  def clear_deprecation_warnings
    $unique_warnings.clear if $unique_warnings
    $deprecation_warnings.clear if $deprecation_warnings
  end

  # TODO: determine whether there might be a potential use for adding a puppet configuration option that would
  # enable this deprecation logging.

  # utility method that can be called, e.g., from spec_helper config.after, when tracking down calls to deprecated
  # code.
  # Parameters:
  # [deprecations_file] relative or absolute path of a file to log the deprecations to
  # [pattern] (default nil) if specified, will only log deprecations whose message matches the provided pattern
  def log_deprecations_to_file(deprecations_file, pattern = nil)
    # this method may get called lots and lots of times (e.g., from spec_helper config.after) without the global
    # list of deprecation warnings being cleared out.  We don't want to keep logging the same offenders over and over,
    # so, we need to keep track of what we've logged.
    #
    # It'd be nice if we could just clear out the list of deprecation warnings, but then the very next spec might
    # find the same offender, and we'd end up logging it again.
    $logged_deprecation_warnings ||= {}

    # Deprecation messages are UTF-8 as they are produced by Ruby
    Puppet::FileSystem.open(deprecations_file, nil, "a:UTF-8") do |f|
      if ($deprecation_warnings) then
        $deprecation_warnings.each do |offender, message|
          if (! $logged_deprecation_warnings.has_key?(offender)) then
            $logged_deprecation_warnings[offender] = true
            if ((pattern.nil?) || (message =~ pattern)) then
              f.puts(message)
              f.puts(offender)
              f.puts()
            end
          end
        end
      end
    end
  end

  # Sets up Facter logging.
  # This method causes Facter output to be forwarded to Puppet.
  def self.setup_facter_logging!
    # Only recent versions of Facter support this feature
    return false unless Facter.respond_to? :on_message

    # The current Facter log levels are: :trace, :debug, :info, :warn, :error, and :fatal.
    # Convert to the corresponding levels in Puppet
    Facter.on_message do |level, message|
      case level
      when :trace, :debug
        level = :debug
      when :info
        # Same as Puppet
      when :warn
        level = :warning
      when :error
        level = :err
      when :fatal
        level = :crit
      else
        next
      end
      Puppet::Util::Log.create({:level => level, :source => 'Facter', :message => message})
      nil
    end
    true
  end

  private

  def issue_deprecation_warning(message, key, file, line, use_caller)
    return if Puppet[:disable_warnings].include?('deprecations')
    $deprecation_warnings ||= {}
    if $deprecation_warnings.length < 100
      key ||= (offender = get_deprecation_offender)
      unless $deprecation_warnings.has_key?(key)
        $deprecation_warnings[key] = message
        # split out to allow translation
        call_trace = if use_caller
                       _("(location: %{location})") % { location: (offender || get_deprecation_offender).join('; ') }
                     else
                       Puppet::Util::Errors.error_location_with_unknowns(file, line)
                     end
        warning("%{message}\n   %{call_trace}" % { message: message, call_trace: call_trace })
      end
    end
  end

  def is_resource?
    defined?(Puppet::Type) && is_a?(Puppet::Type)
  end

  def is_resource_parameter?
    defined?(Puppet::Parameter) && is_a?(Puppet::Parameter)
  end

  def log_metadata
    [:file, :line, :tags].inject({}) do |result, attr|
      result[attr] = send(attr) if respond_to?(attr)
      result
    end
  end

  def log_source
    # We need to guard the existence of the constants, since this module is used by the base Puppet module.
    (is_resource? or is_resource_parameter?) and respond_to?(:path) and return path.to_s
    to_s
  end
end
end
