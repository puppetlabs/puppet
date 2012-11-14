require 'rgen/metamodel_builder'
require 'rgen/model_builder'
require 'rgen/ecore/ecore'
require 'rgen/ecore/ecore_to_ruby'
require 'rgen/ecore/ecore_builder_methods'
require 'rgen/util/name_helper'

module Puppet; module Pops; module Impl

# RUBY IS SILLY
# Must have a constant, or it is not possible to set it later
# (It is however possible to remove it, and then set it again)
# WARNING: Noone is supposed to reference this constant except in this
# class - it is only used to make sure anonymous classes actually have
# a name (or it will be harder to debug) 
# See TypeCreator#initialize  
Types = nil

class TypeCreator
  include RGen::Util::NameHelper
  
  attr_reader :ecore2ruby, :type_module, :package
  
  def initialize
    # Need a mutex since the namespace 'Puppet::Pops::Impl::Types' is a shared resource.
    # This constant *must* be bound to the type_module when classes are created or
    # they will be anonymous. The mutex is needed in case multiple threads are calling at
    # the same time.
    #
    @@mutex = Mutex.new
    
    # Keep an instance of RGen::EcoreToRuby around to allow it to add to one and the same package
    @ecore2ruby = RGen::ECore::ECoreToRuby.new
    
    # Create a Types package and create the anonymous module
    result = RGen::ModelBuilder.build(RGen::ECore, nil, RGen::ECore::ECoreBuilderMethods) do
      ePackage "Types" 
    end
    @package = result[0]
    @type_module = @ecore2ruby.create_module(@package)
    
    # RUBY IS SILLY
    # Set the Types constant, and then get the name of the module
    # This makes the module get a name (it is cached inside the module even if the binding
    # is removed.
    # Wait... it gets sillier, when a class is added to the module, that class will be anonymous
    # if the module is not bound to a constant at the time the class's name is references for
    # the first time.
    Puppet::Pops::Impl.send :remove_const, :Types if Puppet::Pops::Impl.const_defined?(:Types)
    Puppet::Pops::Impl.send :const_set, :Types, @type_module
    Puppet::Pops::Impl::Types.to_s
  end
  
#  def create_enum
#    # Enum.new a) (:name => "...", :literals => [x,y,z]), or (:literals => [x,y,z]), or just a list
#    # literals_as_strings
#    # validLiteral?(x)
#    #
#    kind_type = RGen::MetamodelBuilder::DataTypes::Enum.new([:blue, :green, :red])
#  end
  # Build Model as an Ecore model, use ECoreToRuby to create implementation
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
    unless o.super_name
      super_entry = scope.get_data_entry(:type, o.super_name)
      unless super_entry
        super_entry = scope.load_type(o.super_name)
      end
      super_eclass = super_entry.model_class
    end
    # Create class and add to package
    eclass = create_eclass(name, super_eclass)
    # Create all attributes and add to class 
    create_attributes(eclass, o, scope, evaluator)
    # TODO: Containments and References
    
    # Create the ruby class
    c = create_class_internal(eclass)
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
      result = evaluate(a, scope)
      raise "Internal error: CreateAttributeExpression did not produce an EAttribute" unless result.is_a? RGen::ECore::EAttribute
      result.eContainingClass = eclass
    end
  end
  
  def generate_methods(klass, o)
    # inputTransformer
    # derived_expr
    @@input_transformer_builder ||= ERB.new %q{
#      <%# Rename the original setter %>
#      alias :'<%= old_name %>' :'<%= new_name %>'
#      <%# The new setter %>
#      def <%= new_name %> x
#        scope = Puppet::Pops::Impl::ObjectScope.new(self, {:<%= a.name %>_ => x})
#        evaluator = Puppet::Pops::Impl::EvaluatorImpl.new
#        <%# Call original setter %>
#        <%= old_name %> evaluator.evaluate(@<%= new_name %>_pops, scope) 
#      end
#      <%# Generate a setter for an attribute holding the pops logic %>
#      def <%= new_name %>_pops= x
#        @<%= new_name %>_pops = x
#      end

      }
    @@derived_builder ||= ERB.new %q{
#      def <%= a.name %>_derived
#        scope = Puppet::Pops::Impl::ObjectScope.new(self)
#        evaluator = Puppet::Pops::Impl::EvaluatorImpl.new
#        evaluator.evaluate(@<%= a.name %>_derived_pops, scope) 
#      end
#      <%# Generate a setter for an attribute holding the pops logic %>
#      def <%= a.name %>_derived_pops= x
#        @<%= a.name %>_derived_pops = x
#      end
      }

    o.attributes.each do |a|
      if a.input_transformer
        new_name = firstToUpper(a.name)
        old_name = "_" + new_name
        klass::ClassModule.module_eval(@@input_transformer_builder.result(binding))
        klass.send :"#{new_name}_pops=", a.input_transformer
      end
      if a.derived_expr
        klass::ClassModule.module_eval(@@derived_builder.result(binding))
        klass.send :"#{new_name}_derived_pops=", a.derived_expr
      end
    end
    # TODO: Object scope should bind $_ to arg being set, alt. to original value in derived attribute
    # that has storage using something like x.instance_variable_get("@name")
    # 
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

# INFO:  
# clear ecore cache
# ECoreInterface.clear_ecore_cache

# INFO:  
#  def example_using_ModelBuilder
#    result = RGen::ModelBuilder.build(RGen::ECore, nil, RGen::ECore::ECoreBuilderMethods) do
#      ePackage "TestPackage" do
#        eClass "TestClass" do
#          eAttribute "foo", :eType => RGen::ECore::EString
#        end
#      end
#    end
#    # The EPackage is found as a root in the built model
#    # The result is an anonymous module.
#    mod = RGen::ECore::ECoreToRuby.new.create_module(result[0])
#
#    # WHAT happens when done a second time?
#    result = RGen::ModelBuilder.build(RGen::ECore, nil, RGen::ECore::ECoreBuilderMethods) do
#      ePackage "TestPackage" do
#        eClass "TestClass" do
#          eAttribute "bar", :eType => RGen::ECore::EString
#        end
#      end
#    end
#    # The EPackage is found as a root in the built model
#    # The result is an anonymous module.
#    mod2 = RGen::ECore::ECoreToRuby.new.create_module(result[0])
#
#    mod::TestClass
#  end
  
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
      Puppet::Pops::Impl.send :remove_const, :Types if Puppet::Pops::Impl.const_defined?(:Types)
      Puppet::Pops::Impl.const_set(:Types, @type_module)
      Puppet::Pops::Impl::Types.to_s
      c = ecore2ruby.create_class(eclass)
      c.to_s
      
      # FINAL SILLYNESS
      Puppet::Pops::Impl.send :remove_const, :Types
      # SILLY STUFF DONE
      c
    }
  end
  
end
end; end; end
