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

  def lex_error msg
    raise Puppet::LexError.new(msg)
  end

  class Token
    ALWAYS_ACCEPTABLE = Proc.new { |context| true }

    include Puppet::Util::MethodHelper

    attr_accessor :regex, :name, :string, :skip, :skip_text
    alias skip? skip

    # @param string_or_regex[String] a literal string token matcher
    # @param string_or_regex[Regexp] a regular expression token text matcher
    # @param name [String] the token name (what it is known as in the grammar)
    # @param options [Hash] see {#set_options}
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
    [TOKENS[:STRING], lexer.slurpstring(value,["'"],:ignore_invalid_escapes).first ]
  end

  DQ_initial_token_types      = {'$' => :DQPRE,'"' => :STRING}
  DQ_continuation_token_types = {'$' => :DQMID,'"' => :DQPOST}

  TOKENS.add_token :DQUOTE, /"/ do |lexer, value|
    lexer.tokenize_interpolated_string(DQ_initial_token_types)
  end

  TOKENS.add_token :DQCONT, /\}/ do |lexer, value|
    lexer.tokenize_interpolated_string(DQ_continuation_token_types)
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

  # scan the whole file
  # basically just used for testing
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

  # Find the next token, returning the string and the token.
  def find_token
    shift_token || find_regex_token || find_string_token
  end

  def initialize
    @multibyte = init_multibyte
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
      @skip = %r{[[:blank:]\r]+}
    else
      @skip = %r{[ \t\r]+}
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

    # Add one to pos, first char on line is 1
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

    # Skip any initial whitespace.
    skip

    until token_queue.empty? and @scanner.eos? do
      offset = @scanner.pos
      matched_token, value = find_token
      end_offset = @scanner.pos

      # error out if we didn't match anything at all
      lex_error "Could not match #{@scanner.rest[/^(\S+|\s+|.*)/]}" unless matched_token

      newline = matched_token.name == :RETURN

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

  # we've encountered the start of a string...
  # slurp in the rest of the string and return it
  def slurpstring(terminators,escapes=%w{ \\  $ ' " r n t s }+["\n"],ignore_invalid_escapes=false)
    # we search for the next quote that isn't preceded by a
    # backslash; the caret is there to match empty strings
    last = @scanner.matched
    str = @scanner.scan_until(/([^\\]|^|[^\\])([\\]{2})*[#{terminators}]/) || lex_error(positioned_message("Unclosed quote after #{format_quote(last)} followed by '#{followed_by}'"))
    str.gsub!(/\\(.)/m) {
      ch = $1
      if escapes.include? ch
        case ch
        when 'r'; "\r"
        when 'n'; "\n"
        when 't'; "\t"
        when 's'; " "
        when "\n"; ''
        else      ch
        end
      else
        Puppet.warning(positioned_message("Unrecognized escape sequence '\\#{ch}'")) unless ignore_invalid_escapes
        "\\#{ch}"
      end
    }
    [ str[0..-2],str[-1,1] ]
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
    value,terminator = slurpstring('"$')

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
      if braced && @scanner.match?(%r{[ \t\r]*\(})
        token_queue << [TOKENS[:NAME], position_in_source().merge!({:value=>var_name})]
      else
        token_queue << [TOKENS[:VARIABLE],position_in_source().merge!({:value=>var_name})]
      end
      lexing_context[:offset] = @scanner.pos
      tokenize_interpolated_string(DQ_continuation_token_types)
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

  # just parse a string, not a whole file
  def string=(string)
    @scanner = StringScanner.new(string)
    @locator = Locator.new(string, multibyte?)
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
  #
  class Locator
    attr_reader :line_index
    attr_reader :string

    # Create a locator based on a content string, and a boolean indicating if ruby version support multi-byte strings
    # or not.
    #
    def initialize(string, multibyte)
      @string = string
      @multibyte = multibyte
      compute_line_index
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
        return line_nbr
      end
      # If not found it is after last
      return line_index.size
    end

    # Returns the offset on line (first offset on a line is 0).
    #
    def offset_on_line(offset)
      line_offset = line_index[line_for_offset(offset)-1]
      if multibyte?
        @string.byteslice(line_offset, offset-line_offset).length
      else
        offset - line_offset
      end
    end

    # Returns the position on line (first position on a line is 1)
    def pos_on_line(offset)
      offset_on_line(offset) +1
    end

    # Returns the character offset for a given byte offset
    def char_offset(byte_offset)
      if multibyte?
        @string.byteslice(0, byte_offset).length
      else
        byte_offset
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
