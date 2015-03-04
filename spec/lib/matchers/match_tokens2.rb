# Matches tokens produced by lexer
# The given exepected is one or more entries where an entry is one of
# - a token symbol
# - an Array with a token symbol and the text value
# - an Array with a token symbol and a Hash specifying all attributes of the token
# - nil (ignore)
#
RSpec::Matchers.define :match_tokens2 do | *expected |
  match do | actual |
    expected.zip(actual).all? do |e, a|
      compare(e, a)
    end
  end

  def failure_message
    msg = ["Expected (#{expected.size}):"]
    expected.each {|e| msg << e.to_s }

    zipped = expected.zip(actual)
    msg << "\nGot (#{actual.size}):"
    actual.each_with_index do |e, idx|
      if zipped[idx]
        zipped_expected = zipped[idx][0]
        zipped_actual = zipped[idx][1]

        prefix = compare(zipped_expected, zipped_actual) ? ' ' : '*'
        msg2 = ["#{prefix}[:"]
        msg2 << e[0].to_s
        msg2 << ', '
        if e[1] == false
          msg2 << 'false'
        else
          msg2 << e[1][:value].to_s.dump
        end
        # If expectation has options, output them
        if zipped_expected.is_a?(Array) && zipped_expected[2] && zipped_expected[2].is_a?(Hash)
          msg2 << ", {"
          msg3 = []
          zipped_expected[2].each do |k,v|
            prefix = e[1][k] != v ? "*" : ''
            msg3 << "#{prefix}:#{k}=>#{e[1][k]}"
          end
          msg2 << msg3.join(", ")
          msg2 << "}"
        end
        msg2 << ']'
        msg << msg2.join('')
      end
    end
    msg.join("\n")
  end

  def compare(e, a)
    # if expected ends before actual
    return true if !e

    # If actual ends before expected
    return false if !a

    # Simple - only expect token to match
    return true if a[0] == e

    # Expect value and optional attributes to match
    if e.is_a? Array
      # tokens must match
      return false unless a[0] == e[0]
      if e[2].is_a?(Hash)
        e[2].each {|k,v| return false unless a[1][k] == v }
      end
      return (a[1] == e[1] || (a[1][:value] == e[1]))
    end
    false
  end
end
