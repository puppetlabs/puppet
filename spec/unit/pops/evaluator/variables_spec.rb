#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'
require 'puppet/pops/evaluator/evaluator_impl'


# This file contains basic testing of variable references and assignments
# using a top scope and a local scope.
# It does not test variables and named scopes.
#

# relative to this spec file (./) does not work as this file is loaded by rspec
require File.join(File.dirname(__FILE__), '/evaluator_rspec_helper')

describe 'Puppet::Pops::Impl::EvaluatorImpl' do
  include EvaluatorRspecHelper

  context "When the evaluator deals with variables" do
    context "it should handle" do
      it "simple assignment and dereference" do
        evaluate_l(block( var('a').set(literal(2)+literal(2)), var('a'))).should == 4
      end

      it "local scope shadows top scope" do
        top_scope_block   = block( var('a').set(literal(2)+literal(2)), var('a'))
        local_scope_block = block( var('a').set(var('a') + literal(2)), var('a'))
        evaluate_l(top_scope_block, local_scope_block).should == 6
      end

      it "shadowed in local does not affect parent scope" do
        top_scope_block   = block( var('a').set(literal(2)+literal(2)), var('a'))
        local_scope_block = block( var('a').set(var('a') + literal(2)), var('a'))
        top_scope_again = var('a')
        evaluate_l(top_scope_block, local_scope_block, top_scope_again).should == 4
      end

      it "access to global names works in top scope" do
        top_scope_block   = block( var('a').set(literal(2)+literal(2)), var('::a'))
        evaluate_l(top_scope_block).should == 4
      end

      it "access to global names works in local scope" do
        top_scope_block     = block( var('a').set(literal(2)+literal(2)))
        local_scope_block   = block( var('a').set(var('::a')+literal(2)), var('::a'))
        evaluate_l(top_scope_block, local_scope_block).should == 6
      end

      it "can not change a variable value in same scope" do
        expect { evaluate_l(block(var('a').set(10), var('a').set(20))) }.to raise_error(/Cannot reassign variable a/)
      end

      context "-= operations" do
        # Also see collections_ops_spec.rb where delete via - is fully tested, here only the
        # the -= operation itself is tested (there are many combinations)
        #
        it 'deleting from non existing value produces :undef, nil -= ?' do
          top_scope_block = var('b').set([1,2,3])
          local_scope_block = block(var('a').minus_set([4]), fqn('a').var)
          evaluate_l(top_scope_block, local_scope_block).should == :undef
        end

        it 'deletes from a list' do
          top_scope_block = var('a').set([1,2,3])
          local_scope_block = block(var('a').minus_set([2]), fqn('a').var())
          evaluate_l(top_scope_block, local_scope_block).should == [1,3]
        end

        it 'deletes from a hash' do
          top_scope_block = var('a').set({'a'=>1,'b'=>2,'c'=>3})
          local_scope_block = block(var('a').minus_set('b'), fqn('a').var())
          evaluate_l(top_scope_block, local_scope_block).should == {'a'=>1,'c'=>3}
        end
      end

      context "+= operations" do
        # Also see collections_ops_spec.rb where concatenation via + is fully tested
        it "appending to non existing value, nil += []" do
          top_scope_block = var('b').set([1,2,3])
          local_scope_block = var('a').plus_set([4])
          evaluate_l(top_scope_block, local_scope_block).should == [4]
        end

        context "appending to list" do
          it "from list, [] += []" do
            top_scope_block = var('a').set([1,2,3])
            local_scope_block = block(var('a').plus_set([4]), fqn('a').var())
            evaluate_l(top_scope_block, local_scope_block).should == [1,2,3,4]
          end

          it "from hash, [] += {a=>b}" do
            top_scope_block = var('a').set([1,2,3])
            local_scope_block = block(var('a').plus_set({'a' => 1, 'b'=>2}), fqn('a').var())
            evaluate_l(top_scope_block, local_scope_block).should satisfy {|result|
              # hash in 1.8.7 is not insertion order preserving, hence this hoop
             result == [1,2,3,['a',1],['b',2]] || result == [1,2,3,['b',2],['a',1]]
            }
          end

          it "from single value, [] += x" do
            top_scope_block = var('a').set([1,2,3])
            local_scope_block = block(var('a').plus_set(4), fqn('a').var())
            evaluate_l(top_scope_block, local_scope_block).should == [1,2,3,4]
          end

          it "from embedded list, [] += [[x]]" do
            top_scope_block = var('a').set([1,2,3])
            local_scope_block = block(var('a').plus_set([[4,5]]), fqn('a').var())
            evaluate_l(top_scope_block, local_scope_block).should == [1,2,3,[4,5]]
          end
        end

        context "appending to hash" do
          it "from hash, {a=>b} += {x=>y}" do
            top_scope_block = var('a').set({'a' => 1, 'b' => 2})
            local_scope_block = block(var('a').plus_set({'c' => 3}), fqn('a').var())
            evaluate_l(top_scope_block, local_scope_block) do |scope|
              # Assert no change to top scope hash
              scope['a'].should == {'a' =>1, 'b'=> 2}
            end.should == {'a' => 1, 'b' => 2, 'c' => 3}
          end

          it "from list, {a=>b} += ['x', y]" do
            top_scope_block = var('a').set({'a' => 1, 'b' => 2})
            local_scope_block = block(var('a').plus_set(['c', 3]), fqn('a').var())
            evaluate_l(top_scope_block, local_scope_block) do |scope|
              # Assert no change to top scope hash
              scope['a'].should == {'a' =>1, 'b'=> 2}
            end.should == {'a' => 1, 'b' => 2, 'c' => 3}
          end

          it "with overwrite from hash, {a=>b} += {a=>c}" do
            top_scope_block = var('a').set({'a' => 1, 'b' => 2})
            local_scope_block = block(var('a').plus_set({'b' => 4, 'c' => 3}),fqn('a').var())
            evaluate_l(top_scope_block, local_scope_block) do |scope|
              # Assert no change to top scope hash
              scope['a'].should == {'a' =>1, 'b'=> 2}
            end.should == {'a' => 1, 'b' => 4, 'c' => 3}
          end

          it "with overwrite from list, {a=>b} += ['a', c]" do
            top_scope_block = var('a').set({'a' => 1, 'b' => 2})
            local_scope_block = block(var('a').plus_set(['b', 4, 'c', 3]), fqn('a').var())
            evaluate_l(top_scope_block, local_scope_block) do |scope|
              # Assert no change to topscope hash
              scope['a'].should == {'a' =>1, 'b'=> 2}
            end.should == {'a' => 1, 'b' => 4, 'c' => 3}
          end

          it "from odd length array - error" do
            top_scope_block = var('a').set({'a' => 1, 'b' => 2})
            local_scope_block = var('a').plus_set(['b', 4, 'c'])
            expect { evaluate_l(top_scope_block, local_scope_block) }.to raise_error(/Append assignment \+= failed with error: odd number of arguments for Hash/)
          end
        end
      end

      context "access to numeric variables" do
        it "without a match" do
          evaluate_l(block(literal(2) + literal(2),
            [var(0), var(1), var(2), var(3)])).should == [nil, nil, nil, nil]
        end

        it "after a match" do
          evaluate_l(block(literal('abc') =~ literal(/(a)(b)(c)/),
            [var(0), var(1), var(2), var(3)])).should == ['abc', 'a', 'b', 'c']
        end

        it "after a failed match" do
          evaluate_l(block(literal('abc') =~ literal(/(x)(y)(z)/),
            [var(0), var(1), var(2), var(3)])).should == [nil, nil, nil, nil]
        end

        it "a failed match does not alter previous match" do
          evaluate_l(block(
            literal('abc') =~ literal(/(a)(b)(c)/),
            literal('abc') =~ literal(/(x)(y)(z)/),
            [var(0), var(1), var(2), var(3)])).should == ['abc', 'a', 'b', 'c']
        end

        it "a new match completely shadows previous match" do
          evaluate_l(block(
            literal('abc') =~ literal(/(a)(b)(c)/),
            literal('abc') =~ literal(/(a)bc/),
            [var(0), var(1), var(2), var(3)])).should == ['abc', 'a', nil, nil]
        end

        it "after a match with variable referencing a non existing group" do
          evaluate_l(block(literal('abc') =~ literal(/(a)(b)(c)/),
            [var(0), var(1), var(2), var(3), var(4)])).should == ['abc', 'a', 'b', 'c', nil]
        end
      end
    end
  end
end
