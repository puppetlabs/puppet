require 'puppet/resource/type'

module Puppet::DSL::ResourceTypeAPI
    def resource_type(name, *args, &block)
        result = mk_resource_type(:definition, name, Hash.new, block)
        result.set_arguments(munge_type_arguments(args))
        result
    end

    def hostclass(name, options = {}, &block)
        mk_resource_type(:hostclass, name, options, block)
    end

    def node(name, options = {}, &block)
        mk_resource_type(:node, name, options, block)
    end

    private

    def mk_resource_type(type, name, options, code)
        klass = Puppet::Resource::Type.new(type, name, options)

        klass.ruby_code = code if code

        Puppet::Node::Environment.new.known_resource_types.add klass

        klass
    end

    def munge_type_arguments(args)
        args.inject([]) do |result, item|
            if item.is_a?(Hash)
                item.each { |p, v| result << [p, v] }
            else
                result << item
            end
            result
        end
    end
end
