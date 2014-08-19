# RGen Framework
# (c) Martin Thiede, 2006

require 'erb'
require 'rgen/metamodel_builder/intermediate/feature'

module RGen

module MetamodelBuilder

# This module provides methods which can be used to setup a metamodel element.
# The module is used to +extend+ MetamodelBuilder::MMBase, i.e. add the module's 
# methods as class methods.
# 
# MetamodelBuilder::MMBase should be used as a start for new metamodel elements.
# See MetamodelBuilder for an example.
# 
module BuilderExtensions
  include Util::NameHelper

  class FeatureBlockEvaluator
    def self.eval(block, props1, props2=nil)
      return unless block
      e = self.new(props1, props2)
      e.instance_eval(&block)
    end
    def initialize(props1, props2)
      @props1, @props2 = props1, props2
    end
    def annotation(hash)
      @props1.annotations << Intermediate::Annotation.new(hash)
    end
    def opposite_annotation(hash)
      raise "No opposite available" unless @props2
      @props2.annotations << Intermediate::Annotation.new(hash)
    end
  end
    
  # Add an attribute which can hold a single value.
  # 'role' specifies the name which is used to access the attribute.
  # 'target_class' specifies the type of objects which can be held by this attribute.
  # If no target class is given, String will be default.
  # 
  # This class method adds the following instance methods, where 'role' is to be 
  # replaced by the given role name:
  #   class#role  # getter
  #   class#role=(value)  # setter
  def has_attr(role, target_class=nil, raw_props={}, &block)
    props = Intermediate::Attribute.new(target_class, _ownProps(raw_props).merge({
      :name=>role, :upperBound=>1}))
    raise "No opposite available" unless _oppositeProps(raw_props).empty?
    FeatureBlockEvaluator.eval(block, props)
    _build_internal(props)
  end
  
  # Add an attribute which can hold multiple values.
  # 'role' specifies the name which is used to access the attribute.
  # 'target_class' specifies the type of objects which can be held by this attribute.
  # If no target class is given, String will be default.
  # 
  # This class method adds the following instance methods, where 'role' is to be 
  # replaced by the given role name:
  #   class#addRole(value, index=-1)  
  #   class#removeRole(value)
  #   class#role  # getter, returns an array
  #   class#role= # setter, sets multiple values at once
  # Note that the first letter of the role name is turned into an uppercase 
  # for the add and remove methods.
  def has_many_attr(role, target_class=nil, raw_props={}, &block)
    props = Intermediate::Attribute.new(target_class, _setManyUpperBound(_ownProps(raw_props).merge({
      :name=>role})))
    raise "No opposite available" unless _oppositeProps(raw_props).empty?
    FeatureBlockEvaluator.eval(block, props)
    _build_internal(props)
  end
  
  # Add a single unidirectional association.
  # 'role' specifies the name which is used to access the association.
  # 'target_class' specifies the type of objects which can be held by this association.
  # 
  # This class method adds the following instance methods, where 'role' is to be 
  # replaced by the given role name:
  #   class#role  # getter
  #   class#role=(value)  # setter
  # 
  def has_one(role, target_class=nil, raw_props={}, &block)
    props = Intermediate::Reference.new(target_class, _ownProps(raw_props).merge({
      :name=>role, :upperBound=>1, :containment=>false}))
    raise "No opposite available" unless _oppositeProps(raw_props).empty?
    FeatureBlockEvaluator.eval(block, props)
    _build_internal(props)
  end

  # Add an unidirectional _many_ association.
  # 'role' specifies the name which is used to access the attribute.
  # 'target_class' is optional and can be used to fix the type of objects which
  # can be referenced by this association.
  # 
  # This class method adds the following instance methods, where 'role' is to be 
  # replaced by the given role name:
  #   class#addRole(value, index=-1)  
  #   class#removeRole(value)
  #   class#role  # getter, returns an array
  # Note that the first letter of the role name is turned into an uppercase 
  # for the add and remove methods.
  # 
  def has_many(role, target_class=nil, raw_props={}, &block)
    props = Intermediate::Reference.new(target_class, _setManyUpperBound(_ownProps(raw_props).merge({
      :name=>role, :containment=>false})))
    raise "No opposite available" unless _oppositeProps(raw_props).empty?
    FeatureBlockEvaluator.eval(block, props)
    _build_internal(props)
  end
  
  def contains_one_uni(role, target_class=nil, raw_props={}, &block)
    props = Intermediate::Reference.new(target_class, _ownProps(raw_props).merge({
      :name=>role, :upperBound=>1, :containment=>true}))
    raise "No opposite available" unless _oppositeProps(raw_props).empty?
    FeatureBlockEvaluator.eval(block, props)
    _build_internal(props)
  end

  def contains_many_uni(role, target_class=nil, raw_props={}, &block)
    props = Intermediate::Reference.new(target_class, _setManyUpperBound(_ownProps(raw_props).merge({
      :name=>role, :containment=>true})))
    raise "No opposite available" unless _oppositeProps(raw_props).empty?
    FeatureBlockEvaluator.eval(block, props)
    _build_internal(props)
  end
  
  # Add a bidirectional one-to-many association between two classes.
  # The class this method is called on is refered to as _own_class_ in 
  # the following.
  # 
  # Instances of own_class can use 'own_role' to access _many_ associated instances
  # of type 'target_class'. Instances of 'target_class' can use 'target_role' to
  # access _one_ associated instance of own_class.
  # 
  # This class method adds the following instance methods where 'ownRole' and
  # 'targetRole' are to be replaced by the given role names:
  #   own_class#addOwnRole(value, index=-1)
  #   own_class#removeOwnRole(value)
  #   own_class#ownRole
  #   target_class#targetRole
  #   target_class#targetRole=(value)
  # Note that the first letter of the role name is turned into an uppercase 
  # for the add and remove methods.
  # 
  # When an element is added/set on either side, this element also receives the element
  # is is added to as a new element.
  # 
  def one_to_many(target_role, target_class, own_role, raw_props={}, &block)
    props1 = Intermediate::Reference.new(target_class, _setManyUpperBound(_ownProps(raw_props).merge({
      :name=>target_role, :containment=>false})))
    props2 = Intermediate::Reference.new(self, _oppositeProps(raw_props).merge({
      :name=>own_role, :upperBound=>1, :containment=>false}))
    FeatureBlockEvaluator.eval(block, props1, props2)
    _build_internal(props1, props2)
  end

  def contains_many(target_role, target_class, own_role, raw_props={}, &block)
    props1 = Intermediate::Reference.new(target_class, _setManyUpperBound(_ownProps(raw_props).merge({
      :name=>target_role, :containment=>true})))
    props2 = Intermediate::Reference.new(self, _oppositeProps(raw_props).merge({
      :name=>own_role, :upperBound=>1, :containment=>false}))
    FeatureBlockEvaluator.eval(block, props1, props2)
    _build_internal(props1, props2)
  end
  
  # This is the inverse of one_to_many provided for convenience.
  def many_to_one(target_role, target_class, own_role, raw_props={}, &block)
    props1 = Intermediate::Reference.new(target_class, _ownProps(raw_props).merge({
      :name=>target_role, :upperBound=>1, :containment=>false}))
    props2 = Intermediate::Reference.new(self, _setManyUpperBound(_oppositeProps(raw_props).merge({
      :name=>own_role, :containment=>false})))
    FeatureBlockEvaluator.eval(block, props1, props2)
    _build_internal(props1, props2)
  end
  
  # Add a bidirectional many-to-many association between two classes.
  # The class this method is called on is refered to as _own_class_ in 
  # the following.
  # 
  # Instances of own_class can use 'own_role' to access _many_ associated instances
  # of type 'target_class'. Instances of 'target_class' can use 'target_role' to
  # access _many_ associated instances of own_class.
  # 
  # This class method adds the following instance methods where 'ownRole' and
  # 'targetRole' are to be replaced by the given role names:
  #   own_class#addOwnRole(value, index=-1)
  #   own_class#removeOwnRole(value)
  #   own_class#ownRole
  #   target_class#addTargetRole
  #   target_class#removeTargetRole=(value)
  #   target_class#targetRole
  # Note that the first letter of the role name is turned into an uppercase 
  # for the add and remove methods.
  # 
  # When an element is added on either side, this element also receives the element
  # is is added to as a new element.
  # 
  def many_to_many(target_role, target_class, own_role, raw_props={}, &block)
    props1 = Intermediate::Reference.new(target_class, _setManyUpperBound(_ownProps(raw_props).merge({
      :name=>target_role, :containment=>false})))
    props2 = Intermediate::Reference.new(self, _setManyUpperBound(_oppositeProps(raw_props).merge({
      :name=>own_role, :containment=>false})))
    FeatureBlockEvaluator.eval(block, props1, props2)
    _build_internal(props1, props2)
  end
  
  # Add a bidirectional one-to-one association between two classes.
  # The class this method is called on is refered to as _own_class_ in 
  # the following.
  # 
  # Instances of own_class can use 'own_role' to access _one_ associated instance
  # of type 'target_class'. Instances of 'target_class' can use 'target_role' to
  # access _one_ associated instance of own_class.
  # 
  # This class method adds the following instance methods where 'ownRole' and
  # 'targetRole' are to be replaced by the given role names:
  #   own_class#ownRole
  #   own_class#ownRole=(value)
  #   target_class#targetRole
  #   target_class#targetRole=(value)
  # 
  # When an element is set on either side, this element also receives the element
  # is is added to as the new element.
  # 
  def one_to_one(target_role, target_class, own_role, raw_props={}, &block)
    props1 = Intermediate::Reference.new(target_class, _ownProps(raw_props).merge({
      :name=>target_role, :upperBound=>1, :containment=>false}))
    props2 = Intermediate::Reference.new(self, _oppositeProps(raw_props).merge({
      :name=>own_role, :upperBound=>1, :containment=>false}))
    FeatureBlockEvaluator.eval(block, props1, props2)
    _build_internal(props1, props2)
  end
  
  def contains_one(target_role, target_class, own_role, raw_props={}, &block)
    props1 = Intermediate::Reference.new(target_class, _ownProps(raw_props).merge({
      :name=>target_role, :upperBound=>1, :containment=>true}))
    props2 = Intermediate::Reference.new(self, _oppositeProps(raw_props).merge({
      :name=>own_role, :upperBound=>1, :containment=>false}))
    FeatureBlockEvaluator.eval(block, props1, props2)
    _build_internal(props1, props2)
  end
    
  def _metamodel_description # :nodoc:
    @metamodel_description ||= []
  end

  def _add_metamodel_description(desc) # :nodoc
    @metamodel_description ||= []
    @metamodelDescriptionByName ||= {}
    @metamodel_description.delete(@metamodelDescriptionByName[desc.value(:name)])
    @metamodel_description << desc 
    @metamodelDescriptionByName[desc.value(:name)] = desc
  end
  
  def abstract
    @abstract = true
  end
  
  def _abstract_class
    @abstract || false
  end
  
  def inherited(c)
    c.send(:include, c.const_set(:ClassModule, Module.new))
    MetamodelBuilder::ConstantOrderHelper.classCreated(c)
  end
    
  protected
    
  # Central builder method
  # 
  def _build_internal(props1, props2=nil)
    _add_metamodel_description(props1)
    if props1.many?
      _build_many_methods(props1, props2)
    else
      _build_one_methods(props1, props2)
    end
    if props2
      # this is a bidirectional reference
      props1.opposite, props2.opposite = props2, props1
      other_class = props1.impl_type      
      other_class._add_metamodel_description(props2)
      raise "Internal error: second description must be a reference description" \
        unless props2.reference?
      if props2.many?
        other_class._build_many_methods(props2, props1)
      else
        other_class._build_one_methods(props2, props1)
      end
    end
  end
  
  # To-One association methods
  # 
  def _build_one_methods(props, other_props=nil)
    name = props.value(:name)
    other_role = other_props && other_props.value(:name)

    if props.value(:derived)
      build_derived_method(name, props, :one)
    else
      @@one_read_builder ||= ERB.new <<-CODE
      
        def get<%= firstToUpper(name) %>
          <% if !props.reference? && props.value(:defaultValueLiteral) %>
            <% defVal = props.value(:defaultValueLiteral) %>
            <% check_default_value_literal(defVal, props) %>
            <% defVal = '"'+defVal+'"' if props.impl_type == String %>
            <% defVal = ':'+defVal if props.impl_type.is_a?(DataTypes::Enum) && props.impl_type != DataTypes::Boolean %>
            (defined? @<%= name %>) ? @<%= name %> : <%= defVal %>
          <% else %>
            @<%= name %>
          <% end %>
        end
        <% if name != "class" %>
          alias <%= name %> get<%= firstToUpper(name) %>
        <% end %>

      CODE
      self::ClassModule.module_eval(@@one_read_builder.result(binding))
    end
    
    if props.value(:changeable)
      @@one_write_builder ||= ERB.new <<-CODE
        
        def set<%= firstToUpper(name) %>(val)
          return if (defined? @<%= name %>) && val == @<%= name %>
          <%= type_check_code("val", props) %>
          oldval = @<%= name %>
          @<%= name %> = val
          <% if other_role %>
            oldval._unregister<%= firstToUpper(other_role) %>(self) unless oldval.nil? || oldval.is_a?(MMGeneric)
            val._register<%= firstToUpper(other_role) %>(self) unless val.nil? || val.is_a?(MMGeneric)
          <% end %>
          <% if props.reference? && props.value(:containment) %>
            val._set_container(self, :<%= name %>) unless val.nil?
            oldval._set_container(nil, nil) unless oldval.nil?
          <% end %>
        end 
        alias <%= name %>= set<%= firstToUpper(name) %>

        def _register<%= firstToUpper(name) %>(val)
          <% if other_role %>
            @<%= name %>._unregister<%= firstToUpper(other_role) %>(self) unless @<%= name %>.nil? || @<%= name %>.is_a?(MMGeneric)
          <% end %>
          <% if props.reference? && props.value(:containment) %>
            @<%= name %>._set_container(nil, nil) unless @<%= name %>.nil?
            val._set_container(self, :<%= name %>) unless val.nil?
          <% end %>
          @<%= name %> = val
        end
        
        def _unregister<%= firstToUpper(name) %>(val)
          <% if props.reference? && props.value(:containment) %>
            @<%= name %>._set_container(nil, nil) unless @<%= name %>.nil?
          <% end %>
          @<%= name %> = nil
        end
        
      CODE
      self::ClassModule.module_eval(@@one_write_builder.result(binding))

    end
  end
  
  # To-Many association methods
  # 
  def _build_many_methods(props, other_props=nil)
    name = props.value(:name)
    other_role = other_props && other_props.value(:name)

    if props.value(:derived)
      build_derived_method(name, props, :many)
    else
      @@many_read_builder ||= ERB.new <<-CODE
      
        def get<%= firstToUpper(name) %>
          ( @<%= name %> ? @<%= name %>.dup : [] )
        end
        <% if name != "class" %>
          alias <%= name %> get<%= firstToUpper(name) %>
        <% end %>
              
      CODE
      self::ClassModule.module_eval(@@many_read_builder.result(binding))
    end
    
    if props.value(:changeable)
      @@many_write_builder ||= ERB.new <<-CODE
    
        def add<%= firstToUpper(name) %>(val, index=-1)
          @<%= name %> = [] unless @<%= name %>
          return if val.nil? || (@<%= name %>.any?{|e| e.object_id == val.object_id} && (val.is_a?(MMBase) || val.is_a?(MMGeneric)))
          <%= type_check_code("val", props) %>
          @<%= name %>.insert(index, val)
          <% if other_role %>
            val._register<%= firstToUpper(other_role) %>(self) unless val.is_a?(MMGeneric)
          <% end %>
          <% if props.reference? && props.value(:containment) %>
            val._set_container(self, :<%= name %>)
          <% end %>
        end
        
        def remove<%= firstToUpper(name) %>(val)
          @<%= name %> = [] unless @<%= name %>
          @<%= name %>.each_with_index do |e,i|
            if e.object_id == val.object_id
              @<%= name %>.delete_at(i)
              <% if props.reference? && props.value(:containment) %>
                val._set_container(nil, nil)
              <% end %>
              <% if other_role %>
                val._unregister<%= firstToUpper(other_role) %>(self) unless val.is_a?(MMGeneric)
              <% end %>
              return
            end
          end    
        end
        
        def set<%= firstToUpper(name) %>(val)
          return if val.nil?
          raise _assignmentTypeError(self, val, Enumerable) unless val.is_a? Enumerable
          get<%= firstToUpper(name) %>.each {|e|
            remove<%= firstToUpper(name) %>(e)
          }
          val.each {|v|
            add<%= firstToUpper(name) %>(v)
          }
        end
        alias <%= name %>= set<%= firstToUpper(name) %>
        
        def _register<%= firstToUpper(name) %>(val)
          @<%= name %> = [] unless @<%= name %>
          @<%= name %>.push val
          <% if props.reference? && props.value(:containment) %>
            val._set_container(self, :<%= name %>)
          <% end %>
        end

        def _unregister<%= firstToUpper(name) %>(val)
          @<%= name %>.delete val
          <% if props.reference? && props.value(:containment) %>
            val._set_container(nil, nil)
          <% end %>
        end
        
      CODE
      self::ClassModule.module_eval(@@many_write_builder.result(binding))
    end    
        
  end  
  
  private

  def build_derived_method(name, props, kind)
    raise "Implement method #{name}_derived instead of method #{name}" \
      if (public_instance_methods+protected_instance_methods+private_instance_methods).include?(name)
    @@derived_builder ||= ERB.new <<-CODE
    
      def get<%= firstToUpper(name) %>
        raise "Derived feature requires public implementation of method <%= name %>_derived" \
          unless respond_to?(:<%= name+"_derived" %>)
        val = <%= name %>_derived
        <% if kind == :many %>
          raise _assignmentTypeError(self,val,Enumerable) unless val && val.is_a?(Enumerable)
          val.each do |v|
            <%= type_check_code("v", props) %>
          end
        <% else %>
          <%= type_check_code("val", props) %>
        <% end %>  
        val
      end
      <% if name != "class" %>
        alias <%= name %> get<%= firstToUpper(name) %>
      <% end %>
      #TODO final_method :<%= name %>
      
    CODE
    self::ClassModule.module_eval(@@derived_builder.result(binding))
  end

  def check_default_value_literal(literal, props)
    return if literal.nil? || props.impl_type == String
    if props.impl_type == Integer || props.impl_type == RGen::MetamodelBuilder::DataTypes::Long
      unless literal =~ /^\d+$/
        raise StandardError.new("Property #{props.value(:name)} can not take value #{literal}, expected an Integer")
      end
    elsif props.impl_type == Float
      unless literal =~ /^\d+\.\d+$/
        raise StandardError.new("Property #{props.value(:name)} can not take value #{literal}, expected a Float")
      end
    elsif props.impl_type == RGen::MetamodelBuilder::DataTypes::Boolean
      unless ["true", "false"].include?(literal)
        raise StandardError.new("Property #{props.value(:name)} can not take value #{literal}, expected true or false")
      end
    elsif props.impl_type.is_a?(RGen::MetamodelBuilder::DataTypes::Enum)
      unless props.impl_type.literals.include?(literal.to_sym)
        raise StandardError.new("Property #{props.value(:name)} can not take value #{literal}, expected one of #{props.impl_type.literals_as_strings.join(', ')}")
      end
    else
      raise StandardError.new("Unkown type "+props.impl_type.to_s)
    end
  end
  
  def type_check_code(varname, props)
    code = ""
    if props.impl_type == RGen::MetamodelBuilder::DataTypes::Long
      code << "unless #{varname}.nil? || #{varname}.is_a?(Integer) || #{varname}.is_a?(MMGeneric)"
      code << "\n"
      expected = "Integer"
    elsif props.impl_type.is_a?(Class)
      code << "unless #{varname}.nil? || #{varname}.is_a?(#{props.impl_type}) || #{varname}.is_a?(MMGeneric)"
      code << " || #{varname}.is_a?(BigDecimal)" if props.impl_type == Float && defined?(BigDecimal)
      code << "\n"
      expected = props.impl_type.to_s
    elsif props.impl_type.is_a?(RGen::MetamodelBuilder::DataTypes::Enum)
      code << "unless #{varname}.nil? || [#{props.impl_type.literals_as_strings.join(',')}].include?(#{varname}) || #{varname}.is_a?(MMGeneric)\n"
      expected = "["+props.impl_type.literals_as_strings.join(',')+"]"
    else
      raise StandardError.new("Unkown type "+props.impl_type.to_s)
    end
    code << "raise _assignmentTypeError(self,#{varname},\"#{expected}\")\n"
    code << "end"
    code    
  end  
  
  def _ownProps(props)
    Hash[*(props.select{|k,v| !(k.to_s =~ /^opposite_/)}.flatten)]
  end

  def _oppositeProps(props)
    r = {}
    props.each_pair do |k,v|
      if k.to_s =~ /^opposite_(.*)$/
        r[$1.to_sym] = v
      end
    end
    r
  end

  def _setManyUpperBound(props)
    props[:upperBound] = -1 unless props[:upperBound].is_a?(Integer) && props[:upperBound] > 1
    props
  end
    
end

end

end
