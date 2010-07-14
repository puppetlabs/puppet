# This module adds functionality to a resource to make it
# capable of evaluating the DSL resource type block and also
# hooking into the scope system.
require 'puppet/resource/type_collection_helper'

class Puppet::DSL::ResourceAPI
  include Puppet::Resource::TypeCollectionHelper

  FUNCTION_MAP = {:acquire => :include}

  attr_reader :scope, :resource, :block

  def environment
    scope.environment
  end

  def evaluate
    set_instance_variables
    instance_eval(&block)
  end

  def initialize(resource, scope, block)
    @scope = scope
    @resource = resource
    @block = block
  end

  # Try to convert a missing method into a resource type or a function.
  def method_missing(name, *args)
    raise "MethodMissing loop when searching for #{name} with #{args.inspect}" if searching_for_method?
    @searching_for_method = true
    return create_resource(name, args[0], args[1]) if valid_type?(name)

    name = map_function(name)

    return call_function(name, args) if Puppet::Parser::Functions.function(name)

    super
  ensure
    @searching_for_method = false
  end

  def set_instance_variables
    resource.eachparam do |param|
      instance_variable_set("@#{param.name}", param.value)
    end
    @title = resource.title
    @name ||= resource.title
  end

  def create_resource(type, names, arguments = nil)
    names = [names] unless names.is_a?(Array)

    arguments ||= {}
    raise ArgumentError, "Resource arguments must be provided as a hash" unless arguments.is_a?(Hash)

    names.collect do |name|
      resource = Puppet::Parser::Resource.new(type, name, :scope => scope)
      arguments.each do |param, value|
        resource[param] = value
      end

      resource.exported = true if exporting?
      resource.virtual = true if virtualizing?
      scope.compiler.add_resource(scope, resource)
      resource
    end
  end

  def call_function(name, args)
    return false unless method = Puppet::Parser::Functions.function(name)
    scope.send(method, *args)
  end

  def export(resources = nil, &block)
    if resources
      resources.each { |resource| resource.exported = true }
      return resources
    end
    @exporting = true
    instance_eval(&block)
  ensure
    @exporting = false
  end

  def virtual(resources = nil, &block)
    if resources
      resources.each { |resource| resource.virtual = true }
      return resources
    end
    @virtualizing = true
    instance_eval(&block)
  ensure
    @virtualizing = false
  end

  def valid_type?(name)
    return true if [:class, :node].include?(name)
    return true if Puppet::Type.type(name)
    return(known_resource_types.definition(name) ? true : false)
  end

  private

  def exporting?
    @exporting
  end

  def map_function(name)
    FUNCTION_MAP[name] || name
  end

  def searching_for_method?
    @searching_for_method
  end

  def virtualizing?
    @virtualizing
  end
end
