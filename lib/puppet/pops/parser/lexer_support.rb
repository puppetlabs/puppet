# This is an integral part of the Lexer. It is broken out into a separate module
# for maintainability of the code, and making the various parts of the lexer focused.
#
module Puppet::Pops::Parser::LexerSupport

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
  def lex_error_without_pos(issue, args = {})
    raise Puppet::ParseErrorWithIssue.new(issue.format(args), nil, nil, nil, nil, issue.issue_code)
  end

  # Raises a Puppet::ParserErrorWithIssue with the given issue and arguments
  def lex_error(issue, args = {}, pos=nil)
    raise create_lex_error(issue, args, pos)
  end

  def filename
    file = @locator.file
    file.is_a?(String) && !file.empty? ? file : nil
  end

  def line(pos)
    @locator.line_for_offset(pos || @scanner.pos)
  end

  def position(pos)
    @locator.pos_on_line(pos || @scanner.pos)
  end

  def lex_warning(issue, args = {}, pos=nil)
    Puppet::Util::Log.create({
        :level => :warning,
        :message => issue.format(args),
        :issue_code => issue.issue_code,
        :file => filename,
        :line => line(pos),
        :pos => position(pos),
      })
  end

  # @param issue [Puppet::Pops::Issues::Issue] the issue
  # @param args [Hash<Symbol,String>] Issue arguments
  # @param pos [Integer]
  # @return [Puppet::ParseErrorWithIssue] the created error
  def create_lex_error(issue, args = {}, pos = nil)
    Puppet::ParseErrorWithIssue.new(
        issue.format(args),
        filename,
        line(pos),
        position(pos),
        nil,
        issue.issue_code)
  end

  # Asserts that the given string value is a float, or an integer in decimal, octal or hex form.
  # An error is raised if the given value does not comply.
  #
  def assert_numeric(value, length)
    if value =~ /^0[xX].*$/
      lex_error(Puppet::Pops::Issues::INVALID_HEX_NUMBER, {:value => value}, length)     unless value =~ /^0[xX][0-9A-Fa-f]+$/

    elsif value =~ /^0[^.].*$/
      lex_error(Puppet::Pops::Issues::INVALID_OCTAL_NUMBER, {:value => value}, length)   unless value =~ /^0[0-7]+$/

    else
      lex_error(Puppet::Pops::Issues::INVALID_DECIMAL_NUMBER, {:value => value}, length) unless value =~ /0?\d+(?:\.\d+)?(?:[eE]-?\d+)?/
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
