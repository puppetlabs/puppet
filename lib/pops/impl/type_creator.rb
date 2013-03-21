require 'rgen/metamodel_builder'
require 'rgen/model_builder'
require 'rgen/ecore/ecore'
require 'rgen/ecore/ecore_to_ruby'
require 'rgen/ecore/ecore_builder_methods'

#require 'rgen/util/name_helper'

# Why is this here?
# Some of this functionality requires that the module is nested purely in modules
# and something funny is going on with the Puppet module - at some point later it is not
# possible to ask a nested module for its nesting without getting an error:
# Puppet::Module:Class NoMethod 'nesting' - unclear why.
#
# Placing this logic here is clearly a crutch, would be better to solve the real problem.
#
module Pops
  module Impl

    # RUBY IS SILLY
    # Must have a constant, or it is not possible to set it later
    # (It is however possible to remove it, and then set it again)
    # WARNING: Noone is supposed to reference this constant except in this
    # class - it is only used to make sure anonymous classes actually have
    # a name (or it will be harder to debug)
    Types = nil
    # An instance of TypeCreator is specific to one environment.
    # Multiple instance do share the constant Types, and they are protected against each other
    # by re-assigning this constant in an exclusive way when this constant must have a value.
    #
    class TypeCreator
      # The RGen NameHelper is used since it is used by Rgen to compute names of generated things; best
      # to use the same logic even if only using a single method.
      include RGen::Util::NameHelper

      attr_reader :ecore2ruby, :type_module, :package
      def initialize
        # Need a mutex since the namespace 'Pops::Impl::Types' is a shared resource.
        # This constant *must* be bound to the type_module when classes are created or
        # they will be anonymous. The mutex is needed in case multiple threads are calling at
        # the same time.
        #
        @@mutex = Mutex.new()

        # Keep an instance of RGen::EcoreToRuby around to allow it to add to one and the same package
        # during one execution.
        @ecore2ruby = RGen::ECore::ECoreToRuby.new()

        # Create a Types package and create the anonymous module
        # Remember these as they will be used for all defined types during this run
        #
        result = RGen::ModelBuilder.build(RGen::ECore, nil, RGen::ECore::ECoreBuilderMethods) do
          ePackage "Types"
        end
        @package = result.slice(0)
        @type_module = @ecore2ruby.create_module(@package)

        # RUBY IS SILLY
        # Set the Types constant, and then get the name of the module.
        # This makes the module get a name (it is cached inside the module even if the binding
        # is removed, but wait...
        # it gets sillier; When a class is added to the module, that class will be anonymous
        # if the module is not bound to a constant at the time the class's name is referenced for
        # the first time. The module will eventually loose its name; but it needs to be named each time
        # a new class is created in it). So here is a hoop to jump through.

        # First remove it, or there is a warning that it is reassigned
        Pops::Impl.send :remove_const, :Types if Pops::Impl.const_defined?(:Types)
        # Then set it
        Pops::Impl.send :const_set, :Types, @type_module
        # Ask for the name; this caches it in the module
        Pops::Impl::Types.to_s
      end

      # Creates a new type given a CreateTypeExpression
      #
      # Parameters
      # * o - a CreateTypeExpression
      # * scope - the scope where the create type expression is evaluated
      # * evaluator - the evaluator to use when evaluating invariants, and attribute operations
      #
      # Raises
      # Puppet::Pops::ImmutableError if the type is already created
      #
      def create_type(o, scope, evaluator)
        name = o.name
        if scope.get_data_entry(:type, name)
          raise Puppet::Pops::ImmutableError.new("Type already created: '#{name}'")
        end
        super_eclass = nil
        if o.super_name
          super_entry = scope.get_data_entry(:type, o.super_name)
          unless super_entry
            super_entry = scope.load_type(o.super_name) # TODO: THIS IS BOGUS; NOT IMPLEMENTED
          end
          super_eclass = super_entry.value.class.ecore
        end
        # Create class and add to package
        eclass = create_eclass(name, super_eclass)
        # Create all attributes and add to class
        create_attributes(eclass, o, scope, evaluator)
        # TODO: Containments and References

        # Create the ruby class
        c = create_class_internal(eclass)
        generate_methods(c, o)
        scope.set_data(:type, name, c)
        c
      end

      def create_eclass(name, super_eclass = nil)
        eclass = RGen::ECore::EClass.new
        eclass.name = name
        eclass.ePackage = package
        eclass.addESuperTypes super_eclass if super_eclass
        eclass
      end

      def create_attributes(eclass, o, scope, evaluator)
        o.attributes.each do |a|
          result = evaluator.evaluate(a, scope)
          raise "Internal error: CreateAttributeExpression did not produce an EAttribute" unless result.is_a? RGen::ECore::EAttribute
          result.eContainingClass = eclass
        end
      end

      def generate_methods(klass, o)
        # inputTransformer
        # derived_expr
        @@input_transformer_builder ||= ERB.new <<-CODE
      <%# Rename the original setter %>
      alias :'<%= old_name %>' :'<%= new_name %>'
      <%# The new setter %>
      def <%= new_name %> x
        scope = Puppet::Pops::Impl::ObjectScope.new(self, {:<%= a.name %>_ => x})
        evaluator = Puppet::Pops::Impl::EvaluatorImpl.new
        <%# Call original setter %>
        <%= old_name %> evaluator.evaluate(@<%= new_name %>_pops, scope) 
      end
      <%# Generate a setter for an attribute holding the pops logic %>
      def <%= new_name %>_pops= x
        @<%= new_name %>_pops = x
      end
        
      CODE

        @@derived_builder ||= ERB.new <<-CODE
      def <%= a.name %>_derived
        scope = Puppet::Pops::Impl::ObjectScope.new(self,
          <%# Pass the instance variable value (or nil) as the original value %> 
          {:<%= a.name %>_ => instance_variable_get('@<%=a.name %>')})
        evaluator = Puppet::Pops::Impl::EvaluatorImpl.new
        evaluator.evaluate(@<%= a.name %>_derived_pops, scope) 
      end
      <%# Generate a setter for an attribute holding the pops logic %>
      def <%= a.name %>_derived_pops= x
        @<%= a.name %>_derived_pops = x
      end
        CODE

        o.attributes.each do |a|
          if a.input_transformer
            new_name = firstToUpper(a.name)
            old_name = "_" + new_name
            klass::ClassModule.module_eval(@@input_transformer_builder.result(binding))
            # Bind the pops logic in the class
            klass.send :"#{new_name}_pops=", a.input_transformer
          end
          if a.derived_expr
            klass::ClassModule.module_eval(@@derived_builder.result(binding))
            # Bind the pops logic in the class
            klass.send :"#{new_name}_derived_pops=", a.derived_expr
          end
        end
      end

      def test_create_type
        eclass = RGen::ECore::EClass.new
        eclass.name = 'TestClass1'
        eclass.ePackage = package
        #    package.addEClassifiers(eclass)
        # for each attribute in o
        a = RGen::ECore::EAttribute.new
        a.name = 'attr1'
        a.eType = RGen::ECore::EString
        eclass.addEStructuralFeatures(a)
        # for each containment
        # for each reference
        c = create_class_internal eclass
        c
      end

      def test_create_type2 superclass
        eclass = RGen::ECore::EClass.new
        eclass.name = 'TestClass2'
        eclass.addESuperTypes superclass
        eclass.ePackage = package
        #    package.addEClassifiers(eclass)
        # for each attribute in o
        a = RGen::ECore::EAttribute.new
        a.name = 'attr2'
        a.eType = RGen::ECore::EString
        eclass.addEStructuralFeatures(a)

        c = create_class_internal eclass
        #    # for each containment
        #    # for each reference
        c
      end

      # TODO: Refactor the protected calls to take a block instead, they are all doing the
      # same thing except called ecore2ruby in different ways.
      def create_enum eenum
        # This may not be needed for enums, as they are not classes where we want the
        # const name to be reflected as the class name.
        # Better safe than sorry.
        @@mutex.synchronize {
          # THIS IS RUBY AT ITS WORST
          # The name of a class is memoized when #to_s is called on it.
          # This means that the class and the Module must be bound to constants
          # or we will forever just see an instance unique numbers when asking the Class
          # instance for its name.
          # OTOH: We absolutely do *not* want the module or any of the classes bound in it
          # To be accessible via constants (the runtime will over time load different types
          # bound to the same name.
          #
          Puppet::Pops::Impl.send :remove_const, :Types if Puppet::Pops::Impl.const_defined?(:Types)
          Puppet::Pops::Impl.const_set(:Types, @type_module)
          Puppet::Pops::Impl::Types.to_s
          e = ecore2ruby.create_enum(eenum)
          e.to_s

          # FINAL SILLYNESS
          Puppet::Pops::Impl.send :remove_const, :Types
          # SILLY STUFF DONE
          e
        }
      end

      def create_class_internal eclass
        @@mutex.synchronize {
          # THIS IS RUBY AT ITS WORST
          # The name of a class is memoized when #to_s is called on it.
          # This means that the class and the Module must be bound to constants
          # or we will forever just see an instance unique numbers when asking the Class
          # instance for its name.
          # OTOH: We absolutely do *not* want the module or any of the classes bound in it
          # To be accessible via constants (the runtime will over time load different types
          # bound to the same name.
          #
          Pops::Impl.send :remove_const, :Types if Pops::Impl.const_defined?(:Types)
          Pops::Impl.const_set(:Types, @type_module)
          Pops::Impl::Types.to_s
          c = ecore2ruby.create_class(eclass)
          c.to_s

          # FINAL SILLYNESS
          Pops::Impl.send :remove_const, :Types
          # SILLY STUFF DONE
          c
        }
      end

    end
  end
end
