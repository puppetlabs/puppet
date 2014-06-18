# the scanner/lexer

require 'forwardable'
require 'strscan'
require 'puppet'
require 'puppet/util/methodhelper'


module Puppet
  class LexError < RuntimeError; end
end

module Puppet::Parser; end

class Puppet::Parser::Lexer
  extend Forwardable

  attr_reader :last, :file, :lexing_context, :token_queue

  attr_accessor :line, :indefine
  alias :indefine? :indefine

  # Returns the position on the line.
  # This implementation always returns nil. It is here for API reasons in Puppet::Error
  # which needs to support both --parser current, and --parser future.
  #
  def pos
    # Make the lexer comply with newer API. It does not produce a pos...
    nil
  end

  def lex_error msg
    raise Puppet::LexError.new(msg)
  end

  class Token
    ALWAYS_ACCEPTABLE = Proc.new { |context| true }

    include Puppet::Util::MethodHelper

    attr_accessor :regex, :name, :string, :skip, :incr_line, :skip_text, :accumulate
    alias skip? skip
    alias accumulate? accumulate

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

    def to_s
      string or @name.to_s
    end

    def acceptable?(context={})
      @acceptable_when.call(context)
    end

    # Define when the token is able to match.
    # This provides context that cannot be expressed otherwise, such as feature flags.
    #
    # @param block [Proc] a proc that given a context returns a boolean
    def acceptable_when(block)
      @acceptable_when = block
    end
  end

  # Maintain a list of tokens.
  class TokenList
    extend Forwardable

    attr_reader :regex_tokens, :string_tokens
    def_delegator :@tokens, :[]

    # Create a new token.
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

    def initialize
      @tokens = {}
      @regex_tokens = []
      @string_tokens = []
      @tokens_by_string = {}
    end

    # Look up a token by its value, rather than name.
    def lookup(string)
      @tokens_by_string[string]
    end

    # Define more tokens.
    def add_tokens(hash)
      hash.each do |regex, name|
        add_token(name, regex)
      end
    end

    # Sort our tokens by length, so we know once we match, we're done.
    # This helps us avoid the O(n^2) nature of token matching.
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
    '{'   => :LBRACE,
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
    "<boolean>" => :BOOLEAN
  )

  module Contextual
    QUOTE_TOKENS = [:DQPRE,:DQMID]
    REGEX_INTRODUCING_TOKENS = [:NODE,:LBRACE,:RBRACE,:MATCH,:NOMATCH,:COMMA]

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

  # Numbers are treated separately from names, so that they may contain dots.
  TOKENS.add_token :NUMBER, %r{\b(?:0[xX][0-9A-Fa-f]+|0?\d+(?:\.\d+)?(?:[eE]-?\d+)?)\b} do |lexer, value|
    [TOKENS[:NAME], value]
  end
  TOKENS[:NUMBER].acceptable_when Contextual::NOT_INSIDE_QUOTES

  TOKENS.add_token :NAME, %r{((::)?[a-z0-9][-\w]*)(::[a-z0-9][-\w]*)*} do |lexer, value|
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

  TOKENS.add_token :COMMENT, %r{#.*}, :accumulate => true, :skip => true do |lexer,value|
    value.sub!(/# ?/,'')
    [self, value]
  end

  TOKENS.add_token :MLCOMMENT, %r{/\*(.*?)\*/}m, :accumulate => true, :skip => true do |lexer, value|
    lexer.line += value.count("\n")
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

  TOKENS.add_token :RETURN, "\n", :skip => true, :incr_line => true, :skip_text => true

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

    [TOKENS[:VARIABLE], value]
  end
  TOKENS[:VARIABLE_WITH_DASH].acceptable_when Contextual::VARIABLE_AND_DASHES_ALLOWED

  TOKENS.add_token :VARIABLE, %r{(::)?(\w+::)*\w+}
  TOKENS[:VARIABLE].acceptable_when Contextual::INSIDE_QUOTES

  TOKENS.sort_tokens

  @@pairs = {
    "{"   => "}",
    "("   => ")",
    "["   => "]",
    "<|"  => "|>",
    "<<|" => "|>>"
  }

  KEYWORDS = TokenList.new
  KEYWORDS.add_tokens(
    "case"     => :CASE,
    "class"    => :CLASS,
    "default"  => :DEFAULT,
    "define"   => :DEFINE,
    "import"   => :IMPORT,
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
    TOKENS.lookup(name) or lex_error "Could not find expected token #{name}"
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
    @line = 1
    contents = Puppet::FileSystem.exist?(file) ? Puppet::FileSystem.read(file) : ""
    @scanner = StringScanner.new(contents)
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
    initvars
  end

  def initvars
    @line = 1
    @previous_token = nil
    @scanner = nil
    @file = nil
    # AAARRGGGG! okay, regexes in ruby are bloody annoying
    # no one else has "\n" =~ /\s/
    @skip = %r{[ \t\r]+}

    @namestack = []
    @token_queue = []
    @indefine = false
    @expected = []
    @commentstack = [ ['', @line] ]
    @lexing_context = {
      :after => nil,
      :start_of_line => true,
      :string_interpolation_depth => 0
      }
  end

  # Make any necessary changes to the token and/or value.
  def munge_token(token, value)
    @line += 1 if token.incr_line

    skip if token.skip_text

    return if token.skip and not token.accumulate?

    token, value = token.convert(self, value) if token.respond_to?(:convert)

    return unless token

    if token.accumulate?
      comment = @commentstack.pop
      comment[0] << value + "\n"
      @commentstack.push(comment)
    end

    return if token.skip

    return token, { :value => value, :line => @line }
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
    lex_error "Invalid or empty string" unless @scanner

    # Skip any initial whitespace.
    skip

    until token_queue.empty? and @scanner.eos? do
      matched_token, value = find_token

      # error out if we didn't match anything at all
      lex_error "Could not match #{@scanner.rest[/^(\S+|\s+|.*)/]}" unless matched_token

      newline = matched_token.name == :RETURN

      # this matches a blank line; eat the previously accumulated comments
      getcomment if lexing_context[:start_of_line] and newline
      lexing_context[:start_of_line] = newline

      final_token, token_value = munge_token(matched_token, value)

      unless final_token
        skip
        next
      end

      final_token_name = final_token.name
      lexing_context[:after]         = final_token_name unless newline
      lexing_context[:string_interpolation_depth] += 1 if final_token_name == :DQPRE
      lexing_context[:string_interpolation_depth] -= 1 if final_token_name == :DQPOST

      value = token_value[:value]

      if match = @@pairs[value] and final_token_name != :DQUOTE and final_token_name != :SQUOTE
        @expected << match
      elsif exp = @expected[-1] and exp == value and final_token_name != :DQUOTE and final_token_name != :SQUOTE
        @expected.pop
      end

      if final_token_name == :LBRACE or final_token_name == :LPAREN
        commentpush
      end
      if final_token_name == :RPAREN
        commentpop
      end

      yield [final_token_name, token_value]

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
    @scanner = nil

    # This indicates that we're done parsing.
    yield [false,false]
  end

  # Skip any skipchars in our remaining string.
  def skip
    @scanner.skip(@skip)
  end

  # Provide some limited access to the scanner, for those
  # tokens that need it.
  def_delegator :@scanner, :scan_until

  # we've encountered the start of a string...
  # slurp in the rest of the string and return it
  def slurpstring(terminators,escapes=%w{ \\  $ ' " r n t s }+["\n"],ignore_invalid_escapes=false)
    # we search for the next quote that isn't preceded by a
    # backslash; the caret is there to match empty strings
    str = @scanner.scan_until(/([^\\]|^|[^\\])([\\]{2})*[#{terminators}]/) or lex_error "Unclosed quote after '#{last}' in '#{rest}'"
    @line += str.count("\n") # literal carriage returns add to the line count.
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
        Puppet.warning "Unrecognised escape sequence '\\#{ch}'#{file && " in file #{file}"}#{line && " at line #{line}"}" unless ignore_invalid_escapes
        "\\#{ch}"
      end
    }
    [ str[0..-2],str[-1,1] ]
  end

  def tokenize_interpolated_string(token_type,preamble='')
    value,terminator = slurpstring('"$')
    token_queue << [TOKENS[token_type[terminator]],preamble+value]
    variable_regex = if Puppet[:allow_variables_with_dashes]
                       TOKENS[:VARIABLE_WITH_DASH].regex
                     else
                       TOKENS[:VARIABLE].regex
                     end
    if terminator != '$' or @scanner.scan(/\{/)
      token_queue.shift
    elsif var_name = @scanner.scan(variable_regex)
      warn_if_variable_has_hyphen(var_name)
      token_queue << [TOKENS[:VARIABLE],var_name]
      tokenize_interpolated_string(DQ_continuation_token_types)
    else
      tokenize_interpolated_string(token_type,token_queue.pop.last + terminator)
    end
  end

  # just parse a string, not a whole file
  def string=(string)
    @scanner = StringScanner.new(string)
  end

  # returns the content of the currently accumulated content cache
  def commentpop
    @commentstack.pop[0]
  end

  def getcomment(line = nil)
    comment = @commentstack.last
    if line.nil? or comment[1] <= line
      @commentstack.pop
      @commentstack.push(['', @line])
      return comment[0]
    end
    ''
  end

  def commentpush
    @commentstack.push(['', @line])
  end

  def warn_if_variable_has_hyphen(var_name)
    if var_name.include?('-')
      Puppet.deprecation_warning("Using `-` in variable names is deprecated at #{file || '<string>'}:#{line}. See http://links.puppetlabs.com/puppet-hyphenated-variable-deprecation")
    end
  end
end
