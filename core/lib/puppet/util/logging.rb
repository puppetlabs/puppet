# A module to make logging a bit easier.
require 'puppet/util/log'
require 'puppet/error'

module Puppet::Util::Logging

  def send_log(level, message)
    Puppet::Util::Log.create({:level => level, :source => log_source, :message => message}.merge(log_metadata))
  end

  # Create a method for each log level.
  Puppet::Util::Log.eachlevel do |level|
    define_method(level) do |args|
      args = args.join(" ") if args.is_a?(Array)
      send_log(level, args)
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
    err(format_exception(exception, message, Puppet[:trace] || options[:trace]))
  end

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
      arr << "Wrapped exception:"
      arr << format_exception(exception.original, :default, trace)
    end
    arr.flatten.join("\n")
  end

  def log_and_raise(exception, message)
    log_exception(exception, message)
    raise exception, message + "\n" + exception.to_s, exception.backtrace
  end

  class DeprecationWarning < Exception; end

  # Log a warning indicating that the code path is deprecated.  Note that this method keeps track of the
  # offending lines of code that triggered the deprecation warning, and will only log a warning once per
  # offending line of code.  It will also stop logging deprecation warnings altogether after 100 unique
  # deprecation warnings have been logged.
  # Parameters:
  # [message] The message to log (logs via )
  def deprecation_warning(message)
    $deprecation_warnings ||= {}
    if $deprecation_warnings.length < 100 then
      offender = get_deprecation_offender()
      if (! $deprecation_warnings.has_key?(offender)) then
        $deprecation_warnings[offender] = message
        warning("#{message}\n   (at #{offender})")
      end
    end
  end

  def get_deprecation_offender()
    # we have to put this in its own method to simplify testing; we need to be able to mock the offender results in
    # order to test this class, and our framework does not appear to enjoy it if you try to mock Kernel.caller
    #
    # let's find the offending line;  we need to jump back up the stack a few steps to find the method that called
    #  the deprecated method
    caller()[2]
  end

  def clear_deprecation_warnings
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

    File.open(deprecations_file, "a") do |f|
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

  private

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
