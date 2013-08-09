# the scanner/lexer

require 'forwardable'
require 'strscan'
require 'puppet'
require 'puppet/util/methodhelper'

module Puppet
  class LexError < RuntimeError; end
end

class Puppet::Pops::Parser::Lexer
  extend Forwardable

  attr_reader :file, :lexing_context, :token_queue

  attr_reader :locator

  attr_accessor :indefine
  alias :indefine? :indefine

  # One of the modes :pp, :string, or :epp
  attr_accessor :mode

  def lex_error msg
    raise Puppet::LexError.new(msg)
  end

  class Token
    ALWAYS_ACCEPTABLE = Proc.new { |context| true }

    include Puppet::Util::MethodHelper

    attr_accessor :regex, :name, :string, :skip, :skip_text
    alias skip? skip

    # @overload initialize(string)
    #   @param string [String] a literal string token matcher
    #   @param name [String] the token name (what it is known as in the grammar)
    #   @param options [Hash] see {#set_options}
    # @overload initialize(regex)
    #   @param regex [Regexp] a regular expression token text matcher
    #   @param name [String] the token name (what it is known as in the grammar)
    #   @param options [Hash] see {#set_options}
    #
    def initialize(string_or_regex, name, options = {})
      if string_or_regex.is_a?(String)
        @name, @string = name, string_or_regex
        @regex = Regexp.new(Regexp.escape(string_or_regex))
      else
        @name, @regex = name, string_or_regex
      end

      set_options(options)
      @acceptable_when = ALWAYS_ACCEPTABLE
    end

    # @return [String] human readable token reference; the String if literal, else the token name
    def to_s
      string or @name.to_s
    end

    # @return [Boolean] if the token is acceptable in the given context or not.
    #   this implementation always returns true.
    # @param context [Hash] ? ? ?
    #
    def acceptable?(context={})
      @acceptable_when.call(context)
    end


    # Defines when the token is able to match.
    # This provides context that cannot be expressed otherwise, such as feature flags.
    #
    # @param block [Proc] a proc that given a context returns a boolean
    def acceptable_when(block)
      @acceptable_when = block
    end
  end

  # Maintains a list of tokens.
  class TokenList
    extend Forwardable

    attr_reader :regex_tokens, :string_tokens
    def_delegator :@tokens, :[]
    # Adds a new token to the set of recognized tokens
    # @param name [String] the token name
    # @param regex [Regexp, String] source text token matcher, a litral string or regular expression
    # @param options [Hash] see {Token::set_options}
    # @param block [Proc] optional block set as the created tokens `convert` method
    # @raise [ArgumentError] if the token with the given name is already defined
    #
    def add_token(name, regex, options = {}, &block)
      raise(ArgumentError, "Token #{name} already exists") if @tokens.include?(name)
      token = Token.new(regex, name, options)
      @tokens[token.name] = token
      if token.string
        @string_tokens << token
        @tokens_by_string[token.string] = token
      else
        @regex_tokens << token
      end

      token.meta_def(:convert, &block) if block_given?

      token
    end

    # Creates an empty token list
    #
    def initialize
      @tokens = {}
      @regex_tokens = []
      @string_tokens = []
      @tokens_by_string = {}
    end

    # Look up a token by its literal (match) value, rather than name.
    # @param string [String, nil] the literal match string to obtain a {Token} for, or nil if it does not exist.
    def lookup(string)
      @tokens_by_string[string]
    end

    # Adds tokens from a hash where key is a matcher (literal string or regexp) and the
    # value is the token's name
    # @param hash [Hash<{String => Symbol}, Hash<{Regexp => Symbol}] map token text matcher to token name
    # @return [void]
    #
    def add_tokens(hash)
      hash.each do |regex, name|
        add_token(name, regex)
      end
    end

    # Sort literal (string-) tokens by length, so we know once we match, we're done.
    # This helps avoid the O(n^2) nature of token matching.
    # The tokens are sorted in place.
    # @return [void]
    def sort_tokens
      @string_tokens.sort! { |a, b| b.string.length <=> a.string.length }
    end

    # Yield each token name and value in turn.
    def each
      @tokens.each {|name, value| yield name, value }
    end
  end

  TOKENS = TokenList.new
  TOKENS.add_tokens(
  '['   => :LBRACK,
  ']'   => :RBRACK,
  #    '{'   => :LBRACE, # Specialized to handle lambda
  '}'   => :RBRACE,
  '('   => :LPAREN,
  ')'   => :RPAREN,
  '='   => :EQUALS,
  '+='  => :APPENDS,
  '=='  => :ISEQUAL,
  '>='  => :GREATEREQUAL,
  '>'   => :GREATERTHAN,
  '<'   => :LESSTHAN,
  '<='  => :LESSEQUAL,
  '!='  => :NOTEQUAL,
  '!'   => :NOT,
  ','   => :COMMA,
  '.'   => :DOT,
  ':'   => :COLON,
  '@'   => :AT,
  '|'   => :PIPE,
  '<<|' => :LLCOLLECT,
  '|>>' => :RRCOLLECT,
  '->'  => :IN_EDGE,
  '<-'  => :OUT_EDGE,
  '~>'  => :IN_EDGE_SUB,
  '<~'  => :OUT_EDGE_SUB,
  '<|'  => :LCOLLECT,
  '|>'  => :RCOLLECT,
  ';'   => :SEMIC,
  '?'   => :QMARK,
  '\\'  => :BACKSLASH,
  '=>'  => :FARROW,
  '+>'  => :PARROW,
  '+'   => :PLUS,
  '-'   => :MINUS,
  '/'   => :DIV,
  '*'   => :TIMES,
  '%'   => :MODULO,
  '<<'  => :LSHIFT,
  '>>'  => :RSHIFT,
  '=~'  => :MATCH,
  '!~'  => :NOMATCH,
  %r{((::){0,1}[A-Z][-\w]*)+} => :CLASSREF,
  "<string>" => :STRING,
  "<dqstring up to first interpolation>" => :DQPRE,
  "<dqstring between two interpolations>" => :DQMID,
  "<dqstring after final interpolation>" => :DQPOST,
  "<boolean>" => :BOOLEAN,
  "<lambda start>" => :LAMBDA, # A LBRACE followed by '|'
  "<select start>" => :SELBRACE # A QMARK followed by '{'
  )

  module Contextual
    QUOTE_TOKENS = [:DQPRE,:DQMID]
    REGEX_INTRODUCING_TOKENS = [:NODE,:LBRACE, :SELBRACE, :RBRACE,:MATCH,:NOMATCH,:COMMA]

    NOT_INSIDE_QUOTES = Proc.new do |context|
      !QUOTE_TOKENS.include? context[:after]
    end

    INSIDE_QUOTES = Proc.new do |context|
      QUOTE_TOKENS.include? context[:after]
    end

    IN_REGEX_POSITION = Proc.new do |context|
      REGEX_INTRODUCING_TOKENS.include? context[:after]
    end

    IN_STRING_INTERPOLATION = Proc.new do |context|
      context[:string_interpolation_depth] > 0
    end

    DASHED_VARIABLES_ALLOWED = Proc.new do |context|
      Puppet[:allow_variables_with_dashes]
    end

    VARIABLE_AND_DASHES_ALLOWED = Proc.new do |context|
      Contextual::DASHED_VARIABLES_ALLOWED.call(context) and TOKENS[:VARIABLE].acceptable?(context)
    end

    NEVER = Proc.new do |context|
      false
    end
  end

  TOKENS.add_token :HEREDOC, /@\(/ do |lexer, value|
    lexer.heredoc
    lexer.shift_token
  end

  # LBRACE needs look ahead to differentiate between '{' and a '{'
  # followed by a '|' (start of lambda) The racc grammar can only do one
  # token lookahead.
  #
  TOKENS.add_token :LBRACE, /\{/ do | lexer, value |
    if lexer.match?(/[ \t\r]*\|/)
      [TOKENS[:LAMBDA], value]
    elsif lexer.lexing_context[:after] == :QMARK
      [TOKENS[:SELBRACE], value]
    else
      [TOKENS[:LBRACE], value]
    end
  end

  # Numbers are treated separately from names, so that they may contain dots.
  TOKENS.add_token :NUMBER, %r{\b(?:0[xX][0-9A-Fa-f]+|0?\d+(?:\.\d+)?(?:[eE]-?\d+)?)\b} do |lexer, value|
    lexer.assert_numeric(value)
    [TOKENS[:NAME], value]
  end
  TOKENS[:NUMBER].acceptable_when Contextual::NOT_INSIDE_QUOTES

  TOKENS.add_token :NAME, %r{((::)?[a-z0-9][-\w]*)(::[a-z0-9][-\w]*)*} do |lexer, value|
    # A name starting with a number must be a valid numeric string (not that
    # NUMBER token captures those names that do not comply with the name rule.
    if value =~ /^[0-9].*$/
      lexer.assert_numeric(value)
    end

    string_token = self
    # we're looking for keywords here
    if tmp = KEYWORDS.lookup(value)
      string_token = tmp
      if [:TRUE, :FALSE].include?(string_token.name)
        value = eval(value)
        string_token = TOKENS[:BOOLEAN]
      end
    end
    [string_token, value]
  end
  [:NAME, :CLASSREF].each do |name_token|
    TOKENS[name_token].acceptable_when Contextual::NOT_INSIDE_QUOTES
  end

  TOKENS.add_token :COMMENT, %r{#.*}, :skip => true do |lexer,value|
    value.sub!(/# ?/,'')
    [self, value]
  end

  TOKENS.add_token :MLCOMMENT, %r{/\*(.*?)\*/}m, :skip => true do |lexer, value|
    value.sub!(/^\/\* ?/,'')
    value.sub!(/ ?\*\/$/,'')
    [self,value]
  end

  TOKENS.add_token :REGEX, %r{/[^/\n]*/} do |lexer, value|
    # Make sure we haven't matched an escaped /
    while value[-2..-2] == '\\'
      other = lexer.scan_until(%r{/})
      value += other
    end
    regex = value.sub(%r{\A/}, "").sub(%r{/\Z}, '').gsub("\\/", "/")
    [self, Regexp.new(regex)]
  end
  TOKENS[:REGEX].acceptable_when Contextual::IN_REGEX_POSITION

  TOKENS.add_token :RETURN, "\n", :skip => true, :skip_text => true

  TOKENS.add_token :SQUOTE, "'" do |lexer, value|
    [TOKENS[:STRING], lexer.slurp_sqstring()]
  end

  # Different interpolation rules are needed for Double- (DQ), and Un-quoted (UQ) strings

  DQ_initial_token_types      = {'$' => :DQPRE,'"' => :STRING}
  DQ_continuation_token_types = {'$' => :DQMID,'"' => :DQPOST}
  UQ_initial_token_types      = {'$' => :DQPRE,'' => :STRING}
  UQ_continuation_token_types = {'$' => :DQMID,'' => :DQPOST}

  TOKENS.add_token :DQUOTE, /"/ do |lexer, value|
    lexer.tokenize_interpolated_string(DQ_initial_token_types)
  end

  # This token is used "automatically" when mode is :dqstring (lexing content
  # that is a dq string but that is not surrounded by double quotes). See #find_token
  # and #auto_token.
  #
  TOKENS.add_token :AUTO_DQUOTE, "<auto double quote>" do |lexer, value|
    lexer.tokenize_interpolated_string(UQ_initial_token_types)
  end
  TOKENS[:AUTO_DQUOTE].acceptable_when Contextual::NEVER

  TOKENS.add_token :DQCONT, /\}/ do |lexer, value|
    lexer.tokenize_interpolated_string(lexer.continuation_types())
  end
  TOKENS[:DQCONT].acceptable_when Contextual::IN_STRING_INTERPOLATION

  TOKENS.add_token :DOLLAR_VAR_WITH_DASH, %r{\$(?:::)?(?:[-\w]+::)*[-\w]+} do |lexer, value|
    lexer.warn_if_variable_has_hyphen(value)

    [TOKENS[:VARIABLE], value[1..-1]]
  end
  TOKENS[:DOLLAR_VAR_WITH_DASH].acceptable_when Contextual::DASHED_VARIABLES_ALLOWED

  TOKENS.add_token :DOLLAR_VAR, %r{\$(::)?(\w+::)*\w+} do |lexer, value|
    [TOKENS[:VARIABLE],value[1..-1]]
  end

  TOKENS.add_token :VARIABLE_WITH_DASH, %r{(?:::)?(?:[-\w]+::)*[-\w]+} do |lexer, value|
    lexer.warn_if_variable_has_hyphen(value)
    # If the varname (following $, or ${ is followed by (, it is a function call, and not a variable
    # reference.
    #
    if lexer.match?(%r{[ \t\r]*\(})
      [TOKENS[:NAME],value]
    else
      [TOKENS[:VARIABLE], value]
    end
  end
  TOKENS[:VARIABLE_WITH_DASH].acceptable_when Contextual::VARIABLE_AND_DASHES_ALLOWED

  TOKENS.add_token :VARIABLE, %r{(::)?(\w+::)*\w+} do |lexer, value|
    # If the varname (following $, or ${ is followed by (, it is a function call, and not a variable
    # reference.
    #
    if lexer.match?(%r{[ \t\r]*\(})
      [TOKENS[:NAME],value]
    else
      [TOKENS[:VARIABLE],value]
    end

  end
  TOKENS[:VARIABLE].acceptable_when Contextual::INSIDE_QUOTES

  TOKENS.sort_tokens

  @@pairs = {
    "{"   => "}",
    "("   => ")",
    "["   => "]",
    "<|"  => "|>",
    "<<|" => "|>>",
    "|"   => "|"
  }

  KEYWORDS = TokenList.new
  KEYWORDS.add_tokens(
  "case"     => :CASE,
  "class"    => :CLASS,
  "default"  => :DEFAULT,
  "define"   => :DEFINE,
  #    "import"   => :IMPORT,
  "if"       => :IF,
  "elsif"    => :ELSIF,
  "else"     => :ELSE,
  "inherits" => :INHERITS,
  "node"     => :NODE,
  "and"      => :AND,
  "or"       => :OR,
  "undef"    => :UNDEF,
  "false"    => :FALSE,
  "true"     => :TRUE,
  "in"       => :IN,
  "unless"   => :UNLESS
  )

  def clear
    initvars
  end

  def expected
    return nil if @expected.empty?
    name = @expected[-1]
    TOKENS.lookup(name) or lex_error "Internal Lexer Error: Could not find expected token #{name}"
  end

  # Scans the entire contents and returns it as an array.
  # This is used when lexer is used as a sublexer in heredoc processing with dq string semantics
  # and for testing the lexer.
  #
  def fullscan
    array = []

    self.scan { |token, str|
      # Ignore any definition nesting problems
      @indefine = false
      array.push([token,str])
    }
    array
  end

  def file=(file)
    @file = file
    contents = File.exists?(file) ? File.read(file) : ""
    @scanner = StringScanner.new(contents)
    @locator = Locator.new(contents, multibyte?)
  end

  def_delegator :@token_queue, :shift, :shift_token

  def find_string_token
    # We know our longest string token is three chars, so try each size in turn
    # until we either match or run out of chars.  This way our worst-case is three
    # tries, where it is otherwise the number of string token we have.  Also,
    # the lookups are optimized hash lookups, instead of regex scans.
    #
    s = @scanner.peek(3)
    token = TOKENS.lookup(s[0,3]) || TOKENS.lookup(s[0,2]) || TOKENS.lookup(s[0,1])
    [ token, token && @scanner.scan(token.regex) ]
  end

  # Find the next token that matches a regex.  We look for these first.
  def find_regex_token
    best_token = nil
    best_length = 0

    # I tried optimizing based on the first char, but it had
    # a slightly negative affect and was a good bit more complicated.
    TOKENS.regex_tokens.each do |token|
      if length = @scanner.match?(token.regex) and token.acceptable?(lexing_context)
        # We've found a longer match
        if length > best_length
          best_length = length
          best_token = token
        end
      end
    end

    return best_token, @scanner.scan(best_token.regex) if best_token
  end

  # Produces an automatic implicit token at the start of lexing if a mode requires this.
  # This is used when a lexer is used as a sublexer and is given the content of a double quoted string
  # without the delimiting double quotes.
  #
  def auto_token
    if mode == :dqstring && @scanner.pos == 0
      [TOKENS[:AUTO_DQUOTE], '']
    else
      nil
    end
  end

  # Find the next token, returning the string and the token.
  def find_token
    auto_token || shift_token || find_regex_token || find_string_token
  end

  # Sets the lexer's mode to one of :pp (the default), :dqstring (for unquoted dq string lexing), or :epp (for
  # embedded puppet template).
  # @returns [Puppet::Pops::Impl::Parser::Lexer] self
  #
  def mode=(lexer_mode)
    unless [:pp, :dqstring, :epp].include?(lexer_mode)
      raise Puppet::DevError.new("Illegal lexer mode: '#{lexer_mode}', must be one of :pp, :dqstring or :epp.")
    end
    @mode = lexer_mode
    self
  end

  def initialize(options={})
    @multibyte = init_multibyte
    @options = options
    self.mode = (options[:mode] or :pp)
    initvars
  end

  def assert_numeric(value)
    if value =~ /^0[xX].*$/
      lex_error (positioned_message("Not a valid hex number #{value}")) unless value =~ /^0[xX][0-9A-Fa-f]+$/
    elsif value =~ /^0[^.].*$/
      lex_error(positioned_message("Not a valid octal number #{value}")) unless value =~ /^0[0-7]+$/
    else
      lex_error(positioned_message("Not a valid decimal number #{value}")) unless value =~ /0?\d+(?:\.\d+)?(?:[eE]-?\d+)?/
    end
  end

  # Returns true if ruby version >= 1.9.3 since regexp supports multi-byte matches and expanded
  # character categories like [[:blank:]].
  #
  # This implementation will fail if there are more than 255 minor or micro versions of ruby
  #
  def init_multibyte
    numver = RUBY_VERSION.split(".").collect {|s| s.to_i }
    return true if (numver[0] << 16 | numver[1] << 8 | numver[2]) >= (1 << 16 | 9 << 8 | 3)
    false
  end

  def multibyte?
    @multibyte
  end

  def initvars
    @previous_token = nil
    @scanner = nil
    @file = nil

    # AAARRGGGG! okay, regexes in ruby are bloody annoying
    # no one else has "\n" =~ /\s/

    if multibyte?
      # Skip all kinds of space, and CR, but not newlines
      @skip  = %r{[[:blank:]\r]+}
      # Regexp string for all blanks (not including CR)
      @blank = '[[:blank:]]'
    else
      @skip  = %r{[ \t\r]+}
      # Regexp string for all blanks (not including CR)
      @blank = '[ \t]'
    end

    @namestack = []
    @token_queue = []
    @indefine = false
    @expected = []
    @lexing_context = {
      :after => nil,
      :start_of_line => true,
      :offset => 0,      # byte offset before where token starts
      :end_offset => 0,  # byte offset after scanned token
      :string_interpolation_depth => 0
    }
  end

  # Make any necessary changes to the token and/or value.
  def munge_token(token, value)
    # A token may already have been munged (converted and positioned)
    #
    return token, value if value.is_a? Hash

    skip if token.skip_text

    return if token.skip

    token, value = token.convert(self, value) if token.respond_to?(:convert)

    return unless token

    return if token.skip

    # If the conversion performed the munging/positioning
    return token, value if value.is_a? Hash

    pos_hash = position_in_source
    pos_hash[:value] = value

    return token, pos_hash
  end

  # Returns a hash with the current position in source based on the current lexing context
  #
  def position_in_source
    pos        = @locator.pos_on_line(lexing_context[:offset])
    offset     = @locator.char_offset(lexing_context[:offset])
    length     = @locator.char_length(lexing_context[:offset], lexing_context[:end_offset])
    start_line = @locator.line_for_offset(lexing_context[:offset])

    return { :line => start_line, :pos => pos, :offset => offset, :length => length}
  end

  def pos
    @locator.pos_on_line(lexing_context[:offset])
  end

  # Handling the namespace stack
  def_delegator :@namestack, :pop, :namepop

  # This value might have :: in it, but we don't care -- it'll be handled
  # normally when joining, and when popping we want to pop this full value,
  # however long the namespace is.
  def_delegator :@namestack, :<<, :namestack

  # Collect the current namespace.
  def namespace
    @namestack.join("::")
  end

  def_delegator :@scanner, :rest

  # this is the heart of the lexer
  def scan
    #Puppet.debug("entering scan")
    lex_error "Internal Error: No string or file given to lexer to process." unless @scanner

    # Skip any insignificant initial whitespace.
    # When doing regular lexing, initial whitespace is always "between tokens" and is insignificant.
    # When mode is :dqstring (when parsing heredoc text with dq string semantics) leading whitespace is significant.
    # Avoiding this skip is essential as it takes place before a specific token rule gets a chance to veto skipping initial whitespace.
    #
    skip unless mode == :dqstring && @scanner.pos == 0

    until token_queue.empty? and @scanner.eos? do
      offset = @scanner.pos
      matched_token, value = find_token
      end_offset = @scanner.pos

      # error out if we didn't match anything at all
      lex_error "Could not match #{@scanner.rest[/^(\S+|\s+|.*)/]}" unless matched_token

      newline = matched_token.name == :RETURN

      # Adjust if the just found newline has trailing heredoc text
      if newline && lexing_context[:heredoc_cont]
        # Adjust, since we reached the newline that has trailing heredoc that needs to be
        # skipped
        offset = end_offset = @scanner.pos = lexing_context[:heredoc_cont]
        offset -= 1
        lexing_context[:heredoc_cont] = nil
      end

      lexing_context[:start_of_line] = newline
      lexing_context[:offset] = offset
      lexing_context[:end_offset] = end_offset

      final_token, token_value = munge_token(matched_token, value)
      # update end position since munging may have moved the end offset
      lexing_context[:end_offset] = @scanner.pos

      unless final_token
        skip
        next
      end

      lexing_context[:after] = final_token.name unless newline
      lexing_context[:string_interpolation_depth] += 1 if final_token.name == :DQPRE
      lexing_context[:string_interpolation_depth] -= 1 if final_token.name == :DQPOST

      value = token_value[:value]

      if match = @@pairs[value] and final_token.name != :DQUOTE and final_token.name != :SQUOTE
        @expected << match
      elsif exp = @expected[-1] and exp == value and final_token.name != :DQUOTE and final_token.name != :SQUOTE
        @expected.pop
      end

      yield [final_token.name, token_value]

      if @previous_token
        namestack(value) if @previous_token.name == :CLASS and value != '{'

        if @previous_token.name == :DEFINE
          if indefine?
            msg = "Cannot nest definition #{value} inside #{@indefine}"
            self.indefine = false
            raise Puppet::ParseError, msg
          end

          @indefine = value
        end
      end
      @previous_token = final_token
      skip
    end
    # Cannot reset @scanner to nil here - it is needed to answer questions about context after
    # completed parsing.
    # Seems meaningless to do this. Everything will be gc anyway.
    #@scanner = nil

    # This indicates that we're done parsing.
    yield [false,false]
  end

  # Skip any skipchars in our remaining string.
  def skip
    @scanner.skip(@skip)
  end

  def match? r
    @scanner.match?(r)
  end

  # Provide some limited access to the scanner, for those
  # tokens that need it.
  def_delegator :@scanner, :scan_until

  # Different slurp and escape patterns are needed for Single- (SQ), Double- (DQ), and Un-quoted (UQ) strings

  SLURP_SQ_PATTERN = /(?:[^\\]|^|[^\\])(?:[\\]{2})*[']/
  SLURP_DQ_PATTERN = /(?:[^\\]|^|[^\\])(?:[\\]{2})*(["$])/
  SLURP_UQ_PATTERN = /(?:[^\\]|^|[^\\])(?:[\\]{2})*([$]|\z)/
  SQ_ESCAPES = %w{ ' }
  DQ_ESCAPES = %w{ \\  $ ' " r n t s }+["\r\n", "\n"]
  UQ_ESCAPES = %w{ \\  $ r n t s }+["\r\n", "\n"]

  # Slurps an sq string from @scanner (after it has seen opening sq). Returns the string with \' processed.
  #
  def slurp_sqstring
    str = slurp(@scanner, SLURP_SQ_PATTERN, SQ_ESCAPES, :ignore_invalid_escapes) || lex_error(positioned_message("Unclosed quote after \"'\" followed by '#{followed_by}'"))
    str[0..-2] # strip closing "'" from result
  end

  def slurp_dqstring
    last = @scanner.matched
    if mode == :dqstring && lexing_context[:string_interpolation_depth] <= 1
      pattern = SLURP_UQ_PATTERN
      escapes = (@options[:escapes] or UQ_ESCAPES)
      ignore = true
    else
      pattern = SLURP_DQ_PATTERN
      escapes = DQ_ESCAPES
      ignore = false
    end
    str = slurp(@scanner, pattern, escapes, ignore) || lex_error(positioned_message("Unclosed quote after #{format_quote(last)} followed by '#{followed_by}'"))

    # Special handling is required here to deal with strings that does not have a terminating character.
    # This happens when the pattern given to slurpstring allows the string to end with \z (end of input) as is the case when
    # lexing a heredoc text.
    # The exceptional case is found by looking at the subgroup 1 of the most recent match made by the scanner (i.e. @scanner[1]).
    # This is the last match made by the slurp method (having called scan_until on the scanner).
    # If there is a terminating character is must be stripped and returned separately.
    #
    if @scanner[1] != ''
      [str [0..-2], str[-1,1]] # strip closing terminating char from result, and return it
    else
      [str , ''] # there was no terminating token
    end
  end

  # Slurps a string from the given scanner until the given pattern and then replaces any escaped
  # characters given by escapes into their control-character equivalent or in case of line breaks, replaces the
  # pattern \r?\n with an empty string.
  # The returned string contains the terminating character. Returns nil if the scanner can not scan until the given
  # pattern.
  #
  def slurp scanner, pattern, escapes, ignore_invalid_escapes
    str = scanner.scan_until(pattern) || return
    str.gsub!(/\\([^\r\n]|(?:\r?\n))/m) {
      ch = $1
      if escapes.include? ch
        case ch
        when 'r'   ; "\r"
        when 'n'   ; "\n"
        when 't'   ; "\t"
        when 's'   ; " "
        when "\n"  ; ''
        when "\r\n"; ''
        else      ch
        end
      else
        Puppet.warning(positioned_message("Unrecognized escape sequence '\\#{ch}'")) unless ignore_invalid_escapes
        "\\#{ch}"
      end
    }
    str
  end

  # Slurps a string from the lexer's scanner with the possibility to define, terminators and escapes.
  # @deprecated use the specialized slurp_sqstring, slurp_dqstring instead.
  # @todo remove this when tests are no longer running against pre "future" parser
  #
  def slurpstring(terminators,escapes=%w{ \\  $ ' " r n t s }+["\n", "\r\n"],ignore_invalid_escapes=false)
    last = @scanner.matched
    pattern = /([^\\]|^|[^\\])([\\]{2})*[#{terminators}]/
    str = slurp(@scanner, pattern, escapes, ignore_invalid_escapes) || lex_error(positioned_message("Unclosed quote after #{format_quote(last)} followed by '#{followed_by}'"))
    [str[0..-2], str[-1,1]]
  end

  # Formats given message by appending file, line and position if available.
  def positioned_message msg
    result = [msg]
    result << "in file #{file}" if file
    result << "at line #{line}:#{pos}" if line
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

  def format_quote q
    if q == "'"
      '"\'"'
    else
      "'#{q}'"
    end
  end

  def tokenize_interpolated_string(token_type,preamble='')
    # Expecting a (possibly empty) stretch of text terminated by end of string ", a variable $, or expression ${
    # The length of this part includes the start and terminating characters.
    value,terminator = slurp_dqstring()

    # Advanced after '{' if this is in expression ${} interpolation
    braced = terminator == '$' && @scanner.scan(/\{/)
    # make offset to end_ofset be the length of the pre expression string including its start and terminating chars
    lexing_context[:end_offset] = @scanner.pos

    token_queue << [TOKENS[token_type[terminator]],position_in_source().merge!({:value => preamble+value})]
    variable_regex = if Puppet[:allow_variables_with_dashes]
      TOKENS[:VARIABLE_WITH_DASH].regex
    else
      TOKENS[:VARIABLE].regex
    end
    if terminator != '$' or braced
      return token_queue.shift
    end

    tmp_offset = @scanner.pos
    if var_name = @scanner.scan(variable_regex)
      lexing_context[:offset] = tmp_offset
      lexing_context[:end_offset] = @scanner.pos
      warn_if_variable_has_hyphen(var_name)
      # If the varname after ${ is followed by (, it is a function call, and not a variable
      # reference.
      #
      emitted_token = if braced && @scanner.match?(/#{@blank}*\(/)
        TOKENS[:NAME]
      else
        TOKENS[:VARIABLE]
      end
      token_queue << [emitted_token, position_in_source().merge!({:value=>var_name})]

      lexing_context[:offset] = @scanner.pos
      tokenize_interpolated_string(continuation_types())
    else
      tokenize_interpolated_string(token_type, replace_false_start_with_text(terminator))
    end
  end

  def replace_false_start_with_text(appendix)
    last_token = token_queue.pop
    value = last_token.last
    if value.is_a? Hash
      value[:value] + appendix
    else
      value + appendix
    end
  end

  # Returns the pattern for the heredoc `@(endtag[:syntax][/escapes])` syntax (at position when the leading '@' has been seen)
  # Produces groups for endtag (group 1), syntax (group 2), and escapes (group 3)
  #
  def heredoc_tagparts_pattern()
    # Note: pattern needs access to @blank pattern
    @heredoc_pattern_cache ||= %r{([^:/\r\n\)]+)(?::#{@blank}*([a-z][a-zA-Z0-9_+]+)#{@blank}*)?(?:/((?:\w|[$])*)#{@blank}*)?\)}
    @heredoc_pattern_cache
  end

  def heredoc
    # scanner is at position after opening @(
    skip
    # find end of the heredoc spec
    str = @scanner.scan_until(/\)/) || lex_error(positioned_message("Unclosed parenthesis after '@(' followed by '#{followed_by}'"))
    # Update where lexer is in terms of calculating position/offset/length
    lexing_context[:end_offset] = @scanner.pos

    # Note: allows '+' as separator in syntax, but this needs validation as empty segments are not allowed
    unless md = str.match(heredoc_tagparts_pattern())
      lex_error(positioned_message("Invalid syntax in heredoc expected @(endtag[:syntax][/escapes])"))
    end
    endtag = md[1]
    syntax = md[2] || ''
    escapes = md[3]

    endtag.strip!

    # Is this a dq string style heredoc? (endtag enclosed in "")
    if endtag =~ /^"(.*)"$/
      dqstring_style = true
      endtag = $1.strip
    end

    unless endtag.length >= 1
      lex_error(positioned_message("Missing endtag in heredoc"))
    end

    resulting_escapes = []
    if escapes
      escapes = "trnsL$" if escapes.length < 1

      escapes = escapes.split('')
      lex_error(positioned_message("An escape char for @() may only appear once. Got '#{escapes.join(', ')}")) unless escapes.length == escapes.uniq.length
      resulting_escapes = ["\\"]
      escapes.each do |e|
        case e
        when "t", "r", "n", "s", "$"
          resulting_escapes << e
        when "L"
          resulting_escapes += ["\n", "\r\n"]
        else
          lex_error(positioned_message("Invalid heredoc escape char. Only t, r, n, s, L, $ allowed. Got '#{e}'")) 
        end
      end
    end

    # Produce a heredoc token to make the syntax available to the grammar
    token_queue << [TOKENS[:HEREDOC], position_in_source().merge!({:value =>syntax})]

    # If this is the second or subsequent heredoc on the line, the lexing context's :heredoc_cont contains
    # the position after the \n where the next heredoc text should scan. If not set, this is the first
    # and it should start scanning after the first found \n (or if not found == error).
    pos_after_heredoc = @scanner.pos # where to continue
    if lexing_context[:heredoc_cont]
      @scanner.pos = lexing_context[:heredoc_cont]
    else
      @scanner.scan_until(/\n/) || lex_error(positioned_message("Heredoc without any following lines of text"))
    end
    # offset 0 for the heredoc, and its line number
    heredoc_offset = @scanner.pos
    heredoc_line = @locator.line_for_offset(heredoc_offset)-1

    # Compute message to emit if there is no end (to make it refer to the opening heredoc position).
    eof_message = positioned_message("Heredoc without end-tagged line")

    # Text from this position (+ lexing contexts offset for any preceding heredoc) is heredoc until a line
    # that terminates the heredoc is found.

    # (Endline in EBNF form): WS* ('|' WS*)? ('-' WS*)? endtag WS* \r? (\n|$)
    endline_pattern = /(#{@blank}*)(?:([|])#{@blank}*)?(?:(\-)#{@blank}*)?#{Regexp.escape(endtag)}#{@blank}*\r?(?:\n|\z)/
    lines = []
    while !@scanner.eos? do
      one_line = @scanner.scan_until(/(?:\n|\z)/) || lex_error(eof_message)
      if md = one_line.match(endline_pattern)
        leading      = md[1]
        has_margin   = md[2] == '|'
        remove_break = md[3] == '-'

        # Record position where next heredoc (from same line as current @()) should start scanning for content
        lexing_context[:heredoc_cont] = @scanner.pos

        # Process captured lines - remove leading, and trailing newline
        str = heredoc_text(lines, leading, has_margin, remove_break)
        if dqstring_style
          # if the style is dqstring a new lexer instance is needed, it is configured
          # with offsets to make it report errors correctly and it is given the escapes to use
          sublexer = self.class.new({:mode => :dqstring, :escapes => resulting_escapes})
          sublexer.lex_string(str, @file, heredoc_line, heredoc_offset, leading.length())
          sublexer.fullscan[0..-2].each {|token| token_queue << [TOKENS[token[0]], token[1]] }
        elsif resulting_escapes.length > 0
          # this is only needed to process escapes, if there are none the string can be used as is...
          subscanner = StringScanner.new(str)
          str = slurp subscanner, /\z/, resulting_escapes, :ignore_invalid_escapes
          token_queue << munge_token(TOKENS[:STRING], str)
        else
          # use string as is
          token_queue << munge_token(TOKENS[:STRING], str)
        end

        # Continue scan after @(...)
        @scanner.pos = pos_after_heredoc
        return
      else
        lines << one_line
      end
    end
    lex_error(eof_message)
  end

  # Produces the heredoc text string given the individual (unprocessed) lines as an array.
  # @param lines [Array<String>] unprocessed lines of text in the heredoc w/o terminating line
  # @param leading [String] the leading text up (up to pipe or other terminating char)
  # @param has_margin [Boolean] if the left margin should be adjusted as indicated by `leading`
  # @param remove_break [Boolean] if the line break (\r?\n) at the end of the last line should be removed or not
  #
  def heredoc_text lines, leading, has_margin, remove_break
    if has_margin
      leading_pattern = /^#{Regexp.escape(leading)}/
      lines = lines.collect {|s| s.gsub(leading_pattern, '') }
    end
    result = lines.join('')
    result.gsub!(/\r?\n$/, '') if remove_break
    result
  end

  # Returns continuation types (tokens that apply depending on how an interpolation scan ends) depending on mode.
  # If mode is "unquoted dqstring" (as used in Heredoc) and scan is for the outermost level (interpolation
  # depth <= 1), then the continuation types are based on a regular expression UQ_continuation_types that
  # matches the end of input without an error and an end token of ''), otherwise the normal continuation types.
  #
  def continuation_types
    context = lexing_context
    cont_types = if mode() == :dqstring && context[:string_interpolation_depth] <= 1
      UQ_continuation_token_types
    else
      DQ_continuation_token_types
    end
  end

  # Performs lexing of a string.
  # @deprecated Use #lex_string instead to enable setting the file origin and offsets.
  #
  def string=(string)
    lex_string(string)
  end

  # Performs lexing of a string with options controlling its origin.
  # The given file is used for information about the origin of the string. 
  #
  def lex_string(string, file=nil, leading_line_count=0, leading_offset = 0, leading_line_offset = 0)
    # Set file for information purposes only
    @file = file
    @scanner = StringScanner.new(string)
    @locator = Locator.new(string, multibyte?, leading_line_count, leading_offset, leading_line_offset)
  end

  def warn_if_variable_has_hyphen(var_name)
    if var_name.include?('-')
      Puppet.deprecation_warning("Using `-` in variable names is deprecated at #{file || '<string>'}:#{line}. See http://links.puppetlabs.com/puppet-hyphenated-variable-deprecation")
    end
  end

  # Returns the line number (starting from 1) for the current position
  # in the scanned text (at the end of the last produced, but not necessarily
  # consumed.
  #
  def line
    return 1 unless lexing_context && locator
    locator.line_for_offset(lexing_context[:end_offset])
  end

  # Helper class that keeps track of where line breaks are located and can answer questions about positions.
  # A Locator can be configured to produce absolute positions from relative.
  #
  class Locator
    # Index of offset per line
    attr_reader :line_index

    # The string being scanned (used to compute multibyte positions/offsets)
    attr_reader :string

    # The number of lines preceding the first line
    attr_reader :leading_line_count

    # The offset of offset 0
    attr_reader :leading_offset

    # The amount of offset to add to each line (i.e. the removed left margin in some container)
    attr_accessor :leading_line_offset

    # Create a locator based on a content string, and a boolean indicating if ruby version support multi-byte strings
    # or not.
    #
    def initialize(string, multibyte, leading_line_count=0, leading_offset = 0, leading_line_offset=0)
      @string = string
      @multibyte = multibyte
      compute_line_index
      @leading_line_count = leading_line_count
      @leading_offset = leading_offset
      @leading_line_offset = leading_line_offset
    end

    # Returns whether this a ruby version that supports multi-byte strings or not
    #
    def multibyte?
      @multibyte
    end

    # Computes the start offset for each line.
    #
    def compute_line_index
      scanner = StringScanner.new(@string)
      result = [0] # first line starts at 0
      while scanner.scan_until(/\n/)
        result << scanner.pos
      end
      @line_index = result
    end

    # Returns the line number (first line is 1) for the given offset
    def line_for_offset(offset)
      if line_nbr = line_index.index {|x| x > offset}
        return line_nbr + leading_line_count
      end
      # If not found it is after last
      return line_index.size + leading_line_count
    end

    # Returns the offset on line (first offset on a line is 0).
    #
    def offset_on_line(offset)
      effective_line = line_for_offset(offset) - leading_line_count
      line_offset = line_index[effective_line-1]
      if multibyte?
        @string.byteslice(line_offset, offset-line_offset).length + leading_line_offset
      else
        offset - line_offset + leading_line_offset
      end
    end

    # Returns the position on line (first position on a line is 1)
    def pos_on_line(offset)
      offset_on_line(offset) +1
    end

    # Returns the character offset for a given byte offset
    def char_offset(byte_offset)
      effective_line = line_for_offset(byte_offset) - leading_line_count
      line_offset = line_index[effective_line-1]
      if multibyte?
        @string.byteslice(0, byte_offset).length + (effective_line * leading_line_offset) + leading_offset
      else
        byte_offset + (effective_line * leading_line_offset) + leading_offset
      end
    end

    # Returns the length measured in number of characters from the given start and end byte offseta
    def char_length(offset, end_offset)
      if multibyte?
        @string.byteslice(offset, end_offset - offset).length
      else
        end_offset - offset
      end
    end
  end
end
