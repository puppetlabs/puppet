module Puppet::Pops::Binder::Hiera2
  Model = Puppet::Pops::Model

  # A BindingsProvider instance is used for creating a bindings model from a module directory
  #
  class BindingsProvider

    # Creates a new BindingsProvider by reading the hiera_conf.yaml configuration file. Problems
    # with the configuration are reported propagated to the acceptor
    #
    # @param module_dir [String] Path to the module directory
    # @param acceptor [Puppet::Pops::Validation::Acceptor] Acceptor that will receive diagnostics
    def initialize(module_dir, acceptor)
      @parser = Puppet::Pops::Parser::Parser.new()
      @diagnostics = DiagnosticProducer.new(acceptor)
      @type_calculator = Puppet::Pops::Types::TypeCalculator.new()
      @config = Config.new(module_dir, @diagnostics)
    end

    # Load a bindings model using the hierarchy and backends that has been configured
    # for this instance
    #
    # @param facts [Hash<String,String>] The hash used when expanding
    # @return [Puppet::Pops::Binder::Bindings::NamedBindings] A bindings model
    def load_bindings(facts)
      result = Puppet::Pops::Binder::BindingsFactory.named_bindings(@config.module_name)
      evaluator = StringEvaluator.new(facts, @parser, @diagnostics)

      hierarchy = {}
      @config.hierarchy.each_pair do |k,v|
        hierarchy[k] = [result.when_in_category(k, evaluator.eval(v[0])), evaluator.eval(v[1]), Set.new]
      end

      @config.backends.each do |backend_key|
        backend = Backend.new_backend(backend_key)

        hierarchy.each_pair do |hier_key,hier_val|
          bindings = hier_val[0]
          unique_keys = hier_val[2]

          # The second element in the two element array for the source denotes the
          # source (what the given backend translates into a file)
          backend.read_data(@config.module_dir, hier_val[1]).each_pair do |key,value|
            if unique_keys.add?(key)
              b = bindings.bind().name(key)
              # Transform value into a Model::Expression
              expr = build_expr(value)
              if(is_constant?(expr))
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
      result.model
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
    # @return [Model::Expression] The expression that corresponds to the value
    def build_expr(value)
      case value
      when String
        @parser.parse_string(StringEvaluator.quote(value)).current
      when Hash
        value.inject(Model::LiteralHash.new)  do |h,(k,v)|
          e = Model::KeyedEntry.new
          e.key = parse(k)
          e.value = parse(v)
          h.addEntries(e)
        end
      when Enumerable
        value.inject(Model::LiteralList.new) {|a,v| a.addValues(parse(v)) }
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
end

