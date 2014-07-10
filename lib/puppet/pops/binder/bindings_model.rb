require 'rgen/metamodel_builder'

# The Bindings model is a model of Key to Producer mappings (bindings).
# The central concept is that a Bindings is a nested structure of bindings.
# A top level Bindings should be a NamedBindings (the name is used primarily
# in error messages). A Key is a Type/Name combination.
#
# TODO: In this version, references to "any object" uses the class Object,
#       but this is only temporary. The intent is to use specific Puppet Objects
#       that are typed using the Puppet Type System (to enable serialization).
#
# @see Puppet::Pops::Binder::BindingsFactory The BindingsFactory for more details on how to create model instances.
# @api public
module Puppet::Pops::Binder
  require 'puppet/pops/binder/bindings_model_meta'

  # TODO: Later, if faster dump/restore of the meta model is wanted, this can then be done here
  # like shown below. (But this has to wait until Rgen issues in 0.7.0 has been fixed for this model
  # since there are errors in meta code generation when there is a containment reference to
  # a modeled class in another package.
  #
  # if dumpfile.exists?
  #   root_epackage = Marshal.load(File.read(dumpfile))
  #   Bindings = RGen::ECore::ECoreToRuby.new.create_module(root_epackage)
  # else
  #   # move the require of the meta model here
  #   File.open(dumpfile, 'w') {|f| f.write(Marshal.dump(Puppet::Pops::Binder::Bindings.ecore)) }
  # end

  # Mix in implementation into the generated code
  module Bindings
    class BindingsModelObject
      include Puppet::Pops::Visitable
      include Puppet::Pops::Adaptable
      include Puppet::Pops::Containment
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
