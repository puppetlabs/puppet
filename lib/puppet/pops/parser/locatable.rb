# Interface for something that is "locatable" (holds offset and length).
class Puppet::Pops::Parser::Locatable

  # The offset in the locator's content
  def offset
  end

  # The length in the locator from the given offset
  def length
  end

  # This class is useful for testing
  class Fixed < Puppet::Pops::Parser::Locatable
    attr_reader :offset
    attr_reader :length

    def initialize(offset, length)
      @offset = offset
      @length = length
    end
  end

end
