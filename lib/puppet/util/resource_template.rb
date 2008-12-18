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
#  For example, say you have a resource that generates a file.  You would
# need to implement the following style of `generate` method:
#
#   def generate
#       template = Puppet::Util::ResourceTemplate.new("/path/to/template", self)
#
#       return Puppet::Type.type(:file).new :path => "/my/file",
#           :content => template.evaluate
#   end
#
# This generated file gets added to the catalog (which is what `generate` does),
# and its content is the result of the template.  You need to use instance
# variables in your template, so if your template just needs to have the name
# of the generating resource, it would just have:
#
#   <%= @name %>
#
# Since the ResourceTemplate class sets as instance variables all of the resource's
# parameters.
#
# Note that this example uses the generating resource as its source of
# parameters, which is generally most useful, since it allows you to configure
# the generated resource via the generating resource.
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

