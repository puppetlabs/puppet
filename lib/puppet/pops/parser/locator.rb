# Helper class that keeps track of where line breaks are located and can answer questions about positions.
#
class Puppet::Pops::Parser::Locator

  RUBY_1_9_3 = (1 << 16 | 9 << 8 | 3)
  RUBY_2_0_0 = (2 << 16 | 0 << 8 | 0)
  RUBYVER_ARRAY = RUBY_VERSION.split(".").collect {|s| s.to_i }
  RUBYVER = (RUBYVER_ARRAY[0] << 16 | RUBYVER_ARRAY[1] << 8 | RUBYVER_ARRAY[2])

  # Computes a symbol representing which ruby runtime this is running on
  # This implementation will fail if there are more than 255 minor or micro versions of ruby
  #
  def self.locator_version
    if RUBYVER >= RUBY_2_0_0
      :ruby20
    elsif RUBYVER >= RUBY_1_9_3
      :ruby19
    else
      :ruby18
    end
  end
  LOCATOR_VERSION = locator_version

  # Constant set to true if multibyte is supported (includes multibyte extended regular expressions)
  MULTIBYTE = !!(LOCATOR_VERSION == :ruby19 || LOCATOR_VERSION == :ruby20)

  # Creates, or recreates a Locator. A Locator is created if index is not given (a scan is then
  # performed of the given source string.
  #
  def self.locator(string, file, index = nil)
    case LOCATOR_VERSION
    when :ruby20, :ruby19
      Locator19.new(string, file, index)
    else
      Locator18.new(string, file, index)
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

  # Returns the length measured in number of characters from the given start and end reported offseta
  def char_length(offset, end_offset)
  end

  # Returns the line index - an array of line offsets for the start position of each line, starting at 0 for
  # the first line.
  #
  def line_index()
  end

  private

  class AbstractLocator < Puppet::Pops::Parser::Locator
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
      compute_line_index unless !index.nil?
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

  class Locator18 < AbstractLocator

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
  end
end
