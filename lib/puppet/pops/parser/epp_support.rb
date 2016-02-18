module Puppet::Pops
module Parser
# This module is an integral part of the Lexer.
# It handles scanning of EPP (Embedded Puppet), a form of string/expression interpolation similar to ERB.
#
require 'strscan'
module EppSupport

  TOKEN_RENDER_STRING = [:RENDER_STRING, nil, 0]
  TOKEN_RENDER_EXPR   = [:RENDER_EXPR, nil, 0]

  # Scans all of the content and returns it in an array
  # Note that the terminating [false, false] token is included in the result.
  #
  def fullscan_epp
    result = []
    scan_epp {|token, value| result.push([token, value]) }
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
  def scan_epp
    # PERFORMANCE note: it is faster to access local variables than instance variables.
    # This makes a small but notable difference since instance member access is avoided for
    # every token in the lexed content.
    #
    scn   = @scanner
    ctx   = @lexing_context
    queue = @token_queue

    lex_error(Issues::EPP_INTERNAL_ERROR, :error => 'No string or file given to lexer to process.') unless scn

    ctx[:epp_mode] = :text
    enqueue_completed([:EPP_START, nil, 0], 0)

    interpolate_epp

    # This is the lexer's main loop
    until queue.empty? && scn.eos? do
      if token = queue.shift || lex_token
        yield [ ctx[:after] = token[0], token[1] ]
      end
    end
    if ctx[:epp_open_position]
      lex_error(Issues::EPP_UNBALANCED_TAG, {}, ctx[:epp_position])
    end

    # Signals end of input
    yield [false, false]
  end

  def interpolate_epp(skip_leading=false)
    scn = @scanner
    ctx = @lexing_context
    eppscanner = EppScanner.new(scn)
    before = scn.pos

    s = eppscanner.scan(skip_leading)

    case eppscanner.mode
    when :text
      # Should be at end of scan, or something is terribly wrong
      unless @scanner.eos?
        lex_error(Issues::EPP_INTERNAL_ERROR, :error => 'template scanner returns text mode and is not and end of input')
      end
      if s
        # s may be nil if scanned text ends with an epp tag (i.e. no trailing text).
        enqueue_completed([:RENDER_STRING, s, scn.pos - before], before)
      end
      ctx[:epp_open_position] = nil
      # do nothing else, scanner is at the end

    when :error
      lex_error(eppscanner.issue)

    when :epp
      # It is meaningless to render empty string segments, and it is harmful to do this at
      # the start of the scan as it prevents specification of parameters with <%- ($x, $y) -%>
      #
      if s && s.length > 0
        enqueue_completed([:RENDER_STRING, s, scn.pos - before], before)
      end
      # switch epp_mode to general (embedded) pp logic (non rendered result)
      ctx[:epp_mode] = :epp
      ctx[:epp_open_position] = scn.pos

    when :expr
      # It is meaningless to render an empty string segment
      if s && s.length > 0
        enqueue_completed([:RENDER_STRING, s, scn.pos - before], before)
      end
      enqueue_completed(TOKEN_RENDER_EXPR, before)
      # switch mode to "epp expr interpolation"
      ctx[:epp_mode] = :expr
      ctx[:epp_open_position] = scn.pos
    else
      lex_error(Issues::EPP_INTERNAL_ERROR, :error => "Unknown mode #{eppscanner.mode} returned by template scanner")
    end
    nil
  end

  # A scanner specialized in processing text with embedded EPP (Embedded Puppet) tags.
  # The scanner is initialized with a StringScanner which it mutates as scanning takes place.
  # The intent is to use one instance of EppScanner per wanted scan, and this instance represents
  # the state after the scan.
  #
  # @example Sample usage
  #   a = "some text <% pp code %> some more text"
  #   scan = StringScanner.new(a)
  #   eppscan = EppScanner.new(scan)
  #   str = eppscan.scan
  #   eppscan.mode # => :epp
  #   eppscan.lines # => 0
  #   eppscan
  #
  # The scanner supports
  # * scanning text until <%, <%-, <%=
  # * while scanning text:
  #   * tokens <%% and %%> are translated to <% and %> respetively and is returned as text.
  #   * tokens <%# and %> (or ending with -%>) and the enclosed text is a comment and is not included in the returned text
  #   * text following a comment that ends with -%> gets trailing whitespace (up to and including a line break) trimmed
  #     and this whitespace is not included in the returned text.
  # * The continuation {#mode} is set to one of:
  #   * `:epp` - for a <% token
  #   * `:expr` - for a <%= token
  #   * `:text` - when there was no continuation mode (e.g. when input ends with text)
  #   * ':error` - if the tokens are unbalanced (reaching the end without a closing matching token). An error message
  #     is then also available via the method {#message}.
  #
  # Note that the intent is to use this specialized scanner to scan the text parts, when continuation mode is `:epp` or `:expr`
  # the pp lexer should advance scanning (using the string scanner) until it reaches and consumes a `-%>` or '%>´ token. If it
  # finds a `-%> token it should pass this on as a `skip_leading` parameter when it performs the next {#scan}.
  #
  class EppScanner
    # The original scanner used by the lexer/container using EppScanner
    attr_reader :scanner

    # The resulting mode after the scan.
    # The mode is one of `:text` (the initial mode), `:epp` embedded code (no output), `:expr` (embedded
    # expression), or `:error`
    #
    attr_reader :mode

    # An error issue if `mode == :error`, `nil` otherwise.
    attr_reader :issue

    # If the first scan should skip leading whitespace (typically detected by the pp lexer when the
    # pp mode end-token is found (i.e. `-%>`) and then passed on to the scanner.
    #
    attr_reader :skip_leading

    # Creates an EppScanner based on a StringScanner that represents the state where EppScanner should start scanning.
    # The given scanner will be mutated (i.e. position moved) to reflect the EppScanner's end state after a scan.
    #
    def initialize(scanner)
      @scanner = scanner
    end

    # Here for backwards compatibility.
    # @deprecated Use issue instead
    # @return [String] the issue message
    def message
      @issue.nil? ? nil : @issue.format
    end

    # Scans from the current position in the configured scanner, advances this scanner's position until the end
    # of the input, or to the first position after a mode switching token (`<%`, `<%-` or `<%=`). Number of processed
    # lines and continuation mode can be obtained via {#lines}, and {#mode}.
    #
    # @return [String, nil] the scanned and processed text, or nil if at the end of the input.
    #
    def scan(skip_leading=false)
      @mode = :text
      @skip_leading = skip_leading

      return nil if scanner.eos?
      s = ""
      until scanner.eos?
        part = @scanner.scan_until(/(<%)|\z/)
        if @skip_leading
          part.sub!(/^[ \t]*\r?(?:\n|\z)?/,'')
          @skip_leading = false
        end
        # The spec for %%> is to transform it into a literal %>. This is done here, as %%> otherwise would go
        # undetected in text mode. (i.e. it is not really necessary to escape %> with %%> in text mode unless
        # adding checks stating that a literal %> is illegal in text (unbalanced).
        #
        part.gsub!(/%%>/, '%>')
        s += part
        case @scanner.peek(1)
        when ""
          # at the end
          # if s ends with <% then this is an error (unbalanced <% %>)
          if s.end_with? "<%"
            @mode = :error
            @issue = Issues::EPP_UNBALANCED_EXPRESSION
          else
            mode = :epp
          end
          return s

        when "-"
          # trim trailing whitespace on same line from accumulated s
          # return text and signal switch to pp mode
          @scanner.getch # drop the -
          s.sub!(/[ \t]*<%\z/, '')
          @mode = :epp
          return s

        when "%"
          # verbatim text
          # keep the scanned <%, and continue scanning after skipping one %
          # (i.e. do nothing here)
          @scanner.getch # drop the % to get a literal <% in the output

        when "="
          # expression
          # return text and signal switch to expression mode
          # drop the scanned <%, and skip past -%>, or %>, but also skip %%>
          @scanner.getch # drop the =
          s.slice!(-2..-1)
          @mode = :expr
          return s

        when "#"
          # template comment
          # drop the scanned <%, and skip past -%>, or %>, but also skip %%>
          s.slice!(-2..-1)

          # unless there is an immediate termination i.e. <%#%> scan for the next %> that is not
          # preceded by a % (i.e. skip %%>)
          part = scanner.scan_until(/[^%]%>/)
          unless part
            @issue = Issues::EPP_UNBALANCED_COMMENT
            @mode = :error
            return s
          end
          # Always trim leading whitespace on the same line when there is a comment
          s.sub!(/[ \t]*\z/, '')
          @skip_leading = true if part.end_with?("-%>")
          # Continue scanning for more text

        else
          # Switch to pp after having removed the <%
          s.slice!(-2..-1)
          @mode = :epp
          return s
        end
      end
    end
  end

end
end
end
