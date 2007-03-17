deprecated do
module Spec
  module Expectations
    # This module adds syntactic sugar that allows usage of should_* instead of should.*
    module UnderscoreSugar
      def handle_underscores_for_rspec!  # :nodoc:
        original_method_missing = instance_method(:method_missing)
        class_eval do
          def method_missing(sym, *args, &block)
            _method_missing(sym, args, block)
          end

          define_method :_method_missing do |sym, args, block|
            return original_method_missing.bind(self).call(sym, *args, &block) unless sym.to_s =~ /^should_/
            if sym.to_s =~ /^should_not_/
              if __matcher.respond_to?(__strip_should_not(sym))
                return should_not(__matcher.__send__(__strip_should_not(sym), *args, &block))
              else
                return Spec::Expectations::Should::Not.new(self).__send__(__strip_should_not(sym), *args, &block) if sym.to_s =~ /^should_not_/
              end
            else
              if __matcher.respond_to?(__strip_should(sym))
                return should(__matcher.__send__(__strip_should(sym), *args, &block))
              else
                return Spec::Expectations::Should::Should.new(self).__send__(__strip_should(sym), *args, &block)
              end
            end
          end
          
          def __strip_should(sym) # :nodoc
            sym.to_s[7..-1]
          end
          
          def __strip_should_not(sym) # :nodoc
            sym.to_s[11..-1]
          end
          
          def __matcher
            @matcher ||= Spec::Matchers::Matcher.new
          end
        end
      end
    end
  end
end

end