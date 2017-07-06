#
# The Puppet Pops Metamodel Implementation
#
# The Puppet Pops Metamodel consists of two parts; the metamodel expressed with RGen in model_meta.rb,
# and this file which mixes in implementation details.
#

require 'rgen/metamodel_builder'
require 'rgen/ecore/ecore'
require 'rgen/ecore/ecore_ext'
require 'rgen/ecore/ecore_to_ruby'

module Puppet::Pops
  require 'puppet/pops/model/model_meta'

  # TODO: See PUP-2978 for possible performance optimization

  # Mix in implementation into the generated code
  module Model

    class PopsObject
      include Visitable
      include Adaptable
      include Containment
    end

    class Positioned
      module ClassModule
        def set_loc(offset, length)
          @offset = offset
          @length = length
        end
      end
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
            setLocator(result = Parser::Locator.locator(source_text, source_ref(), line_offsets))
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
            adapter = Adapters::SourcePosAdapter.adapt(self)
            # Get the program (root), and deal with case when not contained in a program
            program = eAllContainers.find {|c| c.is_a?(Program) }
            source_ref = program.nil? ? '' : program.source_ref

            # An outer locator is needed since SubLocator only deals with offsets. This outer locator
            # has 0,0 as origin.
            outer_locator = Parser::Locator.locator(adpater.extract_text, source_ref, line_offsets)

            # Create a sublocator that describes an offset from the outer
            # NOTE: the offset of self is the same as the sublocator's leading_offset
            result = Parser::Locator::SubLocator.new(outer_locator,
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

    class QualifiedReference
      module ClassModule
        def value
          @value ||= cased_value.downcase
        end
      end
    end

    class Program < PopsObject
      module ClassModule
        def locator
          unless result = getLocator
            setLocator(result = Parser::Locator.locator(source_text, source_ref(), line_offsets, char_offsets))
          end
          result
        end
      end
    end

  end

end
