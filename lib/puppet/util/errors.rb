# Some helper methods for throwing and populating errors.
#
# @api public
module Puppet::Util::Errors
  # Throw a Puppet::DevError with the specified message.  Used for unknown or
  # internal application failures.
  #
  # @param msg [String] message used in raised error
  # @raise [Puppet::DevError] always raised with the supplied message
  def devfail(msg)
    self.fail(Puppet::DevError, msg)
  end

  # Add line and file info to the supplied exception if info is available from
  # this object, is appropriately populated and the supplied exception supports
  # it.  When other is supplied, the backtrace will be copied to the error
  # object and the 'original' will be dropped from the error.
  #
  # @param error [Exception] exception that is populated with info
  # @param other [Exception] original exception, source of backtrace info
  # @return [Exception] error parameter
  def adderrorcontext(error, other = nil)
    error.line ||= self.line if error.respond_to?(:line=) and self.respond_to?(:line) and self.line
    error.file ||= self.file if error.respond_to?(:file=) and self.respond_to?(:file) and self.file
    error.original ||= other if error.respond_to?(:original=)

    error.set_backtrace(other.backtrace) if other and other.respond_to?(:backtrace)
    # It is not meaningful to keep the wrapped exception since its backtrace has already
    # been adopted by the error. (The instance variable is private for good reasons).
    error.instance_variable_set(:@original, nil)
    error
  end

  # Return a human-readable string of this object's file and line attributes,
  # if set.
  #
  # @return [String] description of file and line
  def error_context
    if file and line
      " at #{file}:#{line}"
    elsif line
      " at line #{line}"
    elsif file
      " in #{file}"
    else
      ""
    end
  end

  # Wrap a call in such a way that we always throw the right exception and keep
  # as much context as possible.
  #
  # @param options [Hash<Symbol,Object>] options used to create error
  # @option options [Class] :type error type to raise, defaults to
  #   Puppet::DevError
  # @option options [String] :message message to use in error, default mentions
  #   the name of this class
  # @raise [Puppet::Error] re-raised with extra context if the block raises it
  # @raise [Error] of type options[:type], when the block raises other
  #   exceptions
  def exceptwrap(options = {})
    options[:type] ||= Puppet::DevError
    begin
      return yield
    rescue Puppet::Error => detail
      raise adderrorcontext(detail)
    rescue => detail
      message = options[:message] || "#{self.class} failed with error #{detail.class}: #{detail}"

      error = options[:type].new(message)
      # We can't use self.fail here because it always expects strings,
      # not exceptions.
      raise adderrorcontext(error, detail)
    end

    retval
  end

  # Throw an error, defaulting to a Puppet::Error.
  #
  # @overload fail(message, ..)
  #   Throw a Puppet::Error with a message concatenated from the given
  #   arguments.
  #   @param [String] message error message(s)
  # @overload fail(error_klass, message, ..)
  #   Throw an exception of type error_klass with a message concatenated from
  #   the given arguments.
  #   @param [Class] type of error
  #   @param [String] message error message(s)
  # @overload fail(error_klass, message, ..)
  #   Throw an exception of type error_klass with a message concatenated from
  #   the given arguments.
  #   @param [Class] type of error
  #   @param [String] message error message(s)
  #   @param [Exception] original exception, source of backtrace info
  def fail(*args)
    if args[0].is_a?(Class)
      type = args.shift
    else
      type = Puppet::Error
    end

    other = args.count > 1 ? args.pop : nil
    error = adderrorcontext(type.new(args.join(" ")), other)

    raise error
  end
end
