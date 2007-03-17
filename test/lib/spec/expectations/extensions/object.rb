module Spec
  module Expectations
    # rspec adds #should and #should_not to every Object (and,
    # implicitly, every Class).
    module ObjectExpectations

      # :call-seq:
      #   should(matcher)
      #   should == expected
      #   should =~ expected
      #
      #   receiver.should(matcher)
      #     => Passes if matcher.matches?(receiver)
      #
      #   receiver.should == expected #any value
      #     => Passes if (receiver == expected)
      #
      #   receiver.should =~ regexp
      #     => Passes if (receiver =~ regexp)
      #
      # See Spec::Matchers for more information about matchers
      #
      # == Warning
      #
      # NOTE that this does NOT support receiver.should != expected.
      # Instead, use receiver.should_not == expected
      def should(matcher=nil, &block)
        return ExpectationMatcherHandler.handle_matcher(self, matcher, &block) if matcher
        Should::Should.new(self)
      end

      # :call-seq:
      #   should_not(matcher)
      #   should_not == expected
      #   should_not =~ expected
      #
      #   receiver.should_not(matcher)
      #     => Passes unless matcher.matches?(receiver)
      #
      #   receiver.should_not == expected
      #     => Passes unless (receiver == expected)
      #
      #   receiver.should_not =~ regexp
      #     => Passes unless (receiver =~ regexp)
      #
      # See Spec::Matchers for more information about matchers
      def should_not(matcher=nil, &block)
        return NegativeExpectationMatcherHandler.handle_matcher(self, matcher, &block) if matcher
        should.not
      end

      deprecated do
        # Deprecated: use should have(n).items (see Spec::Matchers)
        # This will be removed in 0.9
        def should_have(expected)
          should.have(expected)
        end
        alias_method :should_have_exactly, :should_have

        # Deprecated: use should have_at_least(n).items (see Spec::Matchers)
        # This will be removed in 0.9
        def should_have_at_least(expected)
          should.have.at_least(expected)
        end
      
        # Deprecated: use should have_at_most(n).items (see Spec::Matchers)
        # This will be removed in 0.9
        def should_have_at_most(expected)
          should.have.at_most(expected)
        end

        # Deprecated: use should include(expected) (see Spec::Matchers)
        # This will be removed in 0.9
        def should_include(expected)
          should.include(expected)
        end

        # Deprecated: use should_not include(expected) (see Spec::Matchers)
        # This will be removed in 0.9
        def should_not_include(expected)
          should.not.include(expected)
        end

        # Deprecated: use should be(expected) (see Spec::Matchers)
        # This will be removed in 0.9
        def should_be(expected = :___no_arg)
          should.be(expected)
        end
      
        # Deprecated: use should_not be(expected) (see Spec::Matchers)
        # This will be removed in 0.9
        def should_not_be(expected = :___no_arg)
          should_not.be(expected)
        end
      end
    end
  end
end

class Object
  include Spec::Expectations::ObjectExpectations
  deprecated do
    include Spec::Expectations::UnderscoreSugar
  end
end

deprecated do
  Object.handle_underscores_for_rspec!
end