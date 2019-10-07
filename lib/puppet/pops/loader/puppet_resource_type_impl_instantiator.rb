module Puppet::Pops
module Loader
# The PuppetResourceTypeImplInstantiator instantiates a Puppet::Pops::ResourceTypeImpl object.
# given a Puppet Programming language source that when called evaluates the Puppet logic it contains.
#
class PuppetResourceTypeImplInstantiator
  # Produces an instance of Puppet::Pops::ResourceTypeImpl, or fails with an error if the
  # given puppet source does not produce such an instance when evaluated.
  #
  # @param loader [Loader] The loader the function is associated with
  # @param typed_name [TypedName] the type / name of the resource type impl to load
  # @param source_ref [URI, String] a reference to the source / origin of the puppet code to evaluate
  # @param pp_code_string [String] puppet code in a string
  #
  # @return [Puppet::Pops::ResourceTypeImpl] - an instantiated ResourceTypeImpl
  #
  def self.create(loader, typed_name, source_ref, pp_code_string)
    parser = Parser::EvaluatingParser.new()

    # parse and validate
    model = parser.parse_string(pp_code_string, source_ref)
    statements = if model.is_a?(Model::Program)
                   if model.body.is_a?(Model::BlockExpression)
                     model.body.statements
                   else
                     [model.body]
                   end
                 else
                   EMPTY_ARRAY
                 end
    statements = statements.reject { |s| s.is_a?(Model::Nop) }
    if statements.empty?
      raise ArgumentError, _("The code loaded from %{source_ref} does not create the resource type '%{type_name}' - it is empty") % { source_ref: source_ref, type_name: typed_name.name }
    end

    rname = Resource::ResourceTypeImpl._pcore_type.name
    unless statements.find do |s|
      if s.is_a?(Model::CallMethodExpression)
        functor_expr = s.functor_expr
        functor_expr.is_a?(Model::NamedAccessExpression) &&
          functor_expr.left_expr.is_a?(Model::QualifiedReference) &&
          functor_expr.left_expr.cased_value == rname &&
          functor_expr.right_expr.is_a?(Model::QualifiedName) &&
          functor_expr.right_expr.value == 'new'
      else
        false
      end
    end
      raise ArgumentError, _("The code loaded from %{source_ref} does not create the resource type '%{type_name}' - no call to %{rname}.new found.") % { source_ref: source_ref, type_name: typed_name.name, rname: rname }
    end

    unless statements.size == 1
      raise ArgumentError, _("The code loaded from %{source_ref} must contain only the creation of resource type '%{type_name}' - it has additional logic.") % { source_ref: source_ref, type_name: typed_name.name }
    end

    closure_scope = Puppet.lookup(:global_scope) { {} }
    resource_type_impl = parser.evaluate(closure_scope, model)

    unless resource_type_impl.is_a?(Puppet::Pops::Resource::ResourceTypeImpl)
      got = resource_type.class
      raise ArgumentError, _("The code loaded from %{source_ref} does not define the resource type '%{type_name}' - got '%{got}'.") % { source_ref: source_ref, type_name: typed_name.name, got: got }
    end

    unless resource_type_impl.name == typed_name.name
      expected = typed_name.name
      actual = resource_type_impl.name
      raise ArgumentError, _("The code loaded from %{source_ref} produced resource type with the wrong name, expected '%{expected}', actual '%{actual}'") % { source_ref: source_ref, expected: expected, actual: actual }
    end

    # Adapt the resource type definition with loader - this is used from logic contained in it body to find the
    # loader to use when making calls to the new function API. Such logic have a hard time finding the closure (where
    # the loader is known - hence this mechanism
    Adapters::LoaderAdapter.adapt(resource_type_impl).loader_name = loader.loader_name
    resource_type_impl
  end

end
end
end
