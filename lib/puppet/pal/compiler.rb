module Puppet
module Pal

  # A configured compiler as obtained in the callback from `Puppet::Pal.with_script_compiler`.
  # (Later, there may also be a catalog compiler available.)
  #
  class Compiler
    attr_reader :internal_compiler
    protected :internal_compiler

    attr_reader :internal_evaluator
    protected :internal_evaluator

    def initialize(internal_compiler)
      @internal_compiler = internal_compiler
      @internal_evaluator = Puppet::Pops::Parser::EvaluatingParser.new
    end

    # Calls a function given by name with arguments specified in an `Array`, and optionally accepts a code block.
    # @param function_name [String] the name of the function to call
    # @param args [Object] the arguments to the function
    # @param block [Proc] an optional callable block that is given to the called function
    # @return [Object] what the called function returns
    #
    def call_function(function_name, *args, &block)
      # TRANSLATORS: do not translate variable name strings in these assertions
      Pal::assert_non_empty_string(function_name, 'function_name', false)
      Pal::assert_type(Pal::T_ANY_ARRAY, args, 'args', false)
      internal_evaluator.evaluator.external_call_function(function_name, args, topscope, &block)
    end

    # Returns a Puppet::Pal::FunctionSignature object or nil if function is not found
    # The returned FunctionSignature has information about all overloaded signatures of the function
    #
    # @example using function_signature
    #   # returns true if 'myfunc' is callable with three integer arguments 1, 2, 3
    #   compiler.function_signature('myfunc').callable_with?([1,2,3])
    #
    # @param function_name [String] the name of the function to get a signature for
    # @return [Puppet::Pal::FunctionSignature] a function signature, or nil if function not found
    #
    def function_signature(function_name)
      loader = internal_compiler.loaders.private_environment_loader
      func = loader.load(:function, function_name)
      if func
        return FunctionSignature.new(func.class)
      end
      # Could not find function
      nil
    end

    # Returns an array of TypedName objects for all functions, optionally filtered by a regular expression.
    # The returned array has more information than just the leaf name - the typical thing is to just get
    # the name as showing the following example.
    #
    # Errors that occur during function discovery will either be logged as warnings or collected by the optional
    # `error_collector` array. When provided, it will receive {Puppet::DataTypes::Error} instances describing
    # each error in detail and no warnings will be logged.
    #
    # @example getting the names of all functions
    #   compiler.list_functions.map {|tn| tn.name }
    #
    # @param filter_regex [Regexp] an optional regexp that filters based on name (matching names are included in the result)
    # @param error_collector [Array<Puppet::DataTypes::Error>] an optional array that will receive errors during load
    # @return [Array<Puppet::Pops::Loader::TypedName>] an array of typed names
    #
    def list_functions(filter_regex = nil, error_collector = nil)
      list_loadable_kind(:function, filter_regex, error_collector)
    end

    # Evaluates a string of puppet language code in top scope.
    # A "source_file" reference to a source can be given - if not an actual file name, by convention the name should
    # be bracketed with < > to indicate it is something symbolic; for example `<commandline>` if the string was given on the
    # command line.
    #
    # If the given `puppet_code` is `nil` or an empty string, `nil` is returned, otherwise the result of evaluating the
    # puppet language string. The given string must form a complete and valid expression/statement as an error is raised
    # otherwise. That is, it is not possible to divide a compound expression by line and evaluate each line individually.
    #
    # @param puppet_code [String, nil] the puppet language code to evaluate, must be a complete expression/statement
    # @param source_file [String, nil] an optional reference to a source (a file or symbolic name/location)
    # @return [Object] what the `puppet_code` evaluates to
    #
    def evaluate_string(puppet_code, source_file = nil)
      return nil if puppet_code.nil? || puppet_code == ''
      unless puppet_code.is_a?(String)
        raise ArgumentError, _("The argument 'puppet_code' must be a String, got %{type}") % { type: puppet_code.class }
      end
      evaluate(parse_string(puppet_code, source_file))
    end

    # Evaluates a puppet language file in top scope.
    # The file must exist and contain valid puppet language code or an error is raised.
    #
    # @param file [Path, String] an absolute path to a file with puppet language code, must exist
    # @return [Object] what the last evaluated expression in the file evaluated to
    #
    def evaluate_file(file)
      evaluate(parse_file(file))
    end

    # Evaluates an AST obtained from `parse_string` or `parse_file` in topscope.
    # If the ast is a `Puppet::Pops::Model::Program` (what is returned from the `parse` methods, any definitions
    # in the program (that is, any function, plan, etc. that is defined will be made available for use).
    #
    # @param ast [Puppet::Pops::Model::PopsObject] typically the returned `Program` from the parse methods, but can be any `Expression`
    # @returns [Object] whatever the ast evaluates to
    #
    def evaluate(ast)
      if ast.is_a?(Puppet::Pops::Model::Program)
        loaders = Puppet.lookup(:loaders)
        loaders.instantiate_definitions(ast, loaders.public_environment_loader)
      end
      internal_evaluator.evaluate(topscope, ast)
    end

    # Produces a literal value if the AST obtained from `parse_string` or `parse_file` does not require any actual evaluation.
    # This method is useful if obtaining an AST that represents literal values; string, integer, float, boolean, regexp, array, hash;
    # for example from having read this from the command line or as values in some file.
    #
    # @param ast [Puppet::Pops::Model::PopsObject] typically the returned `Program` from the parse methods, but can be any `Expression`
    # @returns [Object] whatever the literal value the ast evaluates to
    #
    def evaluate_literal(ast)
      catch :not_literal do
        return Puppet::Pops::Evaluator::LiteralEvaluator.new().literal(ast)
      end
      # TRANSLATORS, the 'ast' is the name of a parameter, do not translate
      raise ArgumentError, _("The given 'ast' does not represent a literal value")
    end

    # Parses and validates a puppet language string and returns an instance of Puppet::Pops::Model::Program on success.
    # If the content is not valid an error is raised.
    #
    # @param code_string [String] a puppet language string to parse and validate
    # @param source_file [String] an optional reference to a file or other location in angled brackets
    # @return [Puppet::Pops::Model::Program] returns a `Program` instance on success
    #
    def parse_string(code_string, source_file = nil)
      unless code_string.is_a?(String)
        raise ArgumentError, _("The argument 'code_string' must be a String, got %{type}") % { type: code_string.class }
      end
      internal_evaluator.parse_string(code_string, source_file)
    end

    # Parses and validates a puppet language file and returns an instance of Puppet::Pops::Model::Program on success.
    # If the content is not valid an error is raised.
    #
    # @param file [String] a file with puppet language content to parse and validate
    # @return [Puppet::Pops::Model::Program] returns a `Program` instance on success
    #
    def parse_file(file)
      unless file.is_a?(String)
        raise ArgumentError, _("The argument 'file' must be a String, got %{type}") % { type: file.class }
      end
      internal_evaluator.parse_file(file)
    end

    # Parses a puppet data type given in String format and returns that type, or raises an error.
    # A type is needed in calls to `new` to create an instance of the data type, or to perform type checking
    # of values - typically using `type.instance?(obj)` to check if `obj` is an instance of the type.
    #
    # @example Verify if obj is an instance of a data type
    #   # evaluates to true
    #   pal.type('Enum[red, blue]').instance?("blue")
    #
    # @example Create an instance of a data type
    #   # using an already create type
    #   t = pal.type('Car')
    #   pal.create(t, 'color' => 'black', 'make' => 't-ford')
    #
    #   # letting 'new_object' parse the type from a string
    #   pal.create('Car', 'color' => 'black', 'make' => 't-ford')
    #
    # @param type_string [String] a puppet language data type
    # @return [Puppet::Pops::Types::PAnyType] the data type
    #
    def type(type_string)
      Puppet::Pops::Types::TypeParser.singleton.parse(type_string)
    end

    # Creates a new instance of a given data type.
    # @param data_type [String, Puppet::Pops::Types::PAnyType] the data type as a data type or in String form.
    # @param arguments [Object] one or more arguments to the called `new` function
    # @return [Object] an instance of the given data type,
    #   or raises an error if it was not possible to parse data type or create an instance.
    #
    def create(data_type, *arguments)
      t = data_type.is_a?(String) ? type(data_type) : data_type
      unless t.is_a?(Puppet::Pops::Types::PAnyType)
        raise ArgumentError, _("Given data_type value is not a data type, got '%{type}'") % {type: t.class}
      end
      call_function('new', t, *arguments)
    end

    # Returns true if this is a compiler that compiles a catalog.
    # This implementation returns `false`
    # @return Boolan false
    def has_catalog?
      false
    end

    protected

    def list_loadable_kind(kind, filter_regex = nil, error_collector = nil)
      loader = internal_compiler.loaders.private_environment_loader
      if filter_regex.nil?
        loader.discover(kind, error_collector)
      else
        loader.discover(kind, error_collector) {|f| f.name =~ filter_regex }
      end
    end

    private

    def topscope
      internal_compiler.topscope
    end
  end

end
end
