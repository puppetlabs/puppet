# frozen_string_literal: true

require_relative '../../puppet/util'

module Puppet
module Util
module SymbolicFileMode
  SetUIDBit = ReadBit  = 4
  SetGIDBit = WriteBit = 2
  StickyBit = ExecBit  = 1
  SymbolicMode = { 'x' => ExecBit, 'w' => WriteBit, 'r' => ReadBit }
  SymbolicSpecialToBit = {
    't' => { 'u' => StickyBit, 'g' => StickyBit, 'o' => StickyBit },
    's' => { 'u' => SetUIDBit, 'g' => SetGIDBit, 'o' => StickyBit }
  }

  def valid_symbolic_mode?(value)
    value = normalize_symbolic_mode(value)
    return true if value =~ /^0?[0-7]{1,4}$/
    return true if value =~ /^([ugoa]*[-=+][-=+rstwxXugo]*)(,[ugoa]*[-=+][-=+rstwxXugo]*)*$/

    return false
  end

  def display_mode(value)
    if value =~ /^0?[0-7]{1,4}$/
      value.rjust(4, "0")
    else
      value
    end
  end

  def normalize_symbolic_mode(value)
    return nil if value.nil?

    # We need to treat integers as octal numbers.
    #
    # "A numeric mode is from one to four octal digits (0-7), derived by adding
    # up the bits with values 4, 2, and 1. Omitted digits are assumed to be
    # leading zeros."
    case value
    when Numeric
      value.to_s(8)
    when /^0?[0-7]{1,4}$/
      value.to_i(8).to_s(8) # strip leading 0's
    else
      value
    end
  end

  def symbolic_mode_to_int(modification, to_mode = 0, is_a_directory = false)
    if modification.nil? or modification == ''
      raise Puppet::Error, _("An empty mode string is illegal")
    elsif modification =~ /^[0-7]+$/
      return modification.to_i(8)
    elsif modification =~ /^\d+$/
      raise Puppet::Error, _("Numeric modes must be in octal, not decimal!")
    end

    fail _("non-numeric current mode (%{mode})") % { mode: to_mode.inspect } unless to_mode.is_a?(Numeric)

    original_mode = {
      's' => (to_mode & 0o7000) >> 9,
      'u' => (to_mode & 0o0700) >> 6,
      'g' => (to_mode & 0o0070) >> 3,
      'o' => (to_mode & 0o0007) >> 0,
      # Are there any execute bits set in the original mode?
      'any x?' => (to_mode & 0o0111) != 0
    }
    final_mode = {
      's' => original_mode['s'],
      'u' => original_mode['u'],
      'g' => original_mode['g'],
      'o' => original_mode['o'],
    }

    modification.split(/\s*,\s*/).each do |part|
      begin
        _, to, dsl = /^([ugoa]*)([-+=].*)$/.match(part).to_a
        if dsl.nil? then raise Puppet::Error, _('Missing action') end

        to = "a" unless to and to.length > 0

        # We want a snapshot of the mode before we start messing with it to
        # make actions like 'a-g' atomic.  Various parts of the DSL refer to
        # the original mode, the final mode, or the current snapshot of the
        # mode, for added fun.
        snapshot_mode = {}
        final_mode.each { |k, v| snapshot_mode[k] = v }

        to.gsub('a', 'ugo').split('').uniq.each do |who|
          value = snapshot_mode[who]

          action = '!'
          actions = {
            '!' => ->(_, _) { raise Puppet::Error, _('Missing operation (-, =, or +)') },
            '=' => ->(m, v) { m | v },
            '+' => ->(m, v) { m | v },
            '-' => ->(m, v) { m & ~v },
          }

          dsl.split('').each do |op|
            case op
            when /[-+=]/
              action = op
              # Clear all bits, if this is assignment
              value  = 0 if op == '='

            when /[ugo]/
              value = actions[action].call(value, snapshot_mode[op])

            when /[rwx]/
              value = actions[action].call(value, SymbolicMode[op])

            when 'X'
              # Only meaningful in combination with "set" actions.
              if action != '+'
                raise Puppet::Error, _("X only works with the '+' operator")
              end

              # As per the BSD manual page, set if this is a directory, or if
              # any execute bit is set on the original (unmodified) mode.
              # Ignored otherwise; it is "add if", not "add or clear".
              if is_a_directory or original_mode['any x?']
                value = actions[action].call(value, ExecBit)
              end

            when /[st]/
              bit = SymbolicSpecialToBit[op][who] or fail _("internal error")
              final_mode['s'] = actions[action].call(final_mode['s'], bit)

            else
              raise Puppet::Error, _('Unknown operation')
            end
          end

          # Now, assign back the value.
          final_mode[who] = value
        end
      rescue Puppet::Error => e
        if part.inspect != modification.inspect
          rest = " at #{part.inspect}"
        else
          rest = ''
        end

        raise Puppet::Error, _("%{error}%{rest} in symbolic mode %{modification}") % { error: e, rest: rest, modification: modification.inspect }, e.backtrace
      end
    end

    result =
      final_mode['s'] << 9 |
      final_mode['u'] << 6 |
      final_mode['g'] << 3 |
      final_mode['o'] << 0
    return result
  end
end
end
end
