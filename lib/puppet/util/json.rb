module Puppet::Util
  module Json
    class ParseError < StandardError
      attr_reader :cause, :data

      def self.build(original_exception, data)
        new(original_exception.message).tap do |exception|
          exception.instance_eval do
            @cause = original_exception
            set_backtrace original_exception.backtrace
            @data = data
          end
        end
      end
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
    # whether or not MultiJson can be loaded.
    def self.load(string, options = {})
      if defined? MultiJson
        begin
          # This ensures that JrJackson will parse very large or very small
          # numbers as floats rather than BigDecimals, which are serialized as
          # strings by the built-in JSON gem and therefore can cause schema errors,
          # for example, when we are rendering reports to JSON using `to_pson` in
          # PuppetDB.
          if MultiJson.adapter.name == "MultiJson::Adapters::JrJackson"
            options[:use_bigdecimal] = false
          end

          MultiJson.load(string, options)
        rescue MultiJson::ParseError => e
          raise Puppet::Util::Json::ParseError.build(e, string)
        end
      else
        begin
          string = string.read if string.respond_to?(:read)

          options[:symbolize_names] = true if options.delete(:symbolize_keys)
          ::JSON.parse(string, options)
        rescue JSON::ParserError => e
          raise Puppet::Util::Json::ParseError.build(e, string)
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
