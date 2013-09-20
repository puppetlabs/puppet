module SafeYAML
  class Parse
    class Date
      def self.value(value)
        Time.parse(value)
      end
    end
  end
end
