module Spec
  module Expectations
    module Should
      class Base
        
        #== and =~ will stay after the new syntax
        def ==(expected)
          __delegate_method_missing_to_target "==", "==", expected
        end
        
        def =~(expected)
          __delegate_method_missing_to_target "=~", "=~", expected
        end
        
        #<, <=, >=, > are all implemented in Spec::Matchers::Be
        # and will be removed with 0.9
        deprecated do
          def <(expected)
            __delegate_method_missing_to_target "<", "<", expected
          end
        
          def <=(expected)
            __delegate_method_missing_to_target "<=", "<=", expected
          end
        
          def >=(expected)
            __delegate_method_missing_to_target ">=", ">=", expected
          end
        
          def >(expected)
            __delegate_method_missing_to_target ">", ">", expected
          end
        end

        def default_message(expectation, expected=nil)
          return "expected #{expected.inspect}, got #{@target.inspect} (using #{expectation})" if expectation == '=='
          "expected #{expectation} #{expected.inspect}, got #{@target.inspect}" unless expectation == '=='
        end

        def fail_with_message(message, expected=nil, target=nil)
          Spec::Expectations.fail_with(message, expected, target)
        end
    
        def find_supported_sym(original_sym)
          ["#{original_sym}?", "#{original_sym}s?"].each do |alternate_sym|
            return alternate_sym.to_s if @target.respond_to?(alternate_sym.to_s)
          end
        end

        deprecated do
          def method_missing(original_sym, *args, &block)
            if original_sym.to_s =~ /^not_/
              return Not.new(@target).__send__(sym, *args, &block)
            end
            if original_sym.to_s =~ /^have_/
              return have.__send__(original_sym.to_s[5..-1].to_sym, *args, &block)
            end
            __delegate_method_missing_to_target original_sym, find_supported_sym(original_sym), *args
          end
        end
      end
    end
  end
end
