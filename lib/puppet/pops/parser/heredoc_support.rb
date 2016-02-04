module Puppet::Pops
module Parser
module HeredocSupport
  include LexerSupport

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
    str = scn.scan_until(/\)/) || lex_error(Issues::HEREDOC_UNCLOSED_PARENTHESIS, :followed_by => followed_by)
    pos_after_heredoc = scn.pos

    # Note: allows '+' as separator in syntax, but this needs validation as empty segments are not allowed
    md = str.match(PATTERN_HEREDOC)
    lex_error(Issues::HEREDOC_INVALID_SYNTAX) unless md
    endtag = md[1]
    syntax = md[2] || ''
    escapes = md[3]

    endtag.strip!

    # Is this a dq string style heredoc? (endtag enclosed in "")
    if endtag =~ /^"(.*)"$/
      dqstring_style = true
      endtag = $1.strip
    end

    lex_error(Issues::HEREDOC_MISSING_ENDTAG) unless endtag.length >= 1

    resulting_escapes = []
    if escapes
      escapes = "trnsuL$" if escapes.length < 1

      escapes = escapes.split('')
      unless escapes.length == escapes.uniq.length
        lex_error(Issues::HEREDOC_MULTIPLE_AT_ESCAPES, :escapes => escapes)
      end
      resulting_escapes = ["\\"]
      escapes.each do |e|
        case e
        when "t", "r", "n", "s", "u", "$"
          resulting_escapes << e
        when "L"
          resulting_escapes += ["\n", "\r\n"]
        else
          lex_error(Issues::HEREDOC_INVALID_ESCAPE, :actual => e)
        end
      end
    end

    # Produce a heredoc token to make the syntax available to the grammar
    enqueue_completed([:HEREDOC, syntax, pos_after_heredoc - before], before)

    # If this is the second or subsequent heredoc on the line, the lexing context's :newline_jump contains
    # the position after the \n where the next heredoc text should scan. If not set, this is the first
    # and it should start scanning after the first found \n (or if not found == error).

    if ctx[:newline_jump]
      scn.pos = ctx[:newline_jump]
    else
      scn.scan_until(/\n/) || lex_error(Issues::HEREDOC_WITHOUT_TEXT)
    end
    # offset 0 for the heredoc, and its line number
    heredoc_offset = scn.pos
    heredoc_line = locator.line_for_offset(heredoc_offset)-1

    # Compute message to emit if there is no end (to make it refer to the opening heredoc position).
    eof_error = create_lex_error(Issues::HEREDOC_WITHOUT_END_TAGGED_LINE)

    # Text from this position (+ lexing contexts offset for any preceding heredoc) is heredoc until a line
    # that terminates the heredoc is found.

    # (Endline in EBNF form): WS* ('|' WS*)? ('-' WS*)? endtag WS* \r? (\n|$)
    endline_pattern = /([[:blank:]]*)(?:([|])[[:blank:]]*)?(?:(\-)[[:blank:]]*)?#{Regexp.escape(endtag)}[[:blank:]]*\r?(?:\n|\z)/
    lines = []
    while !scn.eos? do
      one_line = scn.scan_until(/(?:\n|\z)/)
      raise eof_error unless one_line
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
        locator = Locator::SubLocator.sub_locator(str,
          locator.file, heredoc_line, heredoc_offset, leading.length())

        # Emit a token that provides the grammar with location information about the lines on which the heredoc
        # content is based.
        enqueue([:SUBLOCATE,
          LexerSupport::TokenValue.new([:SUBLOCATE,
            lines, lines.reduce(0) {|size, s| size + s.length} ],
            heredoc_offset,
            locator)])

        sublexer.lex_unquoted_string(str, locator, resulting_escapes, dqstring_style)
        sublexer.interpolate_uq_to(self)
        # Continue scan after @(...)
        scn.pos = pos_after_heredoc
        return
      else
        lines << one_line
      end
    end
    raise eof_error
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


end
end
end
