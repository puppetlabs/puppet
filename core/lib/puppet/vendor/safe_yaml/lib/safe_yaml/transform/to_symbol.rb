module SafeYAML
  class Transform
    class ToSymbol
      MATCHER = /\A:"?(\w+)"?\Z/.freeze

      def transform?(value, options=nil)
        options ||= SafeYAML::OPTIONS
        return false unless options[:deserialize_symbols] && MATCHER.match(value)
        return true, $1.to_sym
      end
    end
  end
end
