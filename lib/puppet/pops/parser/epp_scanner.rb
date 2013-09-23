require 'strscan'

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
class Puppet::Pops::Parser::EppScanner
  # The original scanner used by the lexer/container using EppScanner
  attr_reader :scanner

  # The resulting mode after the scan.
  # The mode is one of `:text` (the initial mode), `:epp` embedded code (no output), `:expr` (embedded
  # expression), or `:error`
  #
  attr_reader :mode

  # An error message if `mode == :error`, `nil` otherwise.
  attr_reader :message

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
        part.gsub!(/^[ \t]*\r?\n?/,'')
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
          @message = "Unbalanced embedded expression - opening <% and reaching end of input"
        else
          mode = :epp
        end
        return s

      when "-"
        # trim trailing whitespace on same line from accumulated s
        # return text and signal switch to pp mode
        @scanner.getch # drop the -
        s.gsub!(/\r?\n?[ \t]*<%\z/, '')
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
          @message = "Reaching end after opening <%# without seeing %>"
          @mode = :error
          return s
        end
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
