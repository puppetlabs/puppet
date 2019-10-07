module Puppet
module Pal
  # A CatalogCompiler is a compiler that builds a catalog of resources and dependencies as a side effect of
  # evaluating puppet language code.
  # When the compilation of the given input manifest(s)/code string/file is finished the catalog is complete
  # for encoding and use. It is also possible to evaluate more strings within the same compilation context to
  # add or remove things from the catalog.
  #
  # @api public
  class CatalogCompiler < Compiler

    # @api private
    def catalog
      internal_compiler.catalog
    end
    private :catalog

    # Returns true if this is a compiler that compiles a catalog.
    # This implementation returns `true`
    # @return [Boolean] true
    # @api public
    def has_catalog?
      true
    end

    # Calls a block of code and yields a configured `JsonCatalogEncoder` to the block.
    # @example Get resulting catalog as pretty printed Json
    #   Puppet::Pal.in_environment(...) do |pal|
    #     pal.with_catalog_compiler(...) do |compiler|
    #       compiler.with_json_encoding { |encoder| encoder.encode }
    #     end
    #   end
    #
    # @api public
    #
    def with_json_encoding(pretty: true, exclude_virtual: true)
      yield JsonCatalogEncoder.new(catalog, pretty: pretty, exclude_virtual: exclude_virtual)
    end

    # Returns a hash representation of the compiled catalog.
    #
    # @api public
    def catalog_data_hash
      catalog.to_data_hash
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
        bridged = Puppet::Parser::AST::PopsBridge::Program.new(ast)
        # define all catalog types
        internal_compiler.environment.known_resource_types.import_ast(bridged, "")
        bridged.evaluate(internal_compiler.topscope)
      else
        internal_evaluator.evaluate(topscope, ast)
      end
    end


    # Compiles the result of additional evaluation taking place in a PAL catalog compilation.
    # This will evaluate all lazy constructs until all have been evaluated, and will the validate
    # the result.
    #
    # This should be called if evaluating string or files of puppet logic after the initial
    # compilation taking place by giving PAL a manifest or code-string.
    # This method should be called when a series of evaluation should have reached a
    # valid state (there should be no dangling relationships (to resources that does not
    # exist).
    #
    # As an alternative the methods `evaluate_additions` can be called without any
    # requirements on consistency and then calling `validate` at the end.
    #
    # Can be called multiple times.
    #
    # @return [Void]
    def compile_additions
      internal_compiler.compile_additions
    end

    # Validates the state of the catalog (without performing evaluation of any elements
    # requiring lazy evaluation. Can be called multiple times.
    #
    def validate
      internal_compiler.validate
    end

    # Evaluates all lazy constructs that were produced as a side effect of evaluating puppet logic.
    # Can be called multiple times.
    #
    def evaluate_additions
      internal_compiler.evaluate_additions
    end

  end

end
end
