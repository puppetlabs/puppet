require 'spec_helper'

require 'puppet/pops'

describe 'Puppet::Pops::PuppetStack' do
  class StackTraceTest
    def get_stacktrace
      Puppet::Pops::PuppetStack.stacktrace
    end

    def get_top_of_stack
      Puppet::Pops::PuppetStack.top_of_stack
    end

    def one_level
      Puppet::Pops::PuppetStack.stack("one_level.pp", 1234, self, :get_stacktrace, [])
    end

    def one_level_top
      Puppet::Pops::PuppetStack.stack("one_level.pp", 1234, self, :get_top_of_stack, [])
    end

    def two_levels
      Puppet::Pops::PuppetStack.stack("two_levels.pp", 1237, self, :level2, [])
    end

    def two_levels_top
      Puppet::Pops::PuppetStack.stack("two_levels.pp", 1237, self, :level2_top, [])
    end

    def level2
      Puppet::Pops::PuppetStack.stack("level2.pp", 1240, self, :get_stacktrace, [])
    end

    def level2_top
      Puppet::Pops::PuppetStack.stack("level2.pp", 1240, self, :get_top_of_stack, [])
    end

    def gets_block(a, &block)
      block.call(a)
    end

    def gets_args_and_block(a, b, &block)
      block.call(a, b)
    end

    def with_nil_file
      Puppet::Pops::PuppetStack.stack(nil, 1250, self, :get_stacktrace, [])
    end

    def with_empty_string_file
      Puppet::Pops::PuppetStack.stack('', 1251, self, :get_stacktrace, [])
    end
  end

  it 'returns an empty array from stacktrace when there is nothing on the stack' do
    expect(Puppet::Pops::PuppetStack.stacktrace).to eql([])
  end


  context 'full stacktrace' do
    it 'returns a one element array with file, line from stacktrace when there is one entry on the stack' do
      expect(StackTraceTest.new.one_level).to eql([['one_level.pp', 1234]])
    end

    it 'returns an array from stacktrace with information about each level with oldest frame last' do
      expect(StackTraceTest.new.two_levels).to eql([['level2.pp', 1240], ['two_levels.pp', 1237]])
    end

    it 'returns an empty array from top_of_stack when there is nothing on the stack' do
      expect(Puppet::Pops::PuppetStack.top_of_stack).to eql([])
    end
  end

  context 'top of stack' do
    it 'returns a one element array with file, line from top_of_stack when there is one entry on the stack' do
      expect(StackTraceTest.new.one_level_top).to eql(['one_level.pp', 1234])
    end

    it 'returns newest entry from top_of_stack' do
      expect(StackTraceTest.new.two_levels_top).to eql(['level2.pp', 1240])
    end

    it 'accepts file to be nil' do
      expect(StackTraceTest.new.with_nil_file).to eql([['unknown', 1250]])
    end
  end

  it 'accepts file to be empty_string' do
    expect(StackTraceTest.new.with_empty_string_file).to eql([['unknown', 1251]])
  end

  it 'stacktrace is empty when call has returned' do
    StackTraceTest.new.two_levels
    expect(Puppet::Pops::PuppetStack.stacktrace).to eql([])
  end

  it 'allows passing a block to the stack call' do
    expect(Puppet::Pops::PuppetStack.stack("test.pp", 1, StackTraceTest.new, :gets_block, ['got_it']) {|x| x }).to eql('got_it')
  end

  it 'allows passing multiple variables and a block' do
    expect(
      Puppet::Pops::PuppetStack.stack("test.pp", 1, StackTraceTest.new, :gets_args_and_block, ['got_it', 'again']) {|x, y| [x,y].join(' ')}
      ).to eql('got_it again')
  end

end