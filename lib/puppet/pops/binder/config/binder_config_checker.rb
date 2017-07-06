module Puppet::Pops::Binder::Config
  # Validates the consistency of a Binder::BinderConfig
  class BinderConfigChecker
    # Create an instance with a diagnostic producer that will receive the result during validation
    # @param diagnostics [DiagnosticProducer] The producer that will receive the diagnostic
    # @api public
    #
    def initialize(diagnostics)
      @diagnostics = diagnostics
      t = Puppet::Pops::Types
      @type_calculator = t::TypeCalculator.new()
      @array_of_string_type = t::TypeFactory.array_of(t::TypeFactory.string())
    end

    # Validate the consistency of the given data. Diagnostics will be emitted to the DiagnosticProducer
    # that was set when this checker was created
    #
    # @param data [Object] The data read from the config file
    # @param config_file [String] The full path of the file. Used in error messages
    # @api public
    #
    def validate(data, config_file)
      @unique_layer_names = Set.new()

      if data.is_a?(Hash)
        check_top_level(data, config_file)
      else
        accept(Issues::CONFIG_IS_NOT_HASH, config_file)
      end
    end

    private

    def accept(issue, semantic, options = {})
      @diagnostics.accept(issue, semantic, options)
    end

    def check_top_level(data, config_file)
      if layers = (data['layers'] || data[:layers])
        check_layers(layers, config_file)
      else
        accept(Issues::CONFIG_LAYERS_MISSING, config_file)
      end

      if version = (data['version'] || data[:version])
        accept(Issues::CONFIG_WRONG_VERSION, config_file, {:expected => 1, :actual => version}) unless version == 1
      else
        accept(Issues::CONFIG_VERSION_MISSING, config_file)
      end
      if extensions = data['extensions']
        check_extensions(extensions, config_file)
      end
    end

    def check_layers(layers, config_file)
      unless layers.is_a?(Array)
        accept(Issues::LAYERS_IS_NOT_ARRAY, config_file, :klass => data.class)
      else
        layers.each {|layer| check_layer(layer, config_file) }
      end
    end

    def check_layer(layer, config_file)
      unless layer.is_a?(Hash)
        accept(Issues::LAYER_IS_NOT_HASH, config_file, :klass => layer.class)
        return
      end
      layer.each_pair do |k, v|
        case k
        when 'name'
          unless v.is_a?(String)
            accept(Issues::LAYER_NAME_NOT_STRING, config_file, :class_name => v.class.name)
          end

          unless @unique_layer_names.add?(v)
            accept(Issues::DUPLICATE_LAYER_NAME, config_file, :name => v.to_s )
          end

        when 'include'
          check_bindings_references('include', v, config_file)

        when 'exclude'
          check_bindings_references('exclude', v, config_file)

        when Symbol
          accept(Issues::LAYER_ATTRIBUTE_IS_SYMBOL, config_file, :name => k.to_s)

        else
          accept(Issues::UNKNOWN_LAYER_ATTRIBUTE, config_file, :name => k.to_s )
        end
      end
    end

    # references to bindings is a single String URI, or an array of String URI
    # @param kind [String] 'include' or 'exclude' (used in issue messages)
    # @param value [String, Array<String>] one or more String URI binding references
    # @param config_file [String] reference to the loaded config file
    #
    def check_bindings_references(kind, value, config_file)
      return check_reference(value, kind, config_file) if value.is_a?(String)
      accept(Issues::BINDINGS_REF_NOT_STRING_OR_ARRAY, config_file, :kind => kind ) unless value.is_a?(Array)
      value.each {|ref| check_reference(ref, kind, config_file) }
    end

    # A reference is a URI in string form having a scheme and a path (at least '/')
    #
    def check_reference(value, kind, config_file)
      begin
        uri = URI.parse(value)

        unless uri.scheme
          accept(Issues::MISSING_SCHEME, config_file, :uri => uri)
        end
        unless uri.path
          accept(Issues::REF_WITHOUT_PATH, config_file, :uri => uri, :kind => kind)
        end

      rescue InvalidURIError => e
        accept(Issues::BINDINGS_REF_INVALID_URI, config_file, :msg => e.message)
      end
    end

    def check_extensions(extensions, config_file)
      unless extensions.is_a?(Hash)
        accept(Issues::EXTENSIONS_NOT_HASH, config_file, :actual => extensions.class.name)
        return
      end
      # check known extensions
      extensions.each_key do |key|
        unless ['scheme_handlers'].include? key
          accept(Issues::UNKNOWN_EXTENSION, config_file, :extension => key)
        end
      end

      if binding_schemes = extensions['scheme_handlers']
        unless binding_schemes.is_a?(Hash)
          accept(Issues::EXTENSION_BINDING_NOT_HASH, config_file, :extension => 'scheme_handlers', :actual => binding_schemes.class.name)
        end
      end
    end
  end
end
