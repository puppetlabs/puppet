require 'spec_helper'

require 'puppet_spec/compiler'
require 'matchers/resource'

describe 'the return function' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  context 'returns from outer function when called from nested block' do
    it 'with a given value as function result' do
      expect(compile_to_catalog(<<-CODE)).to have_resource('Notify[100]')
          function please_return() {
            [1,2,3].map |$x| { if $x == 1 { return(100) } 200 }
            300
          }
          notify { String(please_return()): }
        CODE
    end

    it 'with undef value as function result when not given an argument' do
      expect(compile_to_catalog(<<-CODE)).to have_resource('Notify[xy]')
          function please_return() {
            [1,2,3].map |$x| { if $x == 1 { return() } 200 }
            300
          }
          notify { "x${please_return}y": }
        CODE
    end
  end

  it 'can be called without parentheses around the argument' do
    expect(compile_to_catalog(<<-CODE)).to have_resource('Notify[100]')
        function please_return() {
          if 1 == 1 { return 100 }
          200
        }
        notify { String(please_return()): }
      CODE
  end

  it 'provides early exit from a class and keeps the class' do
    expect(eval_and_collect_notices(<<-CODE)).to eql(['a', 'c', 'true', 'true'])
        class notices_c { notice 'c' }
        class does_next {
          notice 'a'
          if 1 == 1 { return() } # avoid making next line statically unreachable
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
          if 1 == 1 { return() } # avoid making next line statically unreachable
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

  it 'can be called when nested in a function to make that function return' do
    expect(eval_and_collect_notices(<<-CODE)).to eql(['100'])
      function nested_return() {
        with(1) |$x| { with($x) |$x| {return(100) }}
      }
      notice nested_return()
      CODE
  end

  it 'can not be called nested from top scope' do
    expect do
      compile_to_catalog(<<-CODE)
        # line 1
        # line 2
        $result = with(1) |$x| { with($x) |$x| {return(100) }}
        notice $result
      CODE
    end.to raise_error(/return\(\) from context where this is illegal \(file: unknown, line: 3\) on node.*/)
  end

  it 'can not be called from top scope' do
    expect do
      compile_to_catalog(<<-CODE)
        # line 1
        # line 2
        return()
      CODE
    end.to raise_error(/return\(\) from context where this is illegal \(file: unknown, line: 3\) on node.*/)
  end
end
