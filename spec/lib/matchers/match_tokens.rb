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
      !e or a[0] == e or (e.is_a? Array and a[0] == e[0] and (a[1] == e[1] or (a[1].is_a?(Hash) and a[1][:value] == e[1])))
    end
  end
  diffable
end
