# This module adds functionality to a resource to make it
# capable of evaluating the DSL resource type block and also
# hooking into the scope system.
require 'puppet/resource/type_collection_helper'

module Puppet::DSL::ResourceHelper
    include Puppet::Resource::TypeCollectionHelper

    FUNCTION_MAP = {:acquire => :include}

    # Try to convert a missing method into a resource type or a function.
    def method_missing(name, *args)
        return create_resource(name, args[0], args[1]) if valid_type?(name)

        name = map_function(name)

        return call_function(name, args) if Puppet::Parser::Functions.function(name)

        super
    end

    def set_instance_variables
        eachparam do |param|
            instance_variable_set("@#{param.name}", param.value)
        end
    end

    def create_resource(type, names, arguments = nil)
        names = [names] unless names.is_a?(Array)

        arguments ||= {}
        raise ArgumentError, "Resource arguments must be provided as a hash" unless arguments.is_a?(Hash)

        names.collect do |name|
            resource = Puppet::Parser::Resource.new(:type => type, :title => name, :scope => scope)
            arguments.each do |param, value|
                resource[param] = value
            end

            scope.compiler.add_resource(scope, resource)
            resource
        end
    end

    def call_function(name, args)
        return false unless method = Puppet::Parser::Functions.function(name)
        scope.send(method, *args)
    end

    def valid_type?(name)
        return true if [:class, :node].include?(name)
        return true if Puppet::Type.type(name)
        return true if known_resource_types.definition(name)
        return false
    end

    private

    def map_function(name)
        return FUNCTION_MAP[name] || name
    end
end
