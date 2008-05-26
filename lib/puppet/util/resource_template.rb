require 'puppet/util'
require 'puppet/util/logging'
require 'erb'

# A template wrapper that evaluates a template in the
# context of a resource, allowing the resource attributes
# to be looked up from within the template.
#  This provides functionality essentially equivalent to
# the language's template() function.  You pass your file
# path and the resource you want to use into the initialization
# method, then call result() on the instance, and you get back
# a chunk of text.
#  The resource's parameters are available as instance variables
# (as opposed to the language, where we use a method_missing trick).
class Puppet::Util::ResourceTemplate
    include Puppet::Util::Logging

    def evaluate
        set_resource_variables
        ERB.new(File.read(@file), 0, "-").result(binding)
    end

    def initialize(file, resource)
        raise ArgumentError, "Template %s does not exist" % file unless FileTest.exist?(file)
        @file = file
        @resource = resource
    end

    private

    def set_resource_variables
        @resource.to_hash.each do |param, value|
            var = "@#{param.to_s}"
            instance_variable_set(var, value)
        end
    end
end

