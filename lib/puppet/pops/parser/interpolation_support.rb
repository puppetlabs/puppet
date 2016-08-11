# This module is an integral part of the Lexer.
# It defines interpolation support
# PERFORMANCE NOTE: There are 4 very similar methods in this module that are designed to be as
# performant as possible. While it is possible to parameterize them into one common method, the overhead
# of passing parameters and evaluating conditional logic has a negative impact on performance.
#
module Puppet::Pops::Parser::InterpolationSupport

  PATTERN_VARIABLE       = %r{(::)?(\w+::)*\w+}

  # This is the starting point for a double quoted string with possible interpolation
  # The structure mimics that of the grammar.
  # The logic is explicit (where the former implementation used parameters/strucures) given to a
  # generic handler.
  # (This is both easier to understand and faster).
  #
  def interpolate_dq
    scn = @scanner
    ctx = @lexing_context
    before = scn.pos
    # skip the leading " by doing a scan since the slurp_dqstring uses last matched when there is an error
    scn.scan(/"/)
    value,terminator = slurp_dqstring()
    text = value
    after = scn.pos
    while true
      case terminator
      when '"'
        # simple case, there was no interpolation, return directly
        return emit_completed([:STRING, text, scn.pos-before], before)
      when '${'
        count = ctx[:brace_count]
        ctx[:brace_count] += 1
        # The ${ terminator is counted towards the string part
        enqueue_completed([:DQPRE, text, scn.pos-before], before)
        # Lex expression tokens until a closing (balanced) brace count is reached
        enqueue_until count
        break
      when '$'
        if varname = scn.scan(PATTERN_VARIABLE)
          # The $ is counted towards the variable
          enqueue_completed([:DQPRE, text, after-before-1], before)
          enqueue_completed([:VARIABLE, varname, scn.pos - after + 1], after -1)
          break
        else
          # false $ variable start
          text += terminator
          value,terminator = slurp_dqstring()
          text += value
          after = scn.pos
        end
      end
    end
    interpolate_tail_dq
    # return the first enqueued token and shift the queue
    @token_queue.shift
  end

  def interpolate_tail_dq
    scn = @scanner
    ctx = @lexing_context
    before = scn.pos
    value,terminator = slurp_dqstring
    text = value
    after = scn.pos
    while true
      case terminator
      when '"'
        # simple case, there was no further interpolation, return directly
        enqueue_completed([:DQPOST, text, scn.pos-before], before)
        return
      when '${'
        count = ctx[:brace_count]
        ctx[:brace_count] += 1
        # The ${ terminator is counted towards the string part
        enqueue_completed([:DQMID, text, scn.pos-before], before)
        # Lex expression tokens until a closing (balanced) brace count is reached
        enqueue_until count
        break
      when '$'
        if varname = scn.scan(PATTERN_VARIABLE)
          # The $ is counted towards the variable
          enqueue_completed([:DQMID, text, after-before-1], before)
          enqueue_completed([:VARIABLE, varname, scn.pos - after +1], after -1)
          break
        else
          # false $ variable start
          text += terminator
          value,terminator = slurp_dqstring
          text += value
          after = scn.pos
        end
      end
    end
    interpolate_tail_dq
  end

  # This is the starting point for a un-quoted string with possible interpolation
  # The logic is explicit (where the former implementation used parameters/strucures) given to a
  # generic handler.
  # (This is both easier to understand and faster).
  #
  def interpolate_uq
    scn = @scanner
    ctx = @lexing_context
    before = scn.pos
    value,terminator = slurp_uqstring()
    text = value
    after = scn.pos
    while true
      case terminator
      when ''
        # simple case, there was no interpolation, return directly
        enqueue_completed([:STRING, text, scn.pos-before], before)
        return
      when '${'
        count = ctx[:brace_count]
        ctx[:brace_count] += 1
        # The ${ terminator is counted towards the string part
        enqueue_completed([:DQPRE, text, scn.pos-before], before)
        # Lex expression tokens until a closing (balanced) brace count is reached
        enqueue_until count
        break
      when '$'
        if varname = scn.scan(PATTERN_VARIABLE)
          # The $ is counted towards the variable
          enqueue_completed([:DQPRE, text, after-before-1], before)
          enqueue_completed([:VARIABLE, varname, scn.pos - after + 1], after -1)
          break
        else
          # false $ variable start
          text += terminator
          value,terminator = slurp_uqstring()
          text += value
          after = scn.pos
        end
      end
    end
    interpolate_tail_uq
    nil
  end

  def interpolate_tail_uq
    scn = @scanner
    ctx = @lexing_context
    before = scn.pos
    value,terminator = slurp_uqstring
    text = value
    after = scn.pos
    while true
      case terminator
      when ''
        # simple case, there was no further interpolation, return directly
        enqueue_completed([:DQPOST, text, scn.pos-before], before)
        return
      when '${'
        count = ctx[:brace_count]
        ctx[:brace_count] += 1
        # The ${ terminator is counted towards the string part
        enqueue_completed([:DQMID, text, scn.pos-before], before)
        # Lex expression tokens until a closing (balanced) brace count is reached
        enqueue_until count
        break
      when '$'
        if varname = scn.scan(PATTERN_VARIABLE)
          # The $ is counted towards the variable
          enqueue_completed([:DQMID, text, after-before-1], before)
          enqueue_completed([:VARIABLE, varname, scn.pos - after +1], after -1)
          break
        else
          # false $ variable start
          text += terminator
          value,terminator = slurp_uqstring
          text += value
          after = scn.pos
        end
      end
    end
    interpolate_tail_uq
  end

  # Enqueues lexed tokens until either end of input, or the given brace_count is reached
  #
  def enqueue_until brace_count
    scn = @scanner
    ctx = @lexing_context
    queue = @token_queue
    queue_base = @token_queue[0]

    scn.skip(self.class::PATTERN_WS)
    queue_size = queue.size
    until scn.eos? do
      if token = lex_token
        if token.equal?(queue_base)
          # A nested #interpolate_dq call shifted the queue_base token from the @token_queue. It must
          # be put back since it is intended for the top level #interpolate_dq call only.
          queue.insert(0, token)
          next # all relevant tokens are already on the queue
        end
        token_name = token[0]
        ctx[:after] = token_name
        if token_name == :RBRACE && ctx[:brace_count] == brace_count
          qlength = queue.size - queue_size
          if qlength == 1
            # Single token is subject to replacement
            queue[-1] = transform_to_variable(queue[-1])
          elsif qlength > 1 && [:DOT, :LBRACK].include?(queue[queue_size + 1][0])
            # A first word, number of name token followed by '[' or '.' is subject to replacement
            # But not for other operators such as ?, +, - etc. where user must use a $ before the name
            # to get a variable
            queue[queue_size] = transform_to_variable(queue[queue_size])
          end
          return
        end
        queue << token
      else
        scn.skip(self.class::PATTERN_WS)
      end
    end
  end

  def transform_to_variable(token)
    token_name = token[0]
    if [:NUMBER, :NAME, :WORD].include?(token_name) || self.class::KEYWORD_NAMES[token_name]
      t = token[1]
      ta = t.token_array
      [:VARIABLE, self.class::TokenValue.new([:VARIABLE, ta[1], ta[2]], t.offset, t.locator)]
    else
      token
    end
  end

  # Interpolates unquoted string and transfers the result to the given lexer
  # (This is used when a second lexer instance is used to lex a substring)
  #
  def interpolate_uq_to(lexer)
    interpolate_uq
    queue = @token_queue
    until queue.empty? do
      lexer.enqueue(queue.shift)
    end
  end

end
