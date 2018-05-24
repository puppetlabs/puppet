require 'spec_helper'

require 'puppet_spec/compiler'
require 'matchers/resource'

describe 'the size function' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  context 'for an array it' do
    it 'returns 0 when empty' do
      expect(compile_to_catalog("notify { String(size([])): }")).to have_resource('Notify[0]')
    end

    it 'returns number of elements when not empty' do
      expect(compile_to_catalog("notify { String(size([1, 2, 3])): }")).to have_resource('Notify[3]')
    end
  end

  context 'for a hash it' do
    it 'returns 0 empty' do
      expect(compile_to_catalog("notify { String(size({})): }")).to have_resource('Notify[0]')
    end

    it 'returns number of elements when not empty' do
      expect(compile_to_catalog("notify { String(size({1=>1,2=>2})): }")).to have_resource('Notify[2]')
    end
  end

  context 'for a string it' do
    it 'returns 0 when empty' do
      expect(compile_to_catalog("notify { String(size('')): }")).to have_resource('Notify[0]')
    end

    it 'returns number of characters when not empty' do
      # note the multibyte characters - åäö each taking two bytes in UTF-8
      expect(compile_to_catalog('notify { String(size("\u00e5\u00e4\u00f6")): }')).to have_resource('Notify[3]')
    end
  end

  context 'for a binary it' do
    it 'returns 0 when empty' do
      expect(compile_to_catalog("notify { String(size(Binary(''))): }")).to have_resource('Notify[0]')
    end

    it 'returns number of bytes when not empty' do
      expect(compile_to_catalog("notify { String(size(Binary('b25l'))): }")).to have_resource('Notify[3]')
    end
  end
end
