require 'rgen/metamodel_builder'

module Puppet::Pops
module Binder
# The Bindings model is a model of Key to Producer mappings (bindings).
# It is composed of a meta-model part (bindings_model_meta.rb), and
# and implementation part (this file).
#
# @see BindingsFactory The BindingsFactory for more details on how to create model instances.
# @api public
require 'puppet/pops/binder/bindings_model_meta'

# TODO: See PUP-2978 for possible performance optimization

# Mix in implementation into the generated code
module Bindings
  class BindingsModelObject
    include Visitable
    include Adaptable
    include Containment
  end

  class ConstantProducerDescriptor
    module ClassModule
      def setValue(v)
        @value = v
      end
      def getValue()
        @value
      end
      def value=(v)
        @value = v
      end
    end
  end

  class NamedArgument
    module ClassModule
      def setValue(v)
        @value = v
      end
      def getValue()
        @value
      end
      def value=(v)
        @value = v
      end
    end
  end

  class InstanceProducerDescriptor
    module ClassModule
      def addArguments(val, index =-1)
        @arguments ||= []
        @arguments.insert(index, val)
      end
      def removeArguments(val)
        raise "unsupported operation"
      end
      def setArguments(values)
        @arguments = []
        values.each {|v| addArguments(v) }
      end
    end
  end

end
end
end

