require 'puppet/indirector'

# A class for managing data lookups
class Puppet::DataBinding

  # Set up indirection, so that data can be looked for in the complier
  extend Puppet::Indirector

  indirects(:data_binding, :terminus_setting => :data_binding_terminus,
    :doc => "Where to find external data bindings.")

  # A class that acts just enough like a Puppet::Parser::Scope to
  # fool Hiera's puppet backend. This class doesn't actually do anything
  # but it does allow people to use the puppet backend with the hiera
  # data bindings withough causing problems.
  class Variables
    FAKE_RESOURCE = Struct.new(:name).new("fake").freeze
    FAKE_CATALOG = Struct.new(:classes).new([].freeze).freeze

    def initialize(variable_bindings)
      @variable_bindings = variable_bindings
    end

    def [](name)
      @variable_bindings[name]
    end

    def resource
      FAKE_RESOURCE
    end

    def catalog
      FAKE_CATALOG
    end

    def function_include(name)
      # noop
    end
  end
end
