# frozen_string_literal: true

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
      LocatorForChars.new(string, file, index)
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

  def to_s
    "Locator for file #{file}"
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

  # Returns the length measured in number of characters from the given start and end byte offset
  def char_length(offset, end_offset)
  end

  # Extracts the text from offset with given length (measured in what the locator uses for offset)
  # @returns String - the extracted text
  def extract_text(offset, length)
  end

  def extract_tree_text(ast)
    first = ast.offset
    last = first + ast.length
    ast._pcore_all_contents([]) do |m|
      next unless m.is_a?(Model::Positioned)

      m_offset = m.offset
      m_last = m_offset + m.length
      first = m_offset if m_offset < first
      last = m_last if m_last > last
    end
    extract_text(first, last - first)
  end

  # Returns the line index - an array of line offsets for the start position of each line, starting at 0 for
  # the first line.
  #
  def line_index
  end

  # Common byte based impl that works for all rubies (stringscanner is byte based
  def self.compute_line_index(string)
    scanner = StringScanner.new(string)
    result = [0] # first line starts at 0
    while scanner.scan_until(/\n/)
      result << scanner.pos
    end
    result.freeze
  end

  # Produces an URI with path?line=n&pos=n. If origin is unknown the URI is string:?line=n&pos=n
  def to_uri(ast)
    f = file
    if f.nil? || f.empty?
      f = 'string:'
    else
      f = Puppet::Util.path_to_uri(f).to_s
    end
    offset = ast.offset
    URI("#{f}?line=#{line_for_offset(offset)}&pos=#{pos_on_line(offset)}")
  end

  class AbstractLocator < Locator
    attr_accessor :line_index
    attr_reader   :string
    attr_reader   :file

    # Create a locator based on a content string, and a boolean indicating if ruby version support multi-byte strings
    # or not.
    #
    def initialize(string, file, line_index = nil)
      @string = string.freeze
      @file = file.freeze
      @prev_offset = nil
      @prev_line = nil
      @line_index = line_index.nil? ? Locator.compute_line_index(@string) : line_index
    end

    # Returns the position on line (first position on a line is 1)
    def pos_on_line(offset)
      offset_on_line(offset) + 1
    end

    def to_location_hash(reported_offset, end_offset)
      pos        = pos_on_line(reported_offset)
      offset     = char_offset(reported_offset)
      length     = char_length(reported_offset, end_offset)
      start_line = line_for_offset(reported_offset)
      { :line => start_line, :pos => pos, :offset => offset, :length => length }
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
      return nil unless satisfied

      return low
    end

    def hash
      [string, file, line_index].hash
    end

    # Equal method needed by serializer to perform tabulation
    def eql?(o)
      self.class == o.class && string == o.string && file == o.file && line_index == o.line_index
    end

    # Returns the line number (first line is 1) for the given offset
    def line_for_offset(offset)
      if @prev_offset == offset
        # use cache
        return @prev_line
      end

      line_nbr = ary_bsearch_i(line_index, offset)
      if line_nbr
        # cache
        @prev_offset = offset
        @prev_line = line_nbr
        return line_nbr
      end
      # If not found it is after last
      # clear cache
      @prev_offset = @prev_line = nil
      return line_index.size
    end
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
  # A SubLocator is only used during parsing as the parser will translate the local offsets/lengths to
  # the parent locator when a sublocated expression is reduced. Do not call the methods
  # `char_offset` or `char_length` as those methods will raise an error.
  #
  class SubLocator < AbstractLocator
    attr_reader :locator
    attr_reader :leading_line_count
    attr_reader :leading_offset
    attr_reader :has_margin
    attr_reader :margin_per_line

    def initialize(locator, str, leading_line_count, leading_offset, has_margin, margin_per_line)
      super(str, locator.file)
      @locator = locator
      @leading_line_count = leading_line_count
      @leading_offset = leading_offset
      @has_margin = has_margin
      @margin_per_line = margin_per_line

      # Since lines can have different margin - accumulated margin per line must be computed
      # and since this accumulated margin adjustment is needed more than once; both for start offset,
      # and for end offset (to compute global length) it is computed up front here.
      # The accumulated_offset holds the sum of all removed margins before a position on line n (line index is 1-n,
      # and (unused) position 0 is always 0).
      # The last entry is duplicated since there will be  the line "after last line" that would otherwise require
      # conditional logic.
      #
      @accumulated_margin = margin_per_line.each_with_object([0]) { |val, memo| memo << memo[-1] + val; }
      @accumulated_margin << @accumulated_margin[-1]
    end

    def file
      @locator.file
    end

    # Returns array with transposed (local) offset and (local) length. The transposed values
    # take the margin into account such that it is added to the content to the right
    #
    # Using X to denote margin and where end of line is explicitly shown as \n:
    # ```
    # XXXXabc\n
    # XXXXdef\n
    # ```
    # A local offset of 0 is translated to the start of the first heredoc line, and a length of 1 is adjusted to
    # 5 - i.e to cover "XXXXa". A local offset of 1, with length 1 would cover "b".
    # A local offset of 4 and length 1 would cover "XXXXd"
    #
    # It is possible that lines have different margin and that is taken into account.
    #
    def to_global(offset, length)
      # simple case, no margin
      return [offset + @leading_offset, length] unless @has_margin

      # compute local start and end line
      start_line = line_for_offset(offset)
      end_line = line_for_offset(offset + length)

      # complex case when there is a margin
      transposed_offset = offset == 0 ? @leading_offset : offset + @leading_offset + @accumulated_margin[start_line]
      transposed_length = length +
                          @accumulated_margin[end_line] - @accumulated_margin[start_line] +    # the margins between start and end (0 is line 1)
                          (offset_on_line(offset) == 0 ? margin_per_line[start_line - 1] : 0)  # include start's margin in position 0
      [transposed_offset, transposed_length]
    end

    # Do not call this method
    def char_offset(offset)
      raise "Should not be called"
    end

    # Do not call this method
    def char_length(offset, end_offset)
      raise "Should not be called"
    end
  end

  class LocatorForChars < AbstractLocator
    def offset_on_line(offset)
      line_offset = line_index[line_for_offset(offset) - 1]
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
    include Types::PuppetObject

    # rubocop:disable Naming/MemoizedInstanceVariableName
    def self._pcore_type
      @type ||= Types::PObjectType.new('Puppet::AST::Locator', {
                                         'attributes' => {
                                           'string' => Types::PStringType::DEFAULT,
                                           'file' => Types::PStringType::DEFAULT,
                                           'line_index' => {
                                             Types::KEY_TYPE => Types::POptionalType.new(Types::PArrayType.new(Types::PIntegerType::DEFAULT)),
                                             Types::KEY_VALUE => nil
                                           }
                                         }
                                       })
    end
    # rubocop:enable Naming/MemoizedInstanceVariableName

    # Returns the offset on line (first offset on a line is 0).
    # Ruby 19 is multibyte but has no character position methods, must use byteslice
    def offset_on_line(offset)
      line_offset = line_index[line_for_offset(offset) - 1]
      @string.byteslice(line_offset, offset - line_offset).length
    end

    # Returns the character offset for a given byte offset
    # Ruby 19 is multibyte but has no character position methods, must use byteslice
    def char_offset(byte_offset)
      string.byteslice(0, byte_offset).length
    end

    # Returns the length measured in number of characters from the given start and end byte offset
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
