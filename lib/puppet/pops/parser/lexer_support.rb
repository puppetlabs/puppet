# This is an integral part of the Lexer. It is broken out into a separate module
# for maintainability of the code, and making the various parts of the lexer focused.
#
module Puppet::Pops::Parser::LexerSupport

  # Formats given message by appending file, line and position if available.
  def positioned_message(msg, pos = nil)
    result = [msg]
    file = @locator.file
    line = @locator.line_for_offset(pos || @scanner.pos)
    pos =  @locator.pos_on_line(pos || @scanner.pos)

    result << "in file #{file}" if file && file.is_a?(String) && !file.empty?
    result << "at line #{line}:#{pos}"
    result.join(" ")
  end

  # Returns "<eof>" if at end of input, else the following 5 characters with \n \r \t escaped
  def followed_by
    return "<eof>" if @scanner.eos?
    result = @scanner.rest[0,5] + "..."
    result.gsub!("\t", '\t')
    result.gsub!("\n", '\n')
    result.gsub!("\r", '\r')
    result
  end

  # Returns a quoted string using " or ' depending on the given a strings's content
  def format_quote(q)
    if q == "'"
      '"\'"'
    else
      "'#{q}'"
    end
  end

  # Raises a Puppet::LexError with the given message
  def lex_error_without_pos msg
    raise Puppet::LexError.new(msg)
  end

  # Raises a Puppet::LexError with the given message
  def lex_error(msg, pos=nil)
    raise Puppet::LexError.new(positioned_message(msg, pos))
  end

  # Asserts that the given string value is a float, or an integer in decimal, octal or hex form.
  # An error is raised if the given value does not comply.
  #
  def assert_numeric(value, length)
    if value =~ /^0[xX].*$/
      lex_error("Not a valid hex number #{value}", length)     unless value =~ /^0[xX][0-9A-Fa-f]+$/

    elsif value =~ /^0[^.].*$/
      lex_error("Not a valid octal number #{value}", length)   unless value =~ /^0[0-7]+$/

    else
      lex_error("Not a valid decimal number #{value}", length) unless value =~ /0?\d+(?:\.\d+)?(?:[eE]-?\d+)?/
    end
  end

  # A TokenValue keeps track of the token symbol, the lexed text for the token, its length
  # and its position in its source container. There is a cost associated with computing the
  # line and position on line information.
  #
  class TokenValue < Puppet::Pops::Parser::Locatable
    attr_reader :token_array
    attr_reader :offset
    attr_reader :locator

    def initialize(token_array, offset, locator)
      @token_array = token_array
      @offset = offset
      @locator = locator
    end

    def length
      @token_array[2]
    end

    def [](key)
      case key
      when :value
        @token_array[1]
      when :file
        @locator.file
      when :line
        @locator.line_for_offset(@offset)
      when :pos
        @locator.pos_on_line(@offset)
      when :length
        @token_array[2]
      when :locator
        @locator
      when :offset
        @offset
      else
        nil
      end
    end

    def to_s
      # This format is very compact and is intended for debugging output from racc parsser in
      # debug mode. If this is made more elaborate the output from a debug run becomes very hard to read.
      #
      "'#{self[:value]} #{@token_array[0]}'"
    end
    # TODO: Make this comparable for testing
    # vs symbolic, vs array with symbol and non hash, array with symbol and hash)
    #
  end

end
