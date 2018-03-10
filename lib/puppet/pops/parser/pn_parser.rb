module Puppet::Pops
module Parser

class PNParser
  LIT_TRUE = 'true'.freeze
  LIT_FALSE = 'false'.freeze
  LIT_NIL = 'nil'.freeze

  TOKEN_END = 0
  TOKEN_BOOL = 1
  TOKEN_NIL = 2
  TOKEN_INT = 3
  TOKEN_FLOAT = 4
  TOKEN_IDENTIFIER = 5
  TOKEN_WS = 0x20
  TOKEN_STRING = 0x22
  TOKEN_KEY = 0x3a
  TOKEN_LP = 0x28
  TOKEN_RP = 0x29
  TOKEN_LB = 0x5b
  TOKEN_RB = 0x5d
  TOKEN_LC = 0x7b
  TOKEN_RC = 0x7d

  TYPE_END = 0
  TYPE_WS = 1
  TYPE_DELIM = 2
  TYPE_KEY_START = 3
  TYPE_STRING_START = 4
  TYPE_IDENTIFIER = 5
  TYPE_MINUS = 6
  TYPE_DIGIT = 7
  TYPE_ALPHA = 8

  def initialize
    @char_types = self.class.char_types
  end

  def parse(text, locator = nil, offset = nil)
    @locator = locator
    @offset = offset
    @text = text
    @codepoints = text.codepoints.to_a.freeze
    @pos = 0
    @token = TOKEN_END
    @token_value = nil
    next_token
    parse_next
  end

  private

  def parse_next
    case @token
    when TOKEN_LB
      parse_array
    when TOKEN_LC
      parse_map
    when TOKEN_LP
      parse_call
    when TOKEN_BOOL, TOKEN_INT, TOKEN_FLOAT, TOKEN_STRING, TOKEN_NIL
      parse_literal
    when TOKEN_END
      parse_error(_('unexpected end of input'))
    else
      parse_error(_('unexpected %{value}' % { value: @token_value }))
    end
  end

  def parse_error(message)
    file = ''
    line = 1
    pos = 1
    if @locator
      file = @locator.file
      line = @locator.line_for_offset(@offset)
      pos  = @locator.pos_on_line(@offset)
    end
    @codepoints[0, @pos].each do |c|
      if c == 0x09
        line += 1
        pos = 1
      end
    end
    raise Puppet::ParseError.new(message, file, line, pos)
  end

  def parse_literal
    pn = PN::Literal.new(@token_value)
    next_token
    pn
  end

  def parse_array
    next_token
    PN::List.new(parse_elements(TOKEN_RB))
  end

  def parse_map
    next_token
    entries = []
    while @token != TOKEN_RC && @token != TOKEN_END
      parse_error(_('map key expected')) unless @token == TOKEN_KEY
      key = @token_value
      next_token
      entries << parse_next.with_name(key)
    end
    next_token
    PN::Map.new(entries)
  end

  def parse_call
    next_token
    parse_error(_("expected identifier to follow '('")) unless @token == TOKEN_IDENTIFIER
    name = @token_value
    next_token
    PN::Call.new(name, *parse_elements(TOKEN_RP))
  end

  def parse_elements(end_token)
    elements = []
    while @token != end_token && @token != TOKEN_END
      elements << parse_next
    end
    parse_error(_("missing '%{token}' to end list") % { token: end_token.chr(Encoding::UTF_8) } ) unless @token == end_token
    next_token
    elements
  end

  # All methods below belong to the PN lexer
  def self.char_types
    unless instance_variable_defined?(:@char_types)
      @char_types = Array.new(0x80, TYPE_IDENTIFIER)
      @char_types[0] = TYPE_END
      [0x09, 0x0d, 0x0a, 0x20].each { |n| @char_types[n] = TYPE_WS }
      [TOKEN_LP, TOKEN_RP, TOKEN_LB, TOKEN_RB, TOKEN_LC, TOKEN_RC].each { |n| @char_types[n] = TYPE_DELIM }
      @char_types[0x2d] = TYPE_MINUS
      (0x30..0x39).each { |n| @char_types[n] = TYPE_DIGIT }
      (0x41..0x5a).each { |n| @char_types[n] = TYPE_ALPHA }
      (0x61..0x7a).each { |n| @char_types[n] = TYPE_ALPHA }
      @char_types[TOKEN_KEY] = TYPE_KEY_START
      @char_types[TOKEN_STRING] = TYPE_STRING_START
      @char_types.freeze
    end
    @char_types
  end

  def next_token
    skip_white
    s = @pos
    c = next_cp

    case @char_types[c]
    when TYPE_END
      @token_value = nil
      @token = TOKEN_END

    when TYPE_MINUS
      if @char_types[peek_cp] == TYPE_DIGIT
        next_token # consume float or integer
        @token_value = -@token_value
      else
        consume_identifier(s)
      end

    when TYPE_DIGIT
      skip_decimal_digits
      c = peek_cp
      if c == 0x2e # '.'
        @pos += 1
        consume_float(s, c)
      else
        @token_value = @text[s..@pos].to_i
        @token = TOKEN_INT
      end

    when TYPE_DELIM
      @token_value = @text[s]
      @token = c

    when TYPE_KEY_START
      if @char_types[peek_cp] == TYPE_ALPHA
        next_token
        @token = TOKEN_KEY
      else
        parse_error(_("expected identifier after ':'"))
      end

    when TYPE_STRING_START
      consume_string
    else
      consume_identifier(s)
    end
  end

  def consume_identifier(s)
    while @char_types[peek_cp] >= TYPE_IDENTIFIER do
      @pos += 1
    end
    id = @text[s...@pos]
    case id
    when LIT_TRUE
      @token = TOKEN_BOOL
      @token_value = true
    when LIT_FALSE
      @token = TOKEN_BOOL
      @token_value = false
    when LIT_NIL
      @token = TOKEN_NIL
      @token_value = nil
    else
      @token = TOKEN_IDENTIFIER
      @token_value = id
    end
  end

  def consume_string
    s = @pos
    b = ''
    loop do
      c = next_cp
      case c
      when TOKEN_END
        @pos = s - 1
        parse_error(_('unterminated quote'))
      when TOKEN_STRING
        @token_value = b
        @token = TOKEN_STRING
        break
      when 0x5c # '\'
        c = next_cp
        case c
        when 0x74 # 't'
          b << "\t"
        when 0x72 # 'r'
          b << "\r"
        when 0x6e # 'n'
          b << "\n"
        when TOKEN_STRING
          b << '"'
        when 0x5c # '\'
          b << "\\"
        when 0x6f # 'o'
          c = 0
          3.times do
            n = next_cp
            if 0x30 <= n && n <= 0x37c
              c *= 8
              c += n - 0x30
            else
              parse_error(_('malformed octal quote'))
            end
          end
          b << c
        else
          b << "\\"
          b << c
        end
      else
        b << c
      end
    end
  end

  def consume_float(s, d)
    parse_error(_('digit expected')) if skip_decimal_digits == 0
    c = peek_cp
    if d == 0x2e # '.'
      if c == 0x45 || c == 0x65 # 'E' or 'e'
        @pos += 1
        parse_error(_('digit expected')) if skip_decimal_digits == 0
        c = peek_cp
      end
    end
    parse_error(_('digit expected')) if @char_types[c] == TYPE_ALPHA
    @token_value = @text[s...@pos].to_f
    @token = TOKEN_FLOAT
  end

  def skip_decimal_digits
    count = 0
    c = peek_cp
    if c == 0x2d || c == 0x2b # '-' or '+'
      @pos += 1
      c = peek_cp
    end

    while @char_types[c] == TYPE_DIGIT do
      @pos += 1
      c = peek_cp
      count += 1
    end
    count
  end

  def skip_white
    while @char_types[peek_cp] == TYPE_WS do
      @pos += 1
    end
  end

  def next_cp
    c = 0
    if @pos < @codepoints.size
      c = @codepoints[@pos]
      @pos += 1
    end
    c
  end

  def peek_cp
    @pos < @codepoints.size ? @codepoints[@pos] : 0
  end
end
end
end
