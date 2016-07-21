# The Lexer is responsbile for turning source text into tokens.
# This version is a performance enhanced lexer (in comparison to the 3.x and earlier "future parser" lexer.
#
# Old returns tokens [:KEY, value, { locator = }
# Could return [[token], locator]
# or Token.new([token], locator) with the same API x[0] = token_symbol, x[1] = self, x[:key] = (:value, :file, :line, :pos) etc

require 'strscan'
require 'puppet/pops/parser/lexer_support'
require 'puppet/pops/parser/heredoc_support'
require 'puppet/pops/parser/interpolation_support'
require 'puppet/pops/parser/epp_support'
require 'puppet/pops/parser/slurp_support'

module Puppet::Pops
module Parser
class Lexer2
  include LexerSupport
  include HeredocSupport
  include InterpolationSupport
  include SlurpSupport
  include EppSupport

  # ALl tokens have three slots, the token name (a Symbol), the token text (String), and a token text length.
  # All operator and punctuation tokens reuse singleton arrays Tokens that require unique values create
  # a unique array per token.
  #
  # PEFORMANCE NOTES:
  # This construct reduces the amount of object that needs to be created for operators and punctuation.
  # The length is pre-calculated for all singleton tokens. The length is used both to signal the length of
  # the token, and to advance the scanner position (without having to advance it with a scan(regexp)).
  #
  TOKEN_LBRACK       = [:LBRACK,       '['.freeze,   1].freeze
  TOKEN_LISTSTART    = [:LISTSTART,    '['.freeze,   1].freeze
  TOKEN_RBRACK       = [:RBRACK,       ']'.freeze,   1].freeze
  TOKEN_LBRACE       = [:LBRACE,       '{'.freeze,   1].freeze
  TOKEN_RBRACE       = [:RBRACE,       '}'.freeze,   1].freeze
  TOKEN_SELBRACE     = [:SELBRACE,     '{'.freeze,   1].freeze
  TOKEN_LPAREN       = [:LPAREN,       '('.freeze,   1].freeze
  TOKEN_WSLPAREN     = [:WSLPAREN,     '('.freeze,   1].freeze
  TOKEN_RPAREN       = [:RPAREN,       ')'.freeze,   1].freeze

  TOKEN_EQUALS       = [:EQUALS,       '='.freeze,   1].freeze
  TOKEN_APPENDS      = [:APPENDS,      '+='.freeze,  2].freeze
  TOKEN_DELETES      = [:DELETES,      '-='.freeze,  2].freeze

  TOKEN_ISEQUAL      = [:ISEQUAL,      '=='.freeze,  2].freeze
  TOKEN_NOTEQUAL     = [:NOTEQUAL,     '!='.freeze,  2].freeze
  TOKEN_MATCH        = [:MATCH,        '=~'.freeze,  2].freeze
  TOKEN_NOMATCH      = [:NOMATCH,      '!~'.freeze,  2].freeze
  TOKEN_GREATEREQUAL = [:GREATEREQUAL, '>='.freeze,  2].freeze
  TOKEN_GREATERTHAN  = [:GREATERTHAN,  '>'.freeze,   1].freeze
  TOKEN_LESSEQUAL    = [:LESSEQUAL,    '<='.freeze,  2].freeze
  TOKEN_LESSTHAN     = [:LESSTHAN,     '<'.freeze,   1].freeze

  TOKEN_FARROW       = [:FARROW,       '=>'.freeze,  2].freeze
  TOKEN_PARROW       = [:PARROW,       '+>'.freeze,  2].freeze

  TOKEN_LSHIFT       = [:LSHIFT,       '<<'.freeze,  2].freeze
  TOKEN_LLCOLLECT    = [:LLCOLLECT,    '<<|'.freeze, 3].freeze
  TOKEN_LCOLLECT     = [:LCOLLECT,     '<|'.freeze,  2].freeze

  TOKEN_RSHIFT       = [:RSHIFT,       '>>'.freeze,  2].freeze
  TOKEN_RRCOLLECT    = [:RRCOLLECT,    '|>>'.freeze, 3].freeze
  TOKEN_RCOLLECT     = [:RCOLLECT,     '|>'.freeze,  2].freeze

  TOKEN_PLUS         = [:PLUS,         '+'.freeze,   1].freeze
  TOKEN_MINUS        = [:MINUS,        '-'.freeze,   1].freeze
  TOKEN_DIV          = [:DIV,          '/'.freeze,   1].freeze
  TOKEN_TIMES        = [:TIMES,        '*'.freeze,   1].freeze
  TOKEN_MODULO       = [:MODULO,       '%'.freeze,   1].freeze

  TOKEN_NOT          = [:NOT,          '!'.freeze,   1].freeze
  TOKEN_DOT          = [:DOT,          '.'.freeze,   1].freeze
  TOKEN_PIPE         = [:PIPE,         '|'.freeze,   1].freeze
  TOKEN_AT           = [:AT ,          '@'.freeze,   1].freeze
  TOKEN_ATAT         = [:ATAT ,        '@@'.freeze,  2].freeze
  TOKEN_COLON        = [:COLON,        ':'.freeze,   1].freeze
  TOKEN_COMMA        = [:COMMA,        ','.freeze,   1].freeze
  TOKEN_SEMIC        = [:SEMIC,        ';'.freeze,   1].freeze
  TOKEN_QMARK        = [:QMARK,        '?'.freeze,   1].freeze
  TOKEN_TILDE        = [:TILDE,        '~'.freeze,   1].freeze # lexed but not an operator in Puppet

  TOKEN_REGEXP       = [:REGEXP,       nil,   0].freeze

  TOKEN_IN_EDGE      = [:IN_EDGE,      '->'.freeze,  2].freeze
  TOKEN_IN_EDGE_SUB  = [:IN_EDGE_SUB,  '~>'.freeze,  2].freeze
  TOKEN_OUT_EDGE     = [:OUT_EDGE,     '<-'.freeze,  2].freeze
  TOKEN_OUT_EDGE_SUB = [:OUT_EDGE_SUB, '<~'.freeze,  2].freeze

  # Tokens that are always unique to what has been lexed
  TOKEN_STRING         =  [:STRING, nil,          0].freeze
  TOKEN_WORD           =  [:WORD, nil,            0].freeze
  TOKEN_DQPRE          =  [:DQPRE,  nil,          0].freeze
  TOKEN_DQMID          =  [:DQPRE,  nil,          0].freeze
  TOKEN_DQPOS          =  [:DQPRE,  nil,          0].freeze
  TOKEN_NUMBER         =  [:NUMBER, nil,          0].freeze
  TOKEN_VARIABLE       =  [:VARIABLE, nil,        1].freeze
  TOKEN_VARIABLE_EMPTY =  [:VARIABLE, ''.freeze,  1].freeze

  # HEREDOC has syntax as an argument.
  TOKEN_HEREDOC        =  [:HEREDOC, nil, 0].freeze

  # EPP_START is currently a marker token, may later get syntax
  TOKEN_EPPSTART       =  [:EPP_START, nil, 0].freeze
  TOKEN_EPPEND         =  [:EPP_END, '%>', 2].freeze
  TOKEN_EPPEND_TRIM    =  [:EPP_END_TRIM, '-%>', 3].freeze

  # This is used for unrecognized tokens, will always be a single character. This particular instance
  # is not used, but is kept here for documentation purposes.
  TOKEN_OTHER        = [:OTHER,  nil,  0]

  # Keywords are all singleton tokens with pre calculated lengths.
  # Booleans are pre-calculated (rather than evaluating the strings "false" "true" repeatedly.
  #
  KEYWORDS = {
    'case'     => [:CASE,     'case',     4],
    'class'    => [:CLASS,    'class',    5],
    'default'  => [:DEFAULT,  'default',  7],
    'define'   => [:DEFINE,   'define',   6],
    'if'       => [:IF,       'if',       2],
    'elsif'    => [:ELSIF,    'elsif',    5],
    'else'     => [:ELSE,     'else',     4],
    'inherits' => [:INHERITS, 'inherits', 8],
    'node'     => [:NODE,     'node',     4],
    'and'      => [:AND,      'and',      3],
    'or'       => [:OR,       'or',       2],
    'undef'    => [:UNDEF,    'undef',    5],
    'false'    => [:BOOLEAN,  false,      5],
    'true'     => [:BOOLEAN,  true,       4],
    'in'       => [:IN,       'in',       2],
    'unless'   => [:UNLESS,   'unless',   6],
    'function' => [:FUNCTION, 'function', 8],
    'type'     => [:TYPE,     'type',     4],
    'attr'     => [:ATTR,     'attr',     4],
    'private'  => [:PRIVATE,  'private',  7],
  }

  KEYWORDS.each {|k,v| v[1].freeze; v.freeze }
  KEYWORDS.freeze

  # We maintain two different tables of tokens for the constructs
  # introduced by application management. Which ones we use is decided in
  # +initvars+; by selecting one or the other variant, we select whether we
  # hit the appmgmt-specific code paths
  APP_MANAGEMENT_TOKENS = {
    :with_appm => {
      'application' => [:APPLICATION, 'application',  11],
      'consumes'    => [:CONSUMES,    'consumes',  8],
      'produces'    => [:PRODUCES,    'produces',  8],
      'site'        => [:SITE,        'site',  4]
    },
    :without_appm => {
      'application' => [:APPLICATION_R, 'application',  11],
      'consumes'    => [:CONSUMES_R,    'consumes',  8],
      'produces'    => [:PRODUCES_R,    'produces',  8],
      'site'        => [:SITE_R,        'site',  4]
    }
  }

  APP_MANAGEMENT_TOKENS.each do |_, variant|
    variant.each { |_,v| v[1].freeze; v.freeze }
    variant.freeze
  end
  APP_MANAGEMENT_TOKENS.freeze

  # Reverse lookup of keyword name to string
  KEYWORD_NAMES = {}
  KEYWORDS.each {|k, v| KEYWORD_NAMES[v[0]] = k }
  APP_MANAGEMENT_TOKENS.each do |_, variant|
    variant.each { |k,v| KEYWORD_NAMES[v[0]] = k }
  end
  KEYWORD_NAMES.freeze

  PATTERN_WS        = %r{[[:blank:]\r]+}
  PATTERN_NON_WS    = %r{\w+\b?}

  # The single line comment includes the line ending.
  PATTERN_COMMENT   = %r{#.*\r?}
  PATTERN_MLCOMMENT = %r{/\*(.*?)\*/}m

  PATTERN_REGEX     = %r{/[^/\n]*/}
  PATTERN_REGEX_END = %r{/}
  PATTERN_REGEX_A   = %r{\A/} # for replacement to ""
  PATTERN_REGEX_Z   = %r{/\Z} # for replacement to ""
  PATTERN_REGEX_ESC = %r{\\/} # for replacement to "/"

  # The 3x patterns:
  # PATTERN_CLASSREF       = %r{((::){0,1}[A-Z][-\w]*)+}
  # PATTERN_NAME           = %r{((::)?[a-z0-9][-\w]*)(::[a-z0-9][-\w]*)*}

  # The NAME and CLASSREF in 4x are strict. Each segment must start with
  # a letter a-z and may not contain dashes (\w includes letters, digits and _).
  #
  PATTERN_CLASSREF       = %r{((::){0,1}[A-Z][\w]*)+}
  PATTERN_NAME           = %r{^((::)?[a-z][\w]*)(::[a-z][\w]*)*$}

  PATTERN_BARE_WORD     = %r{((?:::){0,1}(?:[a-z_](?:[\w-]*[\w])?))+}

  PATTERN_DOLLAR_VAR     = %r{\$(::)?(\w+::)*\w+}
  PATTERN_NUMBER         = %r{\b(?:0[xX][0-9A-Fa-f]+|0?\d+(?:\.\d+)?(?:[eE]-?\d+)?)\b}

  # PERFORMANCE NOTE:
  # Comparison against a frozen string is faster (than unfrozen).
  #
  STRING_BSLASH_BSLASH = '\\'.freeze

  attr_reader :locator

  def initialize()
    @selector = {
      '.' =>  lambda { emit(TOKEN_DOT, @scanner.pos) },
      ',' => lambda {  emit(TOKEN_COMMA, @scanner.pos) },
      '[' => lambda do
        before = @scanner.pos
        if (before == 0 || @scanner.string[locator.char_offset(before)-1,1] =~ /[[:blank:]\r\n]+/)
          emit(TOKEN_LISTSTART, before)
        else
          emit(TOKEN_LBRACK, before)
        end
      end,
      ']' => lambda { emit(TOKEN_RBRACK, @scanner.pos) },
      '(' => lambda do
        before = @scanner.pos
        pos_on_line = locator.pos_on_line(before)
        # If first on a line, or only whitespace between start of line and '('
        # then the token is special to avoid being taken as start of a call.
        if pos_on_line == 1 || @scanner.string[locator.char_offset(before)-pos_on_line+1, pos_on_line-1] =~ /\A[[:blank:]\r\n]+\Z/
          emit(TOKEN_WSLPAREN, before)
        else
          emit(TOKEN_LPAREN, before)
        end
      end,
      ')' => lambda { emit(TOKEN_RPAREN, @scanner.pos) },
      ';' => lambda { emit(TOKEN_SEMIC, @scanner.pos) },
      '?' => lambda { emit(TOKEN_QMARK, @scanner.pos) },
      '*' => lambda { emit(TOKEN_TIMES, @scanner.pos) },
      '%' => lambda do
        scn = @scanner
        before = scn.pos
        la = scn.peek(2)
        if la[1] == '>' && @lexing_context[:epp_mode]
          scn.pos += 2
          if @lexing_context[:epp_mode] == :expr
            enqueue_completed(TOKEN_EPPEND, before)
          end
          @lexing_context[:epp_mode] = :text
          interpolate_epp
        else
          emit(TOKEN_MODULO, before)
        end
      end,
      '{' => lambda do
        # The lexer needs to help the parser since the technology used cannot deal with
        # lookahead of same token with different precedence. This is solved by making left brace
        # after ? into a separate token.
        #
        @lexing_context[:brace_count] += 1
        emit(if @lexing_context[:after] == :QMARK
               TOKEN_SELBRACE
             else
               TOKEN_LBRACE
             end, @scanner.pos)
      end,
      '}' => lambda do
        @lexing_context[:brace_count] -= 1
        emit(TOKEN_RBRACE, @scanner.pos)
      end,


      # TOKENS @, @@, @(
      '@' => lambda do
        scn = @scanner
        la = scn.peek(2)
        if la[1] == '@'
          emit(TOKEN_ATAT, scn.pos) # TODO; Check if this is good for the grammar
        elsif la[1] == '('
          heredoc
        else
          emit(TOKEN_AT, scn.pos)
        end
      end,

      # TOKENS |, |>, |>>
      '|' => lambda do
        scn = @scanner
        la = scn.peek(3)
        emit(la[1] == '>' ? (la[2] == '>' ? TOKEN_RRCOLLECT : TOKEN_RCOLLECT) : TOKEN_PIPE, scn.pos)
      end,

      # TOKENS =, =>, ==, =~
      '=' => lambda do
        scn = @scanner
        la = scn.peek(2)
        emit(case la[1]
             when '='
               TOKEN_ISEQUAL
             when '>'
               TOKEN_FARROW
             when '~'
               TOKEN_MATCH
             else
               TOKEN_EQUALS
             end, scn.pos)
      end,

      # TOKENS '+', '+=', and '+>'
      '+' => lambda do
        scn = @scanner
        la = scn.peek(2)
        emit(case la[1]
             when '='
               TOKEN_APPENDS
             when '>'
               TOKEN_PARROW
             else
               TOKEN_PLUS
             end, scn.pos)
      end,

      # TOKENS '-', '->', and epp '-%>' (end of interpolation with trim)
      '-' => lambda do
        scn = @scanner
        la = scn.peek(3)
        before = scn.pos
        if @lexing_context[:epp_mode] && la[1] == '%' && la[2] == '>'
          scn.pos += 3
          if @lexing_context[:epp_mode] == :expr
            enqueue_completed(TOKEN_EPPEND_TRIM, before)
          end
          interpolate_epp(:with_trim)
        else
          emit(case la[1]
               when '>'
                 TOKEN_IN_EDGE
               when '='
                 TOKEN_DELETES
               else
                 TOKEN_MINUS
               end, before)
        end
      end,

      # TOKENS !, !=, !~
      '!' => lambda do
        scn = @scanner
        la = scn.peek(2)
        emit(case la[1]
             when '='
               TOKEN_NOTEQUAL
             when '~'
               TOKEN_NOMATCH
             else
               TOKEN_NOT
             end, scn.pos)
      end,

      # TOKENS ~>, ~
      '~' => lambda do
        scn = @scanner
        la = scn.peek(2)
        emit(la[1] == '>' ? TOKEN_IN_EDGE_SUB : TOKEN_TILDE, scn.pos)
      end,

      '#' => lambda { @scanner.skip(PATTERN_COMMENT); nil },

      # TOKENS '/', '/*' and '/ regexp /'
      '/' => lambda do
        scn = @scanner
        la = scn.peek(2)
        if la[1] == '*'
          lex_error(Issues::UNCLOSED_MLCOMMENT) if scn.skip(PATTERN_MLCOMMENT).nil?
          nil
        else
          before = scn.pos
          # regexp position is a regexp, else a div
          if regexp_acceptable? && value = scn.scan(PATTERN_REGEX)
            # Ensure an escaped / was not matched
            while value[-2..-2] == STRING_BSLASH_BSLASH # i.e. \\
              value += scn.scan_until(PATTERN_REGEX_END)
            end
            regex = value.sub(PATTERN_REGEX_A, '').sub(PATTERN_REGEX_Z, '').gsub(PATTERN_REGEX_ESC, '/')
            emit_completed([:REGEX, Regexp.new(regex), scn.pos-before], before)
          else
            emit(TOKEN_DIV, before)
          end
        end
      end,

      # TOKENS <, <=, <|, <<|, <<, <-, <~
      '<' => lambda do
        scn = @scanner
        la = scn.peek(3)
        emit(case la[1]
             when '<'
               if la[2] == '|'
                 TOKEN_LLCOLLECT
               else
                 TOKEN_LSHIFT
               end
             when '='
               TOKEN_LESSEQUAL
             when '|'
               TOKEN_LCOLLECT
             when '-'
               TOKEN_OUT_EDGE
             when '~'
               TOKEN_OUT_EDGE_SUB
             else
               TOKEN_LESSTHAN
             end, scn.pos)
      end,

      # TOKENS >, >=, >>
      '>' => lambda do
        scn = @scanner
        la = scn.peek(2)
        emit(case la[1]
             when '>'
               TOKEN_RSHIFT
             when '='
               TOKEN_GREATEREQUAL
             else
               TOKEN_GREATERTHAN
             end, scn.pos)
      end,

      # TOKENS :, ::CLASSREF, ::NAME
      ':' => lambda do
        scn = @scanner
        la = scn.peek(3)
        before = scn.pos
        if la[1] == ':'
          # PERFORMANCE NOTE: This could potentially be speeded up by using a case/when listing all
          # upper case letters. Alternatively, the 'A', and 'Z' comparisons may be faster if they are
          # frozen.
          #
          la2 = la[2]
          if la2 >= 'A' && la2 <= 'Z'
            # CLASSREF or error
            value = scn.scan(PATTERN_CLASSREF)
            if value && scn.peek(2) != '::'
              after = scn.pos
              emit_completed([:CLASSREF, value.freeze, after-before], before)
            else
              # move to faulty position ('::<uc-letter>' was ok)
              scn.pos = scn.pos + 3
              lex_error(Issues::ILLEGAL_FULLY_QUALIFIED_CLASS_REFERENCE)
            end
          else
            value = scn.scan(PATTERN_BARE_WORD)
            if value
              if value =~ PATTERN_NAME
                emit_completed([:NAME, value.freeze, scn.pos - before], before)
              else
                emit_completed([:WORD, value.freeze, scn.pos - before], before)
              end
            else
              # move to faulty position ('::' was ok)
              scn.pos = scn.pos + 2
              lex_error(Issues::ILLEGAL_FULLY_QUALIFIED_NAME)
            end
          end
        else
          emit(TOKEN_COLON, before)
        end
      end,

      '$' => lambda do
        scn = @scanner
        before = scn.pos
        if value = scn.scan(PATTERN_DOLLAR_VAR)
          emit_completed([:VARIABLE, value[1..-1].freeze, scn.pos - before], before)
        else
          # consume the $ and let higher layer complain about the error instead of getting a syntax error
          emit(TOKEN_VARIABLE_EMPTY, before)
        end
      end,

      '"' => lambda do
        # Recursive string interpolation, 'interpolate' either returns a STRING token, or
        # a DQPRE with the rest of the string's tokens placed in the @token_queue
        interpolate_dq
      end,

      "'" => lambda do
        scn = @scanner
        before = scn.pos
        emit_completed([:STRING, slurp_sqstring.freeze, scn.pos - before], before)
      end,

      "\n" => lambda do
        # If heredoc_cont is in effect there are heredoc text lines to skip over
        # otherwise just skip the newline.
        #
        ctx = @lexing_context
        if ctx[:newline_jump]
          @scanner.pos = ctx[:newline_jump]
          ctx[:newline_jump] = nil
        else
          @scanner.pos += 1
        end
        nil
      end,
      '' => lambda { nil } # when the peek(1) returns empty
    }

    [ ' ', "\t", "\r" ].each { |c| @selector[c] = lambda { @scanner.skip(PATTERN_WS); nil } }

    [ '0', '1', '2', '3', '4', '5', '6', '7', '8', '9'].each do |c|
      @selector[c] = lambda do
        scn = @scanner
        before = scn.pos
        value = scn.scan(PATTERN_NUMBER)
        if value
          length = scn.pos - before
          assert_numeric(value, before)
          emit_completed([:NUMBER, value.freeze, length], before)
        else
          invalid_number = scn.scan_until(PATTERN_NON_WS)
          if before > 1
            after = scn.pos
            scn.pos = before - 1
            if scn.peek(1) == '.'
              # preceded by a dot. Is this a bad decimal number then?
              scn.pos = before - 2
              while scn.peek(1) =~ /^\d$/
                invalid_number = nil
                before = scn.pos
                break if before == 0
                scn.pos = scn.pos - 1
              end
            end
            scn.pos = before
            invalid_number = scn.peek(after - before) unless invalid_number
          end
          length = scn.pos - before
          assert_numeric(invalid_number, before)
          scn.pos = before + 1
          lex_error(Issues::ILLEGAL_NUMBER, {:value => invalid_number})
        end
      end
    end
    ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm',
      'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', '_'].each do |c|
      @selector[c] = lambda do

        scn = @scanner
        before = scn.pos
        value = scn.scan(PATTERN_BARE_WORD)
        if value && value =~ PATTERN_NAME
          emit_completed(KEYWORDS[value] || @appm_keywords[value] || [:NAME, value.freeze, scn.pos - before], before)
        elsif value
          emit_completed([:WORD, value.freeze, scn.pos - before], before)
        else
          # move to faulty position ([a-z_] was ok)
          scn.pos = scn.pos + 1
          fully_qualified = scn.match?(/::/)
          if fully_qualified
            lex_error(Issues::ILLEGAL_FULLY_QUALIFIED_NAME)
          else
            lex_error(Issues::ILLEGAL_NAME_OR_BARE_WORD)
          end
        end
      end
    end

    ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
      'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'].each do |c|
      @selector[c] = lambda do
        scn = @scanner
        before = scn.pos
        value = @scanner.scan(PATTERN_CLASSREF)
        if value && @scanner.peek(2) != '::'
          emit_completed([:CLASSREF, value.freeze, scn.pos - before], before)
        else
          # move to faulty position ([A-Z] was ok)
          scn.pos = scn.pos + 1
          lex_error(Issues::ILLEGAL_CLASS_REFERENCE)
        end
      end
    end

    @selector.default = lambda do
      # In case of unicode spaces of various kinds that are captured by a regexp, but not by the
      # simpler case expression above (not worth handling those special cases with better performance).
      scn = @scanner
      if scn.skip(PATTERN_WS)
        nil
      else
        # "unrecognized char"
        emit([:OTHER, scn.peek(0), 1], scn.pos)
      end
    end
    @selector.each { |k,v| k.freeze }
    @selector.freeze
  end

  # Clears the lexer state (it is not required to call this as it will be garbage collected
  # and the next lex call (lex_string, lex_file) will reset the internal state.
  #
  def clear()
    # not really needed, but if someone wants to ensure garbage is collected as early as possible
    @scanner = nil
    @locator = nil
    @lexing_context = nil
  end

  # Convenience method, and for compatibility with older lexer. Use the lex_string instead which allows
  # passing the path to use without first having to call file= (which reads the file if it exists).
  # (Bad form to use overloading of assignment operator for something that is not really an assignment. Also,
  # overloading of = does not allow passing more than one argument).
  #
  def string=(string)
    lex_string(string, '')
  end

  def lex_string(string, path='')
    initvars
    assert_not_bom(string)
    @scanner = StringScanner.new(string)
    @locator = Locator.locator(string, path)
  end

  # Lexes an unquoted string.
  # @param string [String] the string to lex
  # @param locator [Locator] the locator to use (a default is used if nil is given)
  # @param escapes [Array<String>] array of character strings representing the escape sequences to transform
  # @param interpolate [Boolean] whether interpolation of expressions should be made or not.
  #
  def lex_unquoted_string(string, locator, escapes, interpolate)
    initvars
    assert_not_bom(string)
    @scanner = StringScanner.new(string)
    @locator = locator || Locator.locator(string, '')
    @lexing_context[:escapes] = escapes || UQ_ESCAPES
    @lexing_context[:uq_slurp_pattern] = interpolate ? (escapes.include?('$') ? SLURP_UQ_PATTERN : SLURP_UQNE_PATTERN) : SLURP_ALL_PATTERN
  end

  # Convenience method, and for compatibility with older lexer. Use the lex_file instead.
  # (Bad form to use overloading of assignment operator for something that is not really an assignment).
  #
  def file=(file)
    lex_file(file)
  end

  # TODO: This method should not be used, callers should get the locator since it is most likely required to
  # compute line, position etc given offsets.
  #
  def file
    @locator ? @locator.file : nil
  end

  # Initializes lexing of the content of the given file. An empty string is used if the file does not exist.
  #
  def lex_file(file)
    initvars
    contents = Puppet::FileSystem.exist?(file) ? Puppet::FileSystem.read(file, :encoding => 'utf-8') : ''
    assert_not_bom(contents)
    @scanner = StringScanner.new(contents.freeze)
    @locator = Locator.locator(contents, file)
  end

  def initvars
    @token_queue = []
    # NOTE: additional keys are used; :escapes, :uq_slurp_pattern, :newline_jump, :epp_*
    @lexing_context = {
      :brace_count => 0,
      :after => nil,
    }
    appm_mode = Puppet[:app_management] ? :with_appm : :without_appm
    @appm_keywords = APP_MANAGEMENT_TOKENS[appm_mode]
  end

  # Scans all of the content and returns it in an array
  # Note that the terminating [false, false] token is included in the result.
  #
  def fullscan
    result = []
    scan {|token| result.push(token) }
    result
  end

  # A block must be passed to scan. It will be called with two arguments, a symbol for the token,
  # and an instance of LexerSupport::TokenValue
  # PERFORMANCE NOTE: The TokenValue is designed to reduce the amount of garbage / temporary data
  # and to only convert the lexer's internal tokens on demand. It is slightly more costly to create an
  # instance of a class defined in Ruby than an Array or Hash, but the gain is much bigger since transformation
  # logic is avoided for many of its members (most are never used (e.g. line/pos information which is only of
  # value in general for error messages, and for some expressions (which the lexer does not know about).
  #
  def scan
    # PERFORMANCE note: it is faster to access local variables than instance variables.
    # This makes a small but notable difference since instance member access is avoided for
    # every token in the lexed content.
    #
    scn   = @scanner
    lex_error_without_pos(Issues::NO_INPUT_TO_LEXER) unless scn

    ctx   = @lexing_context
    queue = @token_queue
    selector = @selector

    scn.skip(PATTERN_WS)

    # This is the lexer's main loop
    until queue.empty? && scn.eos? do
      if token = queue.shift || selector[scn.peek(1)].call
        ctx[:after] = token[0]
        yield token
      end
    end

    # Signals end of input
    yield [false, false]
  end

  # This lexes one token at the current position of the scanner.
  # PERFORMANCE NOTE: Any change to this logic should be performance measured.
  #
  def lex_token
    @selector[@scanner.peek(1)].call
  end

  # Emits (produces) a token [:tokensymbol, TokenValue] and moves the scanner's position past the token
  #
  def emit(token, byte_offset)
    @scanner.pos = byte_offset + token[2]
    [token[0], TokenValue.new(token, byte_offset, @locator)]
  end

  # Emits the completed token on the form [:tokensymbol, TokenValue. This method does not alter
  # the scanner's position.
  #
  def emit_completed(token, byte_offset)
    [token[0], TokenValue.new(token, byte_offset, @locator)]
  end

  # Enqueues a completed token at the given offset
  def enqueue_completed(token, byte_offset)
    @token_queue << emit_completed(token, byte_offset)
  end

  # Allows subprocessors for heredoc etc to enqueue tokens that are tokenized by a different lexer instance
  #
  def enqueue(emitted_token)
    @token_queue << emitted_token
  end

  # Answers after which tokens it is acceptable to lex a regular expression.
  # PERFORMANCE NOTE:
  # It may be beneficial to turn this into a hash with default value of true for missing entries.
  # A case expression with literal values will however create a hash internally. Since a reference is
  # always needed to the hash, this access is almost as costly as a method call.
  #
  def regexp_acceptable?
    case @lexing_context[:after]

    # Ends of (potential) R-value generating expressions
    when :RPAREN, :RBRACK, :RRCOLLECT, :RCOLLECT
      false

    # End of (potential) R-value - but must be allowed because of case expressions
    # Called out here to not be mistaken for a bug.
    when :RBRACE
      true

    # Operands (that can be followed by DIV (even if illegal in grammar)
    when :NAME, :CLASSREF, :NUMBER, :STRING, :BOOLEAN, :DQPRE, :DQMID, :DQPOST, :HEREDOC, :REGEX, :VARIABLE, :WORD
      false

    else
      true
    end
  end

end
end
end
