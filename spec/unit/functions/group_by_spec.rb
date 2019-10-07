require 'spec_helper'

require 'puppet_spec/compiler'
require 'matchers/resource'

describe 'the group_by function' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  context 'for an array' do
    it 'groups by item' do
      manifest = "notify { String(group_by([a, b, ab]) |$s| { $s.length }): }"
      expect(compile_to_catalog(manifest)).to have_resource("Notify[{1 => ['a', 'b'], 2 => ['ab']}]")
    end

    it 'groups by index, item' do
      manifest = "notify { String(group_by([a, b, ab]) |$i, $s| { $i%2 + $s.length }): }"
      expect(compile_to_catalog(manifest)).to have_resource("Notify[{1 => ['a'], 2 => ['b', 'ab']}]")
    end
  end

  context 'for a hash' do
    it 'groups by key-value pair' do
      manifest = "notify { String(group_by(a => [1, 2], b => [1]) |$kv| { $kv[1].length }): }"
      expect(compile_to_catalog(manifest)).to have_resource("Notify[{2 => [['a', [1, 2]]], 1 => [['b', [1]]]}]")
    end

    it 'groups by key, value' do
      manifest = "notify { String(group_by(a => [1, 2], b => [1]) |$k, $v| { $v.length }): }"
      expect(compile_to_catalog(manifest)).to have_resource("Notify[{2 => [['a', [1, 2]]], 1 => [['b', [1]]]}]")
    end
  end

  context 'for a string' do
    it 'fails' do
      manifest = "notify { String(group_by('something') |$s| { $s.length }): }"
      expect { compile_to_catalog(manifest) }.to raise_error(Puppet::PreformattedError)
    end
  end
end
