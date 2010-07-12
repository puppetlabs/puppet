# Some helper methods for throwing errors.
module Puppet::Util::Errors
  # Throw a dev error.
  def devfail(msg)
    self.fail(Puppet::DevError, msg)
  end

  # Add line and file info if available and appropriate.
  def adderrorcontext(error, other = nil)
    error.line ||= self.line if self.respond_to?(:line) and self.line
    error.file ||= self.file if self.respond_to?(:file) and self.file

    error.set_backtrace other.backtrace if other and other.respond_to?(:backtrace)

    error
  end

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
  def fail(*args)
    if args[0].is_a?(Class)
      type = args.shift
    else
      type = Puppet::Error
    end

    error = adderrorcontext(type.new(args.join(" ")))

    raise error
  end
end

