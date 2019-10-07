require 'spec_helper'

require 'puppet_spec/compiler'
require 'matchers/resource'

describe 'the empty function' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  let(:logs) { [] }
  let(:warnings) { logs.select { |log| log.level == :warning }.map { |log| log.message } }

  context 'for an array it' do
    it 'returns true when empty' do
      expect(compile_to_catalog("notify { String(empty([])): }")).to have_resource('Notify[true]')
    end

    it 'returns false when not empty' do
      expect(compile_to_catalog("notify { String(empty([1])): }")).to have_resource('Notify[false]')
    end
  end

  context 'for a hash it' do
    it 'returns true when empty' do
      expect(compile_to_catalog("notify { String(empty({})): }")).to have_resource('Notify[true]')
    end

    it 'returns false when not empty' do
      expect(compile_to_catalog("notify { String(empty({1=>1})): }")).to have_resource('Notify[false]')
    end
  end

  context 'for numeric values it' do
    it 'always returns false for integer values (including 0)' do
      Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
        expect(compile_to_catalog("notify { String(empty(0)): }")).to have_resource('Notify[false]')
      end
      expect(warnings).to include(/Calling function empty\(\) with Numeric value is deprecated/)
    end

    it 'always returns false for float values (including 0.0)' do
      Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
        expect(compile_to_catalog("notify { String(empty(0.0)): }")).to have_resource('Notify[false]')
      end
      expect(warnings).to include(/Calling function empty\(\) with Numeric value is deprecated/)
    end
  end

  context 'for a string it' do
    it 'returns true when empty' do
      expect(compile_to_catalog("notify { String(empty('')): }")).to have_resource('Notify[true]')
    end

    it 'returns false when not empty' do
      expect(compile_to_catalog("notify { String(empty(' ')): }")).to have_resource('Notify[false]')
    end
  end

  context 'for a binary it' do
    it 'returns true when empty' do
      expect(compile_to_catalog("notify { String(empty(Binary(''))): }")).to have_resource('Notify[true]')
    end

    it 'returns false when not empty' do
      expect(compile_to_catalog("notify { String(empty(Binary('b25l'))): }")).to have_resource('Notify[false]')
    end
  end

  context 'for undef it' do
    it 'returns true without deprecation warning' do
      Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
        expect(compile_to_catalog("notify { String(empty(undef)): }")).to have_resource('Notify[true]')
      end
      expect(warnings).to_not include(/Calling function empty\(\) with Undef value is deprecated/)
    end
  end
end
