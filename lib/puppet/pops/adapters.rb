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

  # A SourcePosAdapter describes a position relative to an origin. (Typically an {OriginAdapter} is
  # associated with the root of a model. This origin has a URI to the resource, and a line number.
  # The offset in the SourcePosAdapter is then relative to this origin.
  # (This somewhat complex structure makes it possible to correctly refer to a source position
  # in source that is embedded in some resource; a parser only sees the embedded snippet of source text
  # and does not know where it was embedded).
  #
  # @see Puppet::Pops::Utils#find_adapter
  #
  class SourcePosAdapter < Puppet::Pops::Adaptable::Adapter
    # @return [Fixnum] The start line in source starting from 1
    attr_accessor :line

    # @return [Fixnum] The position on the start_line (in characters) starting from 0
    attr_accessor :pos

    # @return [Fixnum] The (start) offset of source text characters
    #   (starting from 0) representing the adapted object.
    #   Value may be nil
    attr_accessor :offset

    # @return [Fixnum] The length (count) of characters of source text
    #   representing the adapted object from the origin. Not including any
    #   trailing whitespace.
    attr_accessor :length
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
