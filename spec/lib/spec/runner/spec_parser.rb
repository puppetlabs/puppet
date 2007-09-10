module Spec
  module Runner
    # Parses a spec file and finds the nearest example for a given line number.
    class SpecParser
      def spec_name_for(io, line_number)
        source  = io.read
        behaviour, behaviour_line = behaviour_at_line(source, line_number)
        example, example_line = example_at_line(source, line_number)
        if behaviour && example && (behaviour_line < example_line)
          "#{behaviour} #{example}"
        elsif behaviour
          behaviour
        else
          nil
        end
      end

    protected

      def behaviour_at_line(source, line_number)
        find_above(source, line_number, /^\s*(context|describe)\s+(.*)\s+do/)
      end

      def example_at_line(source, line_number)
        find_above(source, line_number, /^\s*(specify|it)\s+(.*)\s+do/)
      end

      # Returns the context/describe or specify/it name and the line number
      def find_above(source, line_number, pattern)
        lines_above_reversed(source, line_number).each_with_index do |line, n|
          return [parse_description($2), line_number-n] if line =~ pattern
        end
        nil
      end

      def lines_above_reversed(source, line_number)
        lines = source.split("\n")
        lines[0...line_number].reverse
      end
      
      def parse_description(str)
        return str[1..-2] if str =~ /^['"].*['"]$/
        if matches = /^(.*)\s*,\s*['"](.*)['"]$/.match(str)
          return ::Spec::DSL::Description.generate_description(matches[1], matches[2])
        end
        return str
      end
    end
  end
end
