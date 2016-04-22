module Puppet::Pops
module Parser
# Helper class that keeps track of where line breaks are located and can answer questions about positions.
#
class Locator
  # Creates, or recreates a Locator. A Locator is created if index is not given (a scan is then
  # performed of the given source string.
  #
  def self.locator(string, file, index = nil, char_offsets = false)
    if char_offsets
      LocatorForChars.new(string, file, index);
    else
      Locator19.new(string, file, index)
    end
  end

  # Returns the file name associated with the string content
  def file
  end

  # Returns the string content
  def string
  end

  # Returns the position on line (first position on a line is 1)
  def pos_on_line(offset)
  end

  # Returns the line number (first line is 1) for the given offset
  def line_for_offset(offset)
  end

  # Returns the offset on line (first offset on a line is 0).
  #
  def offset_on_line(offset)
  end

  # Returns the character offset for a given reported offset
  def char_offset(byte_offset)
  end

  # Returns the length measured in number of characters from the given start and end reported offset
  def char_length(offset, end_offset)
  end

  # Returns the length measured in number of characters from the given start and end byte offseta
  def char_length(offset, end_offset)
  end

  # Extracts the text from offset with given length (measured in what the locator uses for offset)
  # @returns String - the extracted text
  def extract_text(offset, length)
  end

  # Returns the line index - an array of line offsets for the start position of each line, starting at 0 for
  # the first line.
  #
  def line_index()
  end

  # A Sublocator locates a concrete locator (subspace) in a virtual space.
  # The `leading_line_count` is the (virtual) number of lines preceding the first line in the concrete locator.
  # The `leading_offset` is the (virtual) byte offset of the first byte in the concrete locator.
  # The `leading_line_offset` is the (virtual) offset / margin in characters for each line.
  #
  # This illustrates characters in the sublocator (`.`) inside the subspace (`X`):
  #
  #      1:XXXXXXXX
  #      2:XXXX.... .. ... ..
  #      3:XXXX. . .... ..
  #      4:XXXX............
  #
  # This sublocator would be configured with leading_line_count = 1,
  # leading_offset=8, and leading_line_offset=4
  #
  # Note that leading_offset must be the same for all lines and measured in characters.
  #
  class SubLocator < Locator
    attr_reader :locator
    attr_reader :leading_line_count
    attr_reader :leading_offset
    attr_reader :leading_line_offset

    def self.sub_locator(string, file, leading_line_count, leading_offset, leading_line_offset)
      self.new(Locator.locator(string, file),
        leading_line_count,
        leading_offset,
        leading_line_offset)
    end

    def initialize(locator, leading_line_count, leading_offset, leading_line_offset)
      @locator = locator
      @leading_line_count = leading_line_count
      @leading_offset = leading_offset
      @leading_line_offset = leading_line_offset
    end

    def file
      @locator.file
    end

    def string
      @locator.string
    end

    # Given offset is offset in the subspace
    def line_for_offset(offset)
      @locator.line_for_offset(offset) + @leading_line_count
    end

    # Given offset is offset in the subspace
    def offset_on_line(offset)
      @locator.offset_on_line(offset) + @leading_line_offset
    end

    # Given offset is offset in the subspace
    def char_offset(offset)
      effective_line = @locator.line_for_offset(offset)
      locator.char_offset(offset) + (effective_line * @leading_line_offset) + @leading_offset
    end

    # Given offsets are offsets in the subspace
    def char_length(offset, end_offset)
      effective_line = @locator.line_for_offset(end_offset) - @locator.line_for_offset(offset)
      locator.char_length(offset, end_offset) + (effective_line * @leading_line_offset)
    end

    def pos_on_line(offset)
      offset_on_line(offset) +1
    end
  end

  private

  class AbstractLocator < Locator
    attr_accessor :line_index
    attr_accessor :string
    attr_accessor :prev_offset
    attr_accessor :prev_line
    attr_reader   :string
    attr_reader   :file

    # Create a locator based on a content string, and a boolean indicating if ruby version support multi-byte strings
    # or not.
    #
    def initialize(string, file, index = nil)
      @string = string.freeze
      @file = file.freeze
      @prev_offset = nil
      @prev_line = nil
      @line_index = index
      compute_line_index if index.nil?
    end

    # Returns the position on line (first position on a line is 1)
    def pos_on_line(offset)
      offset_on_line(offset) +1
    end

    def to_location_hash(reported_offset, end_offset)
      pos        = pos_on_line(reported_offset)
      offset     = char_offset(reported_offset)
      length     = char_length(reported_offset, end_offset)
      start_line = line_for_offset(reported_offset)
      { :line => start_line, :pos => pos, :offset => offset, :length => length}
    end

    # Returns the index of the smallest item for which the item > the given value
    # This is a min binary search. Although written in Ruby it is only slightly slower than
    # the corresponding method in C in Ruby 2.0.0 - the main benefit to use this method over
    # the Ruby C version is that it returns the index (not the value) which means there is not need
    # to have an additional structure to get the index (or record the index in the structure). This
    # saves both memory and CPU. It also does not require passing a block that is called since this
    # method is specialized to search the line index.
    #
    def ary_bsearch_i(ary, value)
      low = 0
      high = ary.length
      mid = nil
      smaller = false
      satisfied = false
      v = nil

      while low < high do
          mid = low + ((high - low) / 2)
          v = (ary[mid] > value)
          if v == true
            satisfied = true
            smaller = true
          elsif !v
            smaller = false
          else
            raise TypeError, "wrong argument, must be boolean or nil, got '#{v.class}'"
          end

          if smaller
            high = mid
          else
            low = mid + 1;
          end
      end

      return nil if low == ary.length
      return nil if !satisfied
      return low
    end

    # Common impl for 18 and 19 since scanner is byte based
    def compute_line_index
      scanner = StringScanner.new(string)
      result = [0] # first line starts at 0
      while scanner.scan_until(/\n/)
        result << scanner.pos
      end
      self.line_index = result.freeze
    end

    # Returns the line number (first line is 1) for the given offset
    def line_for_offset(offset)
      if prev_offset == offset
        # use cache
        return prev_line
      end
      if line_nbr = ary_bsearch_i(line_index, offset)
        # cache
        prev_offset = offset
        prev_line = line_nbr
        return line_nbr
      end
      # If not found it is after last
      # clear cache
      prev_offset = prev_line = nil
      return line_index.size
    end
  end

  class LocatorForChars < AbstractLocator

    def offset_on_line(offset)
      line_offset = line_index[ line_for_offset(offset)-1 ]
      offset - line_offset
    end

    def char_offset(char_offset)
      char_offset
    end

    def char_length(offset, end_offset)
      end_offset - offset
    end

    # Extracts the text from char offset with given byte length
    # @returns String - the extracted text
    def extract_text(offset, length)
      string.slice(offset, length)
    end

  end

  # This implementation is for Ruby19 and Ruby20. It uses byteslice to get strings from byte based offsets.
  # For Ruby20 this is faster than using the Stringscanner.charpos method (byteslice outperforms it, when
  # strings are frozen).
  #
  class Locator19 < AbstractLocator

    # Returns the offset on line (first offset on a line is 0).
    # Ruby 19 is multibyte but has no character position methods, must use byteslice
    def offset_on_line(offset)
      line_offset = line_index[ line_for_offset(offset)-1 ]
      string.byteslice(line_offset, offset-line_offset).length
    end

    # Returns the character offset for a given byte offset
    # Ruby 19 is multibyte but has no character position methods, must use byteslice
    def char_offset(byte_offset)
      string.byteslice(0, byte_offset).length
    end

    # Returns the length measured in number of characters from the given start and end byte offseta
    def char_length(offset, end_offset)
      string.byteslice(offset, end_offset - offset).length
    end

    # Extracts the text from byte offset with given byte length
    # @returns String - the extracted text
    def extract_text(offset, length)
      string.byteslice(offset, length)
    end
  end
end
end
end
