require 'spec_helper'

require 'puppet_spec/compiler'
require 'matchers/resource'

describe 'the partition function' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  context 'for an array' do
    it 'partitions by item' do
      manifest = "notify { String(partition(['', b, ab]) |$s| { $s.empty }): }"
      expect(compile_to_catalog(manifest)).to have_resource("Notify[[[''], ['b', 'ab']]]")
    end

    it 'partitions by index, item' do
      manifest = "notify { String(partition(['', b, ab]) |$i, $s| { $i == 2 or $s.empty }): }"
      expect(compile_to_catalog(manifest)).to have_resource("Notify[[['', 'ab'], ['b']]]")
    end
  end

  context 'for a hash' do
    it 'partitions by key-value pair' do
      manifest = "notify { String(partition(a => [1, 2], b => []) |$kv| { $kv[1].empty }): }"
      expect(compile_to_catalog(manifest)).to have_resource("Notify[[[['b', []]], [['a', [1, 2]]]]]")
    end

    it 'partitions by key, value' do
      manifest = "notify { String(partition(a => [1, 2], b => []) |$k, $v| { $v.empty }): }"
      expect(compile_to_catalog(manifest)).to have_resource("Notify[[[['b', []]], [['a', [1, 2]]]]]")
    end
  end

  context 'for a string' do
    it 'fails' do
      manifest = "notify { String(partition('something') |$s| { $s.empty }): }"
      expect { compile_to_catalog(manifest) }.to raise_error(Puppet::PreformattedError)
    end
  end
end
