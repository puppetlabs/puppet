# Interface for something that is "locateable"
# It holds a reference to a Locator which can compute line number, position on line etc.
# The basic information is offset and length.
class Puppet::Pops::Parser::Locatable
  # The locator for this locatable
  def locator
  end

  # The offset in the locator's content
  def offset
  end

  # The length in the locator from the given offset
  def length
  end

  # The file (if given) of the locator's content
  def file
    locator.file
  end

  # This class is useful for testing
  class Fixed < Puppet::Pops::Parser::Locatable
    attr_reader :offset
    attr_reader :pos
    attr_reader :line
    attr_reader :length

    def initialize(line, column, offset, length)
      @line = line
      @pos = column
      @offset = offset
      @length = length
    end

    def locator
      self
    end

    def line_for_offset(offset)
      @line
    end

    def pos_on_line(offset)
      @pos
    end
  end

  class Lazy < Puppet::Pops::Parser::Locatable
    attr_reader :morphed

    def initialize(loc_reference)
      @ref = loc_reference # some object from which location information can be derived
      @morphed = false
    end

    def locator
      ensure_morphed
      @ref.locator
    end

    def offset
      ensure_morphed
      @ref.offset
    end

    def length
      ensure_morphed
      @ref.length
    end

    def ensure_morphed
      unless @morphed
        @morphed = true
        @ref = morph(@ref) or raise ArgumentError.new("Internal Error: Range not given something locatable in 'from'")
      end
    end

    def morph(o)
      # the object may be a Locatable (= done), a PopsObject (find its source pos and locator), or
      # a factory wrapping a pops object
      #
      o = o.current if o.is_a? Puppet::Pops::Model::Factory
      case o
      when Puppet::Pops::Model::PopsObject
        adapter = Puppet::Pops::Adapters::SourcePosAdapter.get(o)
        adapter.nil? ? nil : adapter.locatable
      when Puppet::Pops::Parser::Locatable
        o
      else
        raise ArgumentError, "InternalError: Locator Range can not handle an instance of #{o.class}"
      end
    end

  end
  # Combines two Locators into a range. The given from locator must have smaller offset, but
  # may overlap with given to-locator.
  #
  class Range < Puppet::Pops::Parser::Locatable::Lazy
    attr_reader :from
    attr_reader :to
    attr_reader :morphed

    def initialize(from, to)
      @from = from
      @to = to
      @morphed = false
    end

    def locator
      ensure_morphed
      @from.locator
    end

    def offset
      ensure_morphed
      @from.offset
    end

    def length
      ensure_morphed
      @length ||= @to.offset - @from.offset + @to.length
    end

    def ensure_morphed
      return if @morphed
      @morphed = true
      @from = morph(@from) or raise ArgumentError.new("Internal Error: Range not given something locatable in 'from'")
      if @to.nil?
        @to = @from # i.e. no range if @to is nil
      else
        @to = morph(@to) or raise ArgumentError.new("Internal Error: Range not given something locatable in 'to'")
      end
    end

  end
end
