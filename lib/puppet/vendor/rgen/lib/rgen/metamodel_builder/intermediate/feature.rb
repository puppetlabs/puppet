require 'rgen/metamodel_builder/data_types'

module RGen

module MetamodelBuilder

module Intermediate

class Feature
  attr_reader :etype, :impl_type

  def value(prop)
    @props[prop]
  end
  
  def annotations
    @annotations ||= []
  end

  def many?
    value(:upperBound) > 1 || value(:upperBound) == -1
  end

  def reference?
    is_a?(Reference)
  end

  protected

  def check(props)
    @props.keys.each do |p|
      kind = props[p]
      raise StandardError.new("invalid property #{p}") unless kind
      raise StandardError.new("property '#{p}' not set") if value(p).nil? && kind == :required
    end
  end

end

class Attribute < Feature

  Properties = { 
    :name => :required, 
    :ordered => :required, 
    :unique => :required,
    :changeable => :required,
    :volatile => :required,
    :transient => :required,
    :unsettable => :required,
    :derived => :required,
    :lowerBound => :required,
    :upperBound => :required,
    :defaultValueLiteral => :optional
  }

  Defaults = {
    :ordered => true,
    :unique => true,
    :changeable => true,
    :volatile => false,
    :transient => false,
    :unsettable => false,
    :derived => false,
    :lowerBound => 0
  }

  Types = { 
    String => :EString,
    Integer => :EInt,
    RGen::MetamodelBuilder::DataTypes::Long => :ELong,
    Float => :EFloat,
    RGen::MetamodelBuilder::DataTypes::Boolean => :EBoolean,
    Object => :ERubyObject,
    Class => :ERubyClass 
  }

  def self.default_value(prop)
    Defaults[prop]
  end
  
  def self.properties
    Properties.keys.sort{|a,b| a.to_s <=> b.to_s}
  end

  def initialize(type, props)
    @props = Defaults.merge(props)
    type ||= String
    @etype = Types[type]
    if @etype
      @impl_type = type
    elsif type.is_a?(RGen::MetamodelBuilder::DataTypes::Enum)
      @etype = :EEnumerable
      @impl_type = type
    else
      raise ArgumentError.new("invalid type '#{type}'")
    end
    if @props[:derived]
      @props[:changeable] = false
      @props[:volatile] = true
      @props[:transient] = true
    end    
    check(Properties)
  end

end

class Reference < Feature
  attr_accessor :opposite

  Properties = { 
    :name => :required, 
    :ordered => :required, 
    :unique => :required,
    :changeable => :required,
    :volatile => :required,
    :transient => :required,
    :unsettable => :required,
    :derived => :required,
    :lowerBound => :required,
    :upperBound => :required,
    :resolveProxies => :required,
    :containment => :required
  }

  Defaults = {
    :ordered => true,
    :unique => true,
    :changeable => true,
    :volatile => false,
    :transient => false,
    :unsettable => false,
    :derived => false,
    :lowerBound => 0,
    :resolveProxies => true
  }

  def self.default_value(prop)
    Defaults[prop]
  end
  
  def self.properties
    Properties.keys.sort{|a,b| a.to_s <=> b.to_s}
  end

  def initialize(type, props)
    @props = Defaults.merge(props)
    if type.respond_to?(:_metamodel_description) 
      @etype = nil
      @impl_type = type
    else
      raise ArgumentError.new("'#{type}' (#{type.class}) is not a MMBase in reference #{props[:name]}")
    end
    if @props[:derived]
      @props[:changeable] = false
      @props[:volatile] = true
      @props[:transient] = true
    end    
    check(Properties)
  end

end

end

end

end

