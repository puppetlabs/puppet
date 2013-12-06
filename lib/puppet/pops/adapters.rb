# The Adapters module contains adapters for Documentation, Origin, SourcePosition, and Loader.
#
module Puppet::Pops::Adapters
  # A documentation adapter adapts an object with a documentation string.
  # (The intended use is for a source text parser to extract documentation and store this
  # in DocumentationAdapter instances).
  #
  class DocumentationAdapter < Puppet::Pops::Adaptable::Adapter
    # @return [String] The documentation associated with an object
    attr_accessor :documentation
  end

  # An origin adapter adapts an object with where it came from. This origin
  # describes the resource (a file, etc.) where source text originates.
  # Instances of SourcePosAdapter is then used on other objects in a model to
  # describe their relative position versus the origin.
  #
  # @see Puppet::Pops::Utils#find_adapter
  #
  class OriginAdapter < Puppet::Pops::Adaptable::Adapter
    # @return [String] the origin of the adapted (usually a filename)
    attr_accessor :origin
  end

  # A SourcePosAdapter holds a reference to something *locateable* (a position in source text).
  # This is represented by an instance of Puppet::Pops::Parser::Locateable (it has an offset, a length, and
  # a Puppet::Pops::Parser::Locator) that are used together to provide derived information (line, and position
  # on line).
  # This somewhat complex structure makes it possible to correctly refer to a source position
  # in source that is embedded in some resource; a parser only sees the embedded snippet of source text
  # and does not know where it was embedded. It also enables lazy evaluation of source positions (they are
  # rarely needed - typically just when there is an error to report.
  #
  # @note It is relatively expensive to compute line and postion on line - it is not something that
  #   should be done for every token or model object.
  #
  # @see Puppet::Pops::Utils#find_adapter
  #
  class SourcePosAdapter < Puppet::Pops::Adaptable::Adapter
    attr_accessor :locatable

    def locator
      locatable.locator
    end

    def offset
      locatable.offset
    end

    def length
      locatable.length
    end

    # Produces the line number for the given offset.
    # @note This is an expensive operation
    #
    def line
      locatable.locator.line_for_offset(offset)
    end

    # Produces the position on the line of the given offset.
    # @note This is an expensive operation
    #
    def pos
      locatable.locator.pos_on_line(offset)
    end

    # Extracts the text represented by this source position (the string is obtained from the locator)
    def extract_text
      locatable.locator.string.slice(offset, length)
    end

    # Extracts the text represented by this source position from a given string (which needs to be identical
    # to what is held in the locator - why is this needed ? 
    # TODO:
    def extract_text_from_string(string)
      string.slice(offset, length)
    end
  end

  # A LoaderAdapter adapts an object with a {Puppet::Pops::Loader}. This is used to make further loading from the
  # perspective of the adapted object take place in the perspective of this Loader.
  #
  # It is typically enough to adapt the root of a model as a search is made towards the root of the model
  # until a loader is found, but there is no harm in duplicating this information provided a contained
  # object is adapted with the correct loader.
  #
  # @see Puppet::Pops::Utils#find_adapter
  #
  class LoaderAdapter < Puppet::Pops::Adaptable::Adapter
    # @return [Puppet::Pops::Loader] the loader
    attr_accessor :loader
  end
end
