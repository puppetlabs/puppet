module SafeYAML
  class Transform
    class ToInteger
      MATCHERS = Deep.freeze([
        /\A[-+]?(0|([1-9][0-9_,]*))\Z/, # decimal
        /\A0[0-7]+\Z/,                  # octal
        /\A0x[0-9a-f]+\Z/i,             # hexadecimal
        /\A0b[01_]+\Z/                  # binary
      ])

      def transform?(value)
        MATCHERS.each do |matcher|
          return true, Integer(value.gsub(",", "")) if matcher.match(value)
        end
        try_edge_cases?(value)
      end

      def try_edge_cases?(value)
        return true, Parse::Hexadecimal.value(value) if Parse::Hexadecimal::MATCHER.match(value)
        return true, Parse::Sexagesimal.value(value) if Parse::Sexagesimal::INTEGER_MATCHER.match(value)
        return false
      end
    end
  end
end
