module Puppet::Pops::Binder::Hiera2
  Model = Puppet::Pops::Model

  # A BindingsProvider instance is used for creating a bindings model from a module directory
  # @api public
  #
  class BindingsProvider
    # The resulting name of loaded bindings (given when initializing)
    attr_reader :name

    # Creates a new BindingsProvider by reading the hiera_conf.yaml configuration file. Problems
    # with the configuration are reported propagated to the acceptor
    #
    # @param name [String] the name to assign to the result (and in error messages if there is no result)
    # @param hiera_config_dir [String] Path to the directory containing a hiera_config
    # @param acceptor [Puppet::Pops::Validation::Acceptor] Acceptor that will receive diagnostics
    def initialize(name, hiera_config_dir, acceptor)
      @name = name
      @parser = Puppet::Pops::Parser::EvaluatingParser.new()
      @diagnostics = DiagnosticProducer.new(acceptor)
      @type_calculator = Puppet::Pops::Types::TypeCalculator.new()
      @config = Config.new(hiera_config_dir, @diagnostics)
    end

    # Loads a bindings model using the hierarchy and backends configured for this instance.
    #
    # @param scope [Puppet::Parser::Scope] The hash used when expanding
    # @return [Puppet::Pops::Binder::Bindings::ContributedBindings] A bindings model with effective categories
    def load_bindings(scope)
      backends = BackendHelper.new(scope)
      factory = Puppet::Pops::Binder::BindingsFactory
      result = factory.named_bindings(name)

      hierarchy = {}
      precedence = []

      @config.hierarchy.each do |key, value, path|
        source_file = File.join(@config.module_dir, 'hiera.yaml')
        category_value = @parser.evaluate_string(scope, @parser.quote(value), source_file)

        hierarchy[key] = {
          :bindings    => result.when_in_category(key, category_value),
          :path        => @parser.evaluate_string(scope, @parser.quote(path)),
          :unique_keys =>Set.new()}

        precedence << [key, category_value]
      end

      @config.backends.each do |backend_key|
        backend = backends[backend_key]

        hierarchy.each_pair do |hier_key, hier_val|
          bindings = hier_val[:bindings]
          unique_keys = hier_val[:unique_keys]

          hiera_data_file_path = hier_val[:path]
          backend.read_data(@config.module_dir, hiera_data_file_path).each_pair do |key, value|
            if unique_keys.add?(key)
              b = bindings.bind().name(key)
              # Transform value into a Model::Expression
              expr = build_expr(value, hiera_data_file_path)
              if is_constant?(expr)
                # The value is constant so toss the expression
                b.type(@type_calculator.infer(value)).to(value)
              else
                # Use an evaluating producer for the binding
                b.to(expr)
              end
            end
          end
        end
      end

      factory.contributed_bindings(name, result.model, factory.categories(precedence))
    end

    private

    # @return true unless the expression is a Model::ConcatenatedString or
    # somehow contains one
    def is_constant?(expr)
      if expr.is_a?(Model::ConcatenatedString)
        false
      else
        !expr.eAllContents.any? { |v| v.is_a?(Model::ConcatenatedString) }
      end
    end

    # Transform the value into a Model::Expression. Strings are parsed using
    # the Pops::Parser::Parser to produce either Model::LiteralString or Model::ConcatenatedString
    #
    # @param value [Object] May be an String, Number, TrueClass, FalseClass, or NilClass nested to any depth using Hash or Array.
    # @param hiera_data_file_path [String] The source_file used when reporting errors
    # @return [Model::Expression] The expression that corresponds to the value
    def build_expr(value, hiera_data_file_path)
      case value
      when Symbol
        value.to_s
      when String
        @parser.parse_string(@parser.quote(value)).current
      when Hash
        value.inject(Model::LiteralHash.new)  do |h,(k,v)|
          e = Model::KeyedEntry.new
          e.key = build_expr(k, hiera_data_file_path)
          e.value = build_expr(v, hiera_data_file_path)
          h.addEntries(e)
          h
        end
      when Enumerable
        value.inject(Model::LiteralList.new) {|a,v| a.addValues(build_expr(v, hiera_data_file_path)); a }
      when Numeric
        expr = Model::LiteralNumber.new
        expr.value = value;
        expr
      when TrueClass, FalseClass
        expr = Model::LiteralBoolean.new
        expr.value = value;
        expr
      when NilClass
        Model::Nop.new
      else
        @diagnostics.accept(Issues::UNABLE_TO_PARSE_INSTANCE, value.class.name)
        nil
      end
    end
  end

  # @api private
  class BackendHelper
    T = Puppet::Pops::Types::TypeFactory
    HASH_OF_BACKENDS = T.hash_of(T.type_of('Puppetx::Puppet::Hiera2Backend'))
    def initialize(scope)
      @scope = scope
      @cache = nil
    end

    def [] (backend_key)
      load_backends unless @cache
      @cache[backend_key]
    end

    def load_backends
      @cache = @scope.compiler.boot_injector.lookup(@scope, HASH_OF_BACKENDS, Puppetx::HIERA2_BACKENDS) || {}
    end
  end

end

