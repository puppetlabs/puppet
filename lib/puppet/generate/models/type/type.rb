require 'puppet/generate/models/type/property'

module Puppet
  module Generate
    module Models
      module Type
        # A model for Puppet resource types.
        class Type
          # Gets the name of the type as a Puppet string literal.
          attr_reader :name

          # Gets the doc string of the type.
          attr_reader :doc

          # Gets the properties of the type.
          attr_reader :properties

          # Gets the parameters of the type.
          attr_reader :parameters

          # Gets the title patterns of the type
          attr_reader :title_patterns

          # Gets the isomorphic member attribute of the type
          attr_reader :isomorphic

          # Initializes a type model.
          # @param type [Puppet::Type] The Puppet type to model.
          # @return [void]
          def initialize(type)
            @name = Puppet::Pops::Types::StringConverter.convert(type.name.to_s, '%p')
            @doc = type.doc.strip
            @properties = type.properties.map { |p| Property.new(p) }
            @parameters = type.parameters.map do |name|
              Property.new(type.paramclass(name))
            end
            @title_patterns = Hash[type.title_patterns.map do |mapping|
              [
                "/#{mapping[0].source.gsub(/\//, '\/')}/",
                mapping[1].map { |names|
                  next if names.empty?
                  raise Puppet::Error, 'title patterns that use procs are not supported.' if names.size != 1
                  Puppet::Pops::Types::StringConverter.convert(names[0].to_s, '%p')
                }
              ]
            end]
            @isomorphic = type.isomorphic?
          end

          def render(template)
            template.result(binding)
          end
        end
      end
    end
  end
end
