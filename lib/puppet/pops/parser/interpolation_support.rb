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
          text += value
          value,terminator = slurp_dqstring()
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
          text += value
          value,terminator = self.send(slurpfunc)
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
          text += value
          value,terminator = slurp_uqstring()
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
          text += value
          value,terminator = slurp_uqstring
          after = scn.pos
        end
      end
    end
    interpolate_tail_uq
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