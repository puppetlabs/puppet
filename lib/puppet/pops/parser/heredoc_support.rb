module Puppet::Pops::Parser::HeredocSupport

  # Pattern for heredoc `@(endtag[:syntax][/escapes])
  # Produces groups for endtag (group 1), syntax (group 2), and escapes (group 3)
  #
  PATTERN_HEREDOC = %r{@\(([^:/\r\n\)]+)(?::[:blank:]*([a-z][a-zA-Z0-9_+]+)[:blank:]*)?(?:/((?:\w|[$])*)[:blank:]*)?\)}


  def heredoc
    scn = @scanner
    ctx = @lexing_context
    locator = @locator
    before = scn.pos

    # scanner is at position before @(
    # find end of the heredoc spec
    str = scn.scan_until(/\)/) || lexer.lex_error("Unclosed parenthesis after '@(' followed by '#{followed_by}'")
    pos_after_heredoc = scn.pos

    # Note: allows '+' as separator in syntax, but this needs validation as empty segments are not allowed
    unless md = str.match(PATTERN_HEREDOC)
      lex_error("Invalid syntax in heredoc expected @(endtag[:syntax][/escapes])")
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

    lexer.lex_error("Missing endtag in heredoc") unless endtag.length >= 1

    resulting_escapes = []
    if escapes
      escapes = "trnsuL$" if escapes.length < 1

      escapes = escapes.split('')
      unless escapes.length == escapes.uniq.length
        lex_error("An escape char for @() may only appear once. Got '#{escapes.join(', ')}")
      end
      resulting_escapes = ["\\"]
      escapes.each do |e|
        case e
        when "t", "r", "n", "s", "u", "$"
          resulting_escapes << e
        when "L"
          resulting_escapes += ["\n", "\r\n"]
        else
          lex_error("Invalid heredoc escape char. Only t, r, n, s,  u, L, $ allowed. Got '#{e}'")
        end
      end
    end

    # Produce a heredoc token to make the syntax available to the grammar
    enqueue_completed([:HEREDOC, syntax, pos_after_heredoc - before], before)

    # If this is the second or subsequent heredoc on the line, the lexing context's :newline_jump contains
    # the position after the \n where the next heredoc text should scan. If not set, this is the first
    # and it should start scanning after the first found \n (or if not found == error).

    if ctx[:newline_jump]
      scn.pos = lexing_context[:newline_jump]
    else
      scn.scan_until(/\n/) || lex_error("Heredoc without any following lines of text")
    end
    # offset 0 for the heredoc, and its line number
    heredoc_offset = scn.pos
    heredoc_line = locator.line_for_offset(heredoc_offset)-1

    # Compute message to emit if there is no end (to make it refer to the opening heredoc position).
    eof_message = positioned_message("Heredoc without end-tagged line")

    # Text from this position (+ lexing contexts offset for any preceding heredoc) is heredoc until a line
    # that terminates the heredoc is found.

    # (Endline in EBNF form): WS* ('|' WS*)? ('-' WS*)? endtag WS* \r? (\n|$)
    endline_pattern = /([[:blank:]]*)(?:([|])[[:blank:]]*)?(?:(\-)[[:blank:]]*)?#{Regexp.escape(endtag)}[[:blank:]]*\r?(?:\n|\z)/
    lines = []
    while !scn.eos? do
      one_line = scn.scan_until(/(?:\n|\z)/) || lexer.lex_error_without_pos(eof_message)
      if md = one_line.match(endline_pattern)
        leading      = md[1]
        has_margin   = md[2] == '|'
        remove_break = md[3] == '-'
        # Record position where next heredoc (from same line as current @()) should start scanning for content
        ctx[:newline_jump] = scn.pos

        # Process captured lines - remove leading, and trailing newline
        str = heredoc_text(lines, leading, has_margin, remove_break)

        # Use a new lexer instance configured with a sub-locator to enable correct positioning
        sublexer = self.class.new()
        locator = SubLocator.sub_locator(str, locator.file, heredoc_line, heredoc_offset, leading.length())
        sublexer.lex_unquoted_string(str, locator, resulting_escapes, dqstring_style)
        sublexer.interpolate_uq_to(self)
        # Continue scan after @(...)
        scn.pos = pos_after_heredoc
        return
      else
        lines << one_line
      end
    end
    lex_error_without_pos(eof_message)
  end

  # Produces the heredoc text string given the individual (unprocessed) lines as an array.
  # @param lines [Array<String>] unprocessed lines of text in the heredoc w/o terminating line
  # @param leading [String] the leading text up (up to pipe or other terminating char)
  # @param has_margin [Boolean] if the left margin should be adjusted as indicated by `leading`
  # @param remove_break [Boolean] if the line break (\r?\n) at the end of the last line should be removed or not
  #
  def heredoc_text(lines, leading, has_margin, remove_break)
    if has_margin
      leading_pattern = /^#{Regexp.escape(leading)}/
      lines = lines.collect {|s| s.gsub(leading_pattern, '') }
    end
    result = lines.join('')
    result.gsub!(/\r?\n$/, '') if remove_break
    result
  end

  # A Sublocator locates a concrete locator (subspace) in a virtual space.
  # The `leading_line_count` is the (virtual) number of lines preceding the first line in the concrete locator.
  # The `leading_offset` is the (virtual) byte offset of the first byte in the concrete locator.
  # The `leading_line_offset` is the (virtual) offset / margin in characters for each line.
  #
  # This illustrates characters in the sublocator (`.`) inside the subspace (`X`):
  #
  #      1:XXXXXXXX
  #      2:XXXX.... .. ... ..
  #      3:XXXX. . .... ..
  #      4:XXXX............
  #
  # This sublocator would be configured with leading_line_count = 1,
  # leading_offset=8, and leading_line_offset=4
  #
  # Note that leading_offset must be the same for all lines and measured in characters.
  #
  class SubLocator < Puppet::Pops::Parser::Locator
    def self.sub_locator(string, file, leading_line_count, leading_offset, leading_line_offset)
      self.new(Puppet::Pops::Parser::Locator.locator(string, file),
        leading_line_count,
        leading_offset,
        leading_line_offset)
    end

    def initialize(locator, leading_line_count, leading_offset, leading_line_offset)
      @locator = locator
      @leading_line_count = leading_line_count
      @leading_offset = leading_offset
      @leading_line_offset = leading_line_offset
    end

    def file
      @locator.file
    end

    def string
      @locator.string
    end

    # Given offset is offset in the subspace
    def line_for_offset(offset)
      @locator.line_for_offset(offset) + @leading_line_count
    end

    # Given offset is offset in the subspace
    def offset_on_line(offset)
      @locator.offset_on_line + @leading_line_offset
    end

    # Given offset is offset in the subspace
    def char_offset(offset)
      effective_line = @locator.line_for_offset(offset)
      locator.char_offset(offset) + (effective_line * @leading_line_offset) + @leading_offset
    end

    # Given offsets are offsets in the subspace
    def char_length(offset, end_offset)
      effective_line = @locator.line_for_offset(end_offset) - @locator.line_for_offset(offset)
      locator.char_length(offset, end_offset) + (effective_line * @leading_line_offset)
    end
  end

end