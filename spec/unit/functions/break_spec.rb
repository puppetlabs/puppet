require 'spec_helper'

require 'puppet_spec/compiler'
require 'matchers/resource'

describe 'the break function' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  context  do
    it 'breaks iteration as if at end of input in a map for an array' do
      expect(compile_to_catalog(<<-CODE)).to have_resource('Notify[[1, 2]]')
          function please_break() {
            [1,2,3].map |$x| { if $x == 3 { break() } $x }
          }
          notify { String(please_break()): }
        CODE
    end

    it 'breaks iteration as if at end of input in a map for a hash' do
      expect(compile_to_catalog(<<-CODE)).to have_resource('Notify[[1, 2]]')
          function please_break() {
            {'a' => 1, 'b' => 2, 'c' => 3}.map |$x, $y| { if $y == 3 { break() } $y }
          }
          notify { String(please_break()): }
        CODE
    end

    it 'breaks iteration as if at end of input in a reduce for an array' do
      expect(compile_to_catalog(<<-CODE)).to have_resource('Notify[6]')
          function please_break() {
            [1,2,3,4].reduce |$memo, $x| { if $x == 4 { break() } $memo + $x }
          }
          notify { String(please_break()): }
        CODE
    end

    it 'breaks iteration as if at end of input in a reduce for a hash' do
      expect(compile_to_catalog(<<-CODE)).to have_resource("Notify[['abc', 6]]")
          function please_break() {
            {'a' => 1, 'b' => 2, 'c' => 3, 'd' => 4}.reduce |$memo, $x| {
	      if $x[1] == 4 { break() }
              $string = "${memo[0]}${x[0]}"
              $number = $memo[1] + $x[1]
	      [$string, $number]
	    }
          }
          notify { String(please_break()): }
        CODE
    end

    it 'breaks iteration as if at end of input in an each for an array' do
      expect(compile_to_catalog(<<-CODE)).to_not have_resource('Notify[3]')
          function please_break() {
            [1,2,3].each |$x| { if $x == 3 { break() } notify { "$x": } }
          }
          please_break()
        CODE
    end

    it 'breaks iteration as if at end of input in an each for a hash' do
      expect(compile_to_catalog(<<-CODE)).to_not have_resource('Notify[3]')
          function please_break() {
            {'a' => 1, 'b' => 2, 'c' => 3}.each |$x, $y| { if $y == 3 { break() } notify { "$y": } }
          }
          please_break()
        CODE
    end

    it 'breaks iteration as if at end of input in a reverse_each' do
      expect(compile_to_catalog(<<-CODE)).to have_resource('Notify[2]')
          function please_break() {
            [1,2,3].reverse_each |$x| { if $x == 1 { break() } notify { "$x": } }
          }
          please_break()
        CODE
    end

    it 'breaks iteration as if at end of input in a map for a hash' do
      expect(compile_to_catalog(<<-CODE)).to have_resource('Notify[[1, 2]]')
          function please_break() {
            {'a' => 1, 'b' => 2, 'c' => 3}.map |$x, $y| { if $y == 3 { break() } $y }
          }
          notify { String(please_break()): }
        CODE
    end

    it 'breaks iteration as if at end of input in a reduce for an array' do
      expect(compile_to_catalog(<<-CODE)).to have_resource('Notify[6]')
          function please_break() {
            [1,2,3,4].reduce |$memo, $x| { if $x == 4 { break() } $memo + $x }
          }
          notify { String(please_break()): }
        CODE
    end

    it 'breaks iteration as if at end of input in a reduce for a hash' do
      expect(compile_to_catalog(<<-CODE)).to have_resource("Notify[['abc', 6]]")
          function please_break() {
            {'a' => 1, 'b' => 2, 'c' => 3, 'd' => 4}.reduce |$memo, $x| {
              if $x[1] == 4 { break() }
              $string = "${memo[0]}${x[0]}"
              $number = $memo[1] + $x[1]
              [$string, $number]
            }
          }
          notify { String(please_break()): }
        CODE
    end

    it 'breaks iteration as if at end of input in an each for an array' do
      expect(compile_to_catalog(<<-CODE)).to_not have_resource('Notify[3]')
          function please_break() {
            [1,2,3].each |$x| { if $x == 3 { break() } notify { "$x": } }
          }
          please_break()
        CODE
    end

    it 'breaks iteration as if at end of input in an each for a hash' do
      expect(compile_to_catalog(<<-CODE)).to_not have_resource('Notify[3]')
          function please_break() {
            {'a' => 1, 'b' => 2, 'c' => 3}.each |$x, $y| { if $y == 3 { break() } notify { "$y": } }
          }
          please_break()
        CODE
    end

    it 'breaks iteration as if at end of input in a reverse_each' do
      expect(compile_to_catalog(<<-CODE)).to have_resource('Notify[2]')
          function please_break() {
            [1,2,3].reverse_each |$x| { if $x == 1 { break() } notify { "$x": } }
          }
          please_break()
        CODE
    end

    it 'does not provide early exit from a class' do
      # A break would semantically mean that the class should not be included - as if the
      # iteration over class names should stop. That is too magic and should
      # be done differently by the user.
      #
      expect do
        compile_to_catalog(<<-CODE)
          class does_break {
            notice 'a'
            if 1 == 1 { break() } # avoid making next line statically unreachable
            notice 'b'
          }
          include(does_break)
        CODE
      end.to raise_error(/break\(\) from context where this is illegal \(file: unknown, line: 3\) on node.*/)
    end

    it 'does not provide early exit from a define' do
      # A break would semantically mean that the resource should not be created - as if the
      # iteration over resource titles should stop. That is too magic and should
      # be done differently by the user.
      #
      expect do
        compile_to_catalog(<<-CODE)
          define does_break {
            notice 'a'
            if 1 == 1 { break() } # avoid making next line statically unreachable
            notice 'b'
          }
            does_break { 'no_you_cannot': }
        CODE
      end.to raise_error(/break\(\) from context where this is illegal \(file: unknown, line: 3\) on node.*/)
    end

    it 'can be called when nested in a function to make that function behave as a break' do
      # This allows functions like break_when(...) to be implemented by calling break() conditionally
      #
      expect(eval_and_collect_notices(<<-CODE)).to eql(['[100]'])
        function nested_break($x) {
          if $x == 2 { break() } else { $x * 100 }
        }
        function example() {
          [1,2,3].map |$x| { nested_break($x)  }
        }
        notice example()
        CODE
    end

    it 'can not be called nested from top scope' do
      expect do
        compile_to_catalog(<<-CODE)
          # line 1
          # line 2
          $result = with(1) |$x| { with($x) |$x| {break() }}
          notice $result
        CODE
      end.to raise_error(/break\(\) from context where this is illegal \(file: unknown, line: 3\) on node.*/)
    end

    it 'can not be called from top scope' do
      expect do
        compile_to_catalog(<<-CODE)
          # line 1
          # line 2
          break()
        CODE
      end.to raise_error(/break\(\) from context where this is illegal \(file: unknown, line: 3\) on node.*/)
    end
  end
end
