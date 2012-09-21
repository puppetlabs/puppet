# Where we store helper methods related to, um, methods.
module Puppet::Util::MethodHelper
  extend self

  def requiredopts(*names)
    names.each do |name|
      devfail("#{name} is a required option for #{self.class}") if self.send(name).nil?
    end
  end

  # Iterate over a hash, treating each member as an attribute.
  def set_options(options)
    options.each do |param,value|
      method = param.to_s + "="
      if respond_to? method
        self.send(method, value)
      else
        raise ArgumentError, "Invalid parameter #{param} to object class #{self.class}"
      end
    end
  end

  # Take a hash and convert all of the keys to symbols if possible.
  def symbolize_options(options)
    options.inject({}) do |hash, opts|
      if opts[0].respond_to? :intern
        hash[opts[0].intern] = opts[1]
      else
        hash[opts[0]] = opts[1]
      end
      hash
    end
  end

  ##
  # Helper to validate options. Example:
  #
  #   validate_options [:arguments, :inherits], options
  #
  # It expects list of valid options and a hash to validate as a last
  # argument.
  ##
  def validate_options(allow, options = {})
    options.each do |k, _|
      unless Array(allow).include? k
        raise ArgumentError, "unrecognized option #{k}"
      end
    end
  rescue Exception => e
    # removing +validate_options+ from the backtrace, because the error is one
    # frame above it and it is just helping to find it.
    e.set_backtrace e.backtrace[1..-1]
    raise e
  end

end
