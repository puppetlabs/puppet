#
# The Puppet Pops Metamodel
#
# This module contains a formal description of the Puppet Pops (*P*uppet *OP*eration instruction*S*).
# It describes a Metamodel containing DSL instructions, a description of PuppetType and related
# classes needed to evaluate puppet logic.
# The metamodel resembles the existing AST model, but it is a semantic model of instructions and
# the types that they operate on rather than an Abstract Syntax Tree, although closely related.
#
# The metamodel is anemic (has no behavior) except basic datatype and type
# assertions and reference/containment assertions.
# The metamodel is also a generalized description of the Puppet DSL to enable the
# same metamodel to be used to express Puppet DSL models (instances) with different semantics as
# the language evolves.
#
# The metamodel is concretized by a validator for a particular version of
# the Puppet DSL language.
#
# This metamodel is expressed using RGen.
#

require 'rgen/metamodel_builder'
require 'rgen/ecore/ecore'
require 'rgen/ecore/ecore_ext'
require 'rgen/ecore/ecore_to_ruby'

module Puppet::Pops
  require 'puppet/pops/model/model_meta'

  # TODO: Later, if faster dump/restore of the model is wanted (it saves ~50ms in load time)
  # this can be done by something like this:
  # if dumpfile.exists?
  #   root_epackage = Marshal.load(File.read(Dumpfile))
  #   Model = RGen::ECore::ECoreToRuby.new.create_module(root_epackage)
  # else
  #   # build the metamodel part
  #   # move the require of the meta part here
  #  File.open(dumpfile, "w") {|f| f.write(Marshal.dump(Puppet::Pops::Model.ecore)) }
  #end

  # Mix in implementation into the generated code
  module Model

    class PopsObject
      include Puppet::Pops::Visitable
      include Puppet::Pops::Adaptable
      include Puppet::Pops::Containment
    end

    class LocatableExpression
      module ClassModule
        # Go through the gymnastics of making either value or pattern settable
        # with synchronization to the other form. A derived value cannot be serialized
        # and we want to serialize the pattern. When recreating the object we need to
        # recreate it from the pattern string.
        # The below sets both values if one is changed.
        #
        def locator
          unless result = getLocator
            setLocator(result = Puppet::Pops::Parser::Locator.locator(source_text, source_ref(), line_offsets))
          end
          result
        end
      end
    end

    class SubLocatedExpression
      module ClassModule
        def locator
          unless result = getLocator
            # Adapt myself to get the Locator for me
            adapter = Puppet::Pops::Adapters::SourcePosAdapter.adapt(self)
            # Get the program (root), and deal with case when not contained in a program
            program = eAllContainers.find {|c| c.is_a?(Program) }
            source_ref = program.nil? ? '' : program.source_ref

            # An outer locator is needed since SubLocator only deals with offsets. This outer locator
            # has 0,0 as origin.
            outer_locator = Puppet::Pops::Parser::Locator.locator(adpater.extract_text, source_ref, line_offsets)

            # Create a sublocator that describes an offset from the outer
            # NOTE: the offset of self is the same as the sublocator's leading_offset
            result = Puppet::Pops::Parser::Locator::SubLocator.new(outer_locator,
              leading_line_count, offset, leading_line_offset)
            setLocator(result)
          end
          result
        end
      end
    end

    class LiteralRegularExpression
      module ClassModule
        # Go through the gymnastics of making either value or pattern settable
        # with synchronization to the other form. A derived value cannot be serialized
        # and we want to serialize the pattern. When recreating the object we need to
        # recreate it from the pattern string.
        # The below sets both values if one is changed.
        #
        def value= regexp
          setValue regexp
          setPattern regexp.to_s
        end

        def pattern= regexp_string
          setPattern regexp_string
          setValue Regexp.new(regexp_string)
        end
      end
    end

    class AbstractResource
      module ClassModule
        def virtual_derived
          form == :virtual || form == :exported
        end

        def exported_derived
          form == :exported
        end
      end
    end

    class Program < PopsObject
      module ClassModule
        def locator
          unless result = getLocator
            setLocator(result = Puppet::Pops::Parser::Locator.locator(source_text, source_ref(), line_offsets))
          end
          result
        end
      end
    end

  end

end
