module Spec
  module Runner
    # Parses a spec file and finds the nearest spec for a given line number.
    class SpecParser
      def spec_name_for(io, line_number)
        source  = io.read
        context = context_at_line(source, line_number)
        spec    = spec_at_line(source, line_number)
        if context && spec
          "#{context} #{spec}"
        elsif context
          context
        else
          nil
        end
      end

    protected

      def context_at_line(source, line_number)
        find_above(source, line_number, /^\s*context\s+['|"](.*)['|"]/)
      end

      def spec_at_line(source, line_number)
        find_above(source, line_number, /^\s*specify\s+['|"](.*)['|"]/)
      end

      def find_above(source, line_number, pattern)
        lines_above_reversed(source, line_number).each do |line| 
          return $1 if line =~ pattern
        end
        nil
      end

      def lines_above_reversed(source, line_number)
        lines = source.split("\n")
      	lines[0...line_number].reverse
      end
    end
  end
end