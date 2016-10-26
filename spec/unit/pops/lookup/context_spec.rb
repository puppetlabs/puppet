#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/compiler'

module Puppet::Pops
module Lookup
describe 'Puppet::Pops::Lookup::Context' do

  context 'an instance' do
    include PuppetSpec::Compiler
    it 'can be created' do
      code = "notice(type(Puppet::LookupContext.new('e', 'm')))"
      expect(eval_and_collect_notices(code)[0]).to match(/Object\[\{name => 'Puppet::LookupContext'/)
    end

    it 'returns its environment_name' do
      code = "notice(Puppet::LookupContext.new('e', 'm').environment_name)"
      expect(eval_and_collect_notices(code)[0]).to eql('e')
    end

    it 'returns its module_name' do
      code = "notice(Puppet::LookupContext.new('e', 'm').module_name)"
      expect(eval_and_collect_notices(code)[0]).to eql('m')
    end

    it 'can use an undef module_name' do
      code = "notice(type(Puppet::LookupContext.new('e', undef).module_name))"
      expect(eval_and_collect_notices(code)[0]).to eql('Undef')
    end

    it 'can store and retrieve a value using the cache' do
      code = <<-PUPPET.unindent
        $ctx = Puppet::LookupContext.new('e', 'm')
        $ctx.cache('ze_key', 'ze_value')
        notice($ctx.cached_value('ze_key'))
      PUPPET
      expect(eval_and_collect_notices(code)[0]).to eql('ze_value')
    end

    it 'can store and retrieve a hash using the cache' do
      code = <<-PUPPET.unindent
        $ctx = Puppet::LookupContext.new('e', 'm')
        $ctx.cache_all({ 'v1' => 'first', 'v2' => 'second' })
        $ctx.cached_entries |$key, $value| { notice($key); notice($value) }
      PUPPET
      expect(eval_and_collect_notices(code)).to eql(%w(v1 first v2 second))
    end

    it 'can use the cache to merge hashes' do
      code = <<-PUPPET.unindent
        $ctx = Puppet::LookupContext.new('e', 'm')
        $ctx.cache_all({ 'v1' => 'first', 'v2' => 'second' })
        $ctx.cache_all({ 'v3' => 'third', 'v4' => 'fourth' })
        $ctx.cached_entries |$key, $value| { notice($key); notice($value) }
      PUPPET
      expect(eval_and_collect_notices(code)).to eql(%w(v1 first v2 second v3 third v4 fourth))
    end

    it 'can use the cache to merge hashes and individual entries' do
      code = <<-PUPPET.unindent
        $ctx = Puppet::LookupContext.new('e', 'm')
        $ctx.cache_all({ 'v1' => 'first', 'v2' => 'second' })
        $ctx.cache('v3', 'third')
        $ctx.cached_entries |$key, $value| { notice($key); notice($value) }
      PUPPET
      expect(eval_and_collect_notices(code)).to eql(%w(v1 first v2 second v3 third))
    end

    it 'can iterate the cache using one argument block' do
      code = <<-PUPPET.unindent
        $ctx = Puppet::LookupContext.new('e', 'm')
        $ctx.cache_all({ 'v1' => 'first', 'v2' => 'second' })
        $ctx.cached_entries |$entry| { notice($entry[0]); notice($entry[1]) }
      PUPPET
      expect(eval_and_collect_notices(code)).to eql(%w(v1 first v2 second))
    end

    it 'can replace individual cached entries' do
      code = <<-PUPPET.unindent
        $ctx = Puppet::LookupContext.new('e', 'm')
        $ctx.cache_all({ 'v1' => 'first', 'v2' => 'second' })
        $ctx.cache('v2', 'changed')
        $ctx.cached_entries |$key, $value| { notice($key); notice($value) }
      PUPPET
      expect(eval_and_collect_notices(code)).to eql(%w(v1 first v2 changed))
    end

    it 'can replace multiple cached entries' do
      code = <<-PUPPET.unindent
        $ctx = Puppet::LookupContext.new('e', 'm')
        $ctx.cache_all({ 'v1' => 'first', 'v2' => 'second', 'v3' => 'third' })
        $ctx.cache_all({ 'v1' => 'one', 'v3' => 'three' })
        $ctx.cached_entries |$key, $value| { notice($key); notice($value) }
      PUPPET
      expect(eval_and_collect_notices(code)).to eql(%w(v1 one v2 second v3 three))
    end

    it 'cached_entries returns an Iterable when called without a block' do
      code = <<-PUPPET.unindent
        $ctx = Puppet::LookupContext.new('e', 'm')
        $ctx.cache_all({ 'v1' => 'first', 'v2' => 'second' })
        $iter = $ctx.cached_entries
        notice(type($iter, generalized))
        $iter.each |$entry| { notice($entry[0]); notice($entry[1]) }
      PUPPET
      expect(eval_and_collect_notices(code)).to eql(['Iterator[Tuple[String, String, 2, 2]]', 'v1', 'first', 'v2', 'second'])
    end

    it 'will throw :no_such_key when not_found is called' do
      code = <<-PUPPET.unindent
        $ctx = Puppet::LookupContext.new('e', 'm')
        $ctx.not_found
      PUPPET
      expect { eval_and_collect_notices(code) }.to throw_symbol(:no_such_key)
    end

    context 'when used in an Invocation' do
      let(:invocation) { Invocation.new({}) }
      let(:invocation_with_explain) { Invocation.new({}, {}, {}, true) }

      it 'will not call explain unless explanations are active' do
        Invocation.expects(:current).returns(invocation)
        code = <<-PUPPET.unindent
          $ctx = Puppet::LookupContext.new('e', 'm')
          $ctx.explain || { notice('stop calling'); 'bad' }
        PUPPET
        expect(eval_and_collect_notices(code)).to be_empty
      end

      it 'will call explain when explanations are active' do
        Invocation.expects(:current).returns(invocation_with_explain)
        invocation_with_explain.with(:global, 'test') do
          code = <<-PUPPET.unindent
            $ctx = Puppet::LookupContext.new('e', 'm')
            $ctx.explain || { notice('called'); 'good' }
          PUPPET
          expect(eval_and_collect_notices(code)).to eql(['called'])
        end
        expect(invocation_with_explain.explainer.to_s).to eql(<<-TEXT.unindent)
          Data Binding "test"
            good
        TEXT
      end
    end
  end
end
end
end

