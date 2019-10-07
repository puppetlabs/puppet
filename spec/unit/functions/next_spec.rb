require 'spec_helper'

require 'puppet_spec/compiler'
require 'matchers/resource'

describe 'the next function' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  context 'exits a block yielded to iteratively' do
    it 'with a given value as result for this iteration' do
      expect(compile_to_catalog(<<-CODE)).to have_resource('Notify[[100, 4, 6]]')
          $result = String([1,2,3].map |$x| { if $x == 1 { next(100) } $x*2 })
          notify { $result: }
        CODE
    end

    it 'with undef value as result for this iteration when next is not given an argument' do
      expect(compile_to_catalog(<<-CODE)).to have_resource('Notify[[undef, 4, 6]]')
          $result = String([1,2,3].map |$x| { if $x == 1 { next() } $x*2 })
          notify { $result: }
        CODE
    end
  end

  it 'can be called without parentheses around the argument' do
    expect(compile_to_catalog(<<-CODE)).to have_resource('Notify[[100, 4, 6]]')
        $result = String([1,2,3].map |$x| { if $x == 1 { next 100 } $x*2 })
        notify { $result: }
      CODE
  end

  it 'has the same effect as a return when called from within a block not used in an iteration' do
    expect(compile_to_catalog(<<-CODE)).to have_resource('Notify[100]')
        $result = String(with(1) |$x| { if $x == 1 { next(100) } 200 })
        notify { $result: }
      CODE
  end

  it 'has the same effect as a return when called from within a function' do
    expect(compile_to_catalog(<<-CODE)).to have_resource('Notify[[102, 200, 300]]')
        function do_next() {
          next(100)
        }
        $result = String([1,2,3].map |$x| { if $x == 1 { next do_next()+2 } $x*do_next() })
        notify { $result: }
      CODE
  end

  it 'provides early exit from a class and keeps the class' do
    expect(eval_and_collect_notices(<<-CODE)).to eql(['a', 'c', 'true', 'true'])
        class notices_c { notice 'c' }
        class does_next {
          notice 'a'
          if 1 == 1 { next() } # avoid making next line statically unreachable
          notice 'b'
        }
        # include two classes to check that next does not do an early return from
        # the include function.
        include(does_next, notices_c)
        notice defined(does_next)
        notice defined(notices_c)
      CODE
  end

  it 'provides early exit from a user defined resource and keeps the resource' do
    expect(eval_and_collect_notices(<<-CODE)).to eql(['the_doer_of_next', 'copy_cat', 'true', 'true'])
        define does_next {
          notice $title
          if 1 == 1 { next() } # avoid making next line statically unreachable
          notice 'b'
        }
        define checker {
          notice defined(Does_next['the_doer_of_next'])
          notice defined(Does_next['copy_cat'])
        }
        # create two instances to ensure next does not break the entire
        # resource expression
        does_next { ['the_doer_of_next', 'copy_cat']: }
        checker { 'needed_because_evaluation_order': }
      CODE
  end

  it 'can not be called from top scope' do
    expect do
      compile_to_catalog(<<-CODE)
        # line 1
        # line 2
        next()
      CODE
    end.to raise_error(/next\(\) from context where this is illegal \(file: unknown, line: 3\) on node.*/)
  end
end
