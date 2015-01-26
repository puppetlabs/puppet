module Matchers; module Include
  extend RSpec::Matchers::DSL

  matcher :include_in_any_order do |*matchers|
    match do |enumerable|
      @not_matched = []
      expected_as_array.each do |matcher|
        if enumerable.empty?
          break
        end

        if found = enumerable.find { |elem| matcher.matches?(elem) }
          enumerable = enumerable.reject { |elem| elem == found }
        else
          @not_matched << matcher
        end
      end


      @not_matched.empty? && enumerable.empty?
    end

    failure_message do |enumerable|
      "did not match #{@not_matched.collect(&:description).join(', ')} in #{enumerable.inspect}: <#{@not_matched.collect(&:failure_message).join('>, <')}>"
    end
  end
end; end
