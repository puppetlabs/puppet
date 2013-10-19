# Matches tokens produced by lexer
# The given exepected is one or more entries where an entry is one of
# - a token symbol
# - an Array with a token symbol and the text value
# - an Array with a token symbol and a Hash specifying all attributes of the token
# - nil (ignore)
#
RSpec::Matchers.define :match_tokens do | *expected |
  match do | actual |
    expected.zip(actual).all? do |e, a|
      compare(e, a)
      #!e or a[0] == e or (e.is_a? Array and a[0] == e[0] and (a[1] == e[1] or (a[1].is_a?(Hash) and a[1][:value] == e[1])))
    end
  end
  #diffable

  def failure_message_for_should
    msg = ["Expected:"]
    expected.each {|e| msg << e.to_s }

    zipped = expected.zip(actual)
    msg << "\nGot:"
    actual.each_with_index do |e, idx|
      if zipped[idx]
        zipped_expected = zipped[idx][0]
        zipped_actual = zipped[idx][0]

        prefix = compare(zipped_expected, zipped[idx][1]) ? ' ' : '*'
        msg2 = ["#{prefix}["]
        msg2 << e[0].to_s
        msg2 << ', '
        if e[1] == false
          msg2 << 'false'
        else
          msg2 << e[1][:value].to_s.dump
        end
        msg2 << ']'
        msg << msg2.join('')
      end
    end
    msg.join("\n")
  end

  def compare(e, a)
    !e or a[0] == e or (e.is_a? Array and a[0] == e[0] and (a[1] == e[1] or (a[1].is_a?(Hash) and a[1][:value] == e[1])))
  end
end
