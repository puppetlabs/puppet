module Puppet::Util
  module Json
    class ParseError < StandardError
    end

    begin
      require 'multi_json'
      # Force backend detection before attempting to use the library
      # or load any other JSON libraries
      MultiJson.default_adapter

      # Preserve core type monkey-patching done by the built-in JSON gem
      require 'json'
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
        # MultiJson calls `merge` on the options it is passed, which relies
        # on the options' defining a `to_hash` method. In Ruby 1.9.3,
        # JSON::Ext::Generator::State only defines `to_h`, not `to_hash`, so we
        # need to convert it first, similar to what is done in the `else` block
        # below. Later versions of the JSON gem alias `to_h` to `to_hash`, so this
        # can be removed once we drop Ruby 1.9.3 support.
        options = options.to_h if options.class.name == "JSON::Ext::Generator::State"

        MultiJson.dump(object, options)
      else
        options.merge!(::JSON::PRETTY_STATE_PROTOTYPE.to_h) if options.delete(:pretty)
        object.to_json(options)
      end
    end
  end
end
