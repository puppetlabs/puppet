module Puppet::Util
  module Json
    class ParseError < StandardError
    end

    begin
      require 'multi_json'
    rescue LoadError
      require 'json'
    end

    # These methods do similar processing to the fallback implemented by MultiJson
    # when using the built-in JSON backend, to ensure consistent behavior
    # whether or not Puppet::Util::Json can be loaded.
    def self.load(string, options = {})
      if defined? MultiJson
        begin
          MultiJson.load(string, options)
        rescue MultiJson::ParseError => e
          raise Puppet::Util::Json::ParseError, e.cause
        end
      else
        begin
          if string.nil?
            raise Puppet::Util::Json::ParseError, "Invalid JSON: nil input"
          end

          string = string.read if string.respond_to?(:read)

          if string.respond_to?(:force_encoding)
            string = string.dup.force_encoding(::Encoding::ASCII_8BIT)
          end

          options[:symbolize_names] = true if options.delete(:symbolize_keys)
          ::JSON.parse(string, options)
        rescue JSON::ParserError => e
          raise Puppet::Util::Json::ParseError, e.message
        end
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
end
