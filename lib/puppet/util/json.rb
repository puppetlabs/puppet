module Puppet::Util::Json
  begin
    require 'multi_json'
  rescue LoadError
    require 'json'
  end

  # These methods are identical to the fallback implemented by MultiJson
  # when using the built-in JSON backend, to ensure consistent behavior
  # whether or not MultiJson can be loaded.
  def self.load(source, options = {})
    if defined? MultiJson
      MultiJson.load(source, options)
    else
      if string.respond_to?(:force_encoding)
          string = string.dup.force_encoding(::Encoding::ASCII_8BIT)
      end

      options[:symbolize_names] = true if options.delete(:symbolize_keys)
      ::JSON.parse(string, options)
    end
  end

  def self.dump(object, options = {})
    if defined? MultiJson
      MultiJson.dump(object, options)
    else
      options.merge!(::JSON::PRETTY_STATE_PROTOTYPE.to_h) if options.delete(:pretty)
      object.to_json(options)
    end
  end
end
