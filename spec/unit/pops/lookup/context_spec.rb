#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/files'
require 'puppet_spec/compiler'

module Puppet::Pops
module Lookup
describe 'Puppet::Pops::Lookup::Context' do

  context 'an instance' do
    include PuppetSpec::Compiler
    it 'can be created' do
      code = "notice(type(Puppet::LookupContext.new('m')))"
      expect(eval_and_collect_notices(code)[0]).to match(/Object\[\{name => 'Puppet::LookupContext'/)
    end

    it 'returns its environment_name' do
      code = "notice(Puppet::LookupContext.new('m').environment_name)"
      expect(eval_and_collect_notices(code)[0]).to eql('production')
    end

    it 'returns its module_name' do
      code = "notice(Puppet::LookupContext.new('m').module_name)"
      expect(eval_and_collect_notices(code)[0]).to eql('m')
    end

    it 'can use an undef module_name' do
      code = "notice(type(Puppet::LookupContext.new(undef).module_name))"
      expect(eval_and_collect_notices(code)[0]).to eql('Undef')
    end

    it 'can store and retrieve a value using the cache' do
      code = <<-PUPPET.unindent
        $ctx = Puppet::LookupContext.new('m')
        $ctx.cache('ze_key', 'ze_value')
        notice($ctx.cached_value('ze_key'))
      PUPPET
      expect(eval_and_collect_notices(code)[0]).to eql('ze_value')
    end

    it 'the cache method returns the value that is cached' do
      code = <<-PUPPET.unindent
        $ctx = Puppet::LookupContext.new('m')
        notice($ctx.cache('ze_key', 'ze_value'))
      PUPPET
      expect(eval_and_collect_notices(code)[0]).to eql('ze_value')
    end

    it 'can store and retrieve a hash using the cache' do
      code = <<-PUPPET.unindent
        $ctx = Puppet::LookupContext.new('m')
        $ctx.cache_all({ 'v1' => 'first', 'v2' => 'second' })
        $ctx.cached_entries |$key, $value| { notice($key); notice($value) }
      PUPPET
      expect(eval_and_collect_notices(code)).to eql(%w(v1 first v2 second))
    end

    it 'can use the cache to merge hashes' do
      code = <<-PUPPET.unindent
        $ctx = Puppet::LookupContext.new('m')
        $ctx.cache_all({ 'v1' => 'first', 'v2' => 'second' })
        $ctx.cache_all({ 'v3' => 'third', 'v4' => 'fourth' })
        $ctx.cached_entries |$key, $value| { notice($key); notice($value) }
      PUPPET
      expect(eval_and_collect_notices(code)).to eql(%w(v1 first v2 second v3 third v4 fourth))
    end

    it 'can use the cache to merge hashes and individual entries' do
      code = <<-PUPPET.unindent
        $ctx = Puppet::LookupContext.new('m')
        $ctx.cache_all({ 'v1' => 'first', 'v2' => 'second' })
        $ctx.cache('v3', 'third')
        $ctx.cached_entries |$key, $value| { notice($key); notice($value) }
      PUPPET
      expect(eval_and_collect_notices(code)).to eql(%w(v1 first v2 second v3 third))
    end

    it 'can iterate the cache using one argument block' do
      code = <<-PUPPET.unindent
        $ctx = Puppet::LookupContext.new('m')
        $ctx.cache_all({ 'v1' => 'first', 'v2' => 'second' })
        $ctx.cached_entries |$entry| { notice($entry[0]); notice($entry[1]) }
      PUPPET
      expect(eval_and_collect_notices(code)).to eql(%w(v1 first v2 second))
    end

    it 'can replace individual cached entries' do
      code = <<-PUPPET.unindent
        $ctx = Puppet::LookupContext.new('m')
        $ctx.cache_all({ 'v1' => 'first', 'v2' => 'second' })
        $ctx.cache('v2', 'changed')
        $ctx.cached_entries |$key, $value| { notice($key); notice($value) }
      PUPPET
      expect(eval_and_collect_notices(code)).to eql(%w(v1 first v2 changed))
    end

    it 'can replace multiple cached entries' do
      code = <<-PUPPET.unindent
        $ctx = Puppet::LookupContext.new('m')
        $ctx.cache_all({ 'v1' => 'first', 'v2' => 'second', 'v3' => 'third' })
        $ctx.cache_all({ 'v1' => 'one', 'v3' => 'three' })
        $ctx.cached_entries |$key, $value| { notice($key); notice($value) }
      PUPPET
      expect(eval_and_collect_notices(code)).to eql(%w(v1 one v2 second v3 three))
    end

    it 'cached_entries returns an Iterable when called without a block' do
      code = <<-PUPPET.unindent
        $ctx = Puppet::LookupContext.new('m')
        $ctx.cache_all({ 'v1' => 'first', 'v2' => 'second' })
        $iter = $ctx.cached_entries
        notice(type($iter, generalized))
        $iter.each |$entry| { notice($entry[0]); notice($entry[1]) }
      PUPPET
      expect(eval_and_collect_notices(code)).to eql(['Iterator[Tuple[String, String, 2, 2]]', 'v1', 'first', 'v2', 'second'])
    end

    it 'will throw :no_such_key when not_found is called' do
      code = <<-PUPPET.unindent
        $ctx = Puppet::LookupContext.new('m')
        $ctx.not_found
      PUPPET
      expect { eval_and_collect_notices(code) }.to throw_symbol(:no_such_key)
    end

    context 'with cached_file_data' do
      include PuppetSpec::Files

      let(:code_dir) { Puppet[:environmentpath] }
      let(:env_name) { 'testing' }
      let(:env_dir) { File.join(code_dir, env_name) }
      let(:env) { Puppet::Node::Environment.create(env_name.to_sym, [File.join(populated_env_dir, 'modules')]) }
      let(:node) { Puppet::Node.new('test', :environment => env) }
      let(:data_yaml) { 'data.yaml' }
      let(:data_path) { File.join(populated_env_dir, 'data', data_yaml) }
      let(:populated_env_dir) do
        dir_contained_in(code_dir,
          {
            env_name => {
              'data' => {
                data_yaml => <<-YAML.unindent
                  a: value a
                  YAML
              }
            }
          }
        )
        PuppetSpec::Files.record_tmp(File.join(env_dir))
        env_dir
      end

      it 'can use cached_file_data without a block' do
        code = <<-PUPPET.unindent
          $ctx = Puppet::LookupContext.new(nil)
          $yaml_data = $ctx.cached_file_data('#{data_path}')
          notice($yaml_data)
        PUPPET
        expect(eval_and_collect_notices(code, node)).to eql(["a: value a\n"])
      end

      it 'can use cached_file_data with a block' do
        code = <<-PUPPET.unindent
          $ctx = Puppet::LookupContext.new(nil)
          $yaml_data = $ctx.cached_file_data('#{data_path}') |$content| {
            { 'parsed' => $content }
          }
          notice($yaml_data)
        PUPPET
        expect(eval_and_collect_notices(code, node)).to eql(["{parsed => a: value a\n}"])
      end

      context 'and multiple compilations' do

        before(:each) { Puppet.settings[:environment_timeout] = 'unlimited' }

        it 'will reuse cached_file_data and not call block again' do

          code1 = <<-PUPPET.unindent
            $ctx = Puppet::LookupContext.new(nil)
            $yaml_data = $ctx.cached_file_data('#{data_path}') |$content| {
              { 'parsed' => $content }
            }
            notice($yaml_data)
            PUPPET

          code2 = <<-PUPPET.unindent
            $ctx = Puppet::LookupContext.new(nil)
            $yaml_data = $ctx.cached_file_data('#{data_path}') |$content| {
              { 'parsed' => 'should not be called' }
            }
            notice($yaml_data)
            PUPPET

          logs = []
          Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
            Puppet[:code] = code1
            Puppet::Parser::Compiler.compile(node)
            Puppet[:code] = code2
            Puppet::Parser::Compiler.compile(node)
          end
          logs = logs.select { |log| log.level == :notice }.map { |log| log.message }
          expect(logs.uniq.size).to eql(1)
        end

        it 'will invalidate cache if file changes size' do
          code = <<-PUPPET.unindent
            $ctx = Puppet::LookupContext.new(nil)
            $yaml_data = $ctx.cached_file_data('#{data_path}') |$content| {
              { 'parsed' => $content }
            }
            notice($yaml_data)
            PUPPET

          logs = []
          Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
            Puppet[:code] = code
            Puppet::Parser::Compiler.compile(node)

            # Change content size!
            File.write(data_path, "a: value is now A\n")
            Puppet::Parser::Compiler.compile(node)
          end
          logs = logs.select { |log| log.level == :notice }.map { |log| log.message }
          expect(logs).to eql(["{parsed => a: value a\n}", "{parsed => a: value is now A\n}"])
        end

        it 'will invalidate cache if file changes mtime' do
          old_mtime = Puppet::FileSystem.stat(data_path).mtime

          code = <<-PUPPET.unindent
            $ctx = Puppet::LookupContext.new(nil)
            $yaml_data = $ctx.cached_file_data('#{data_path}') |$content| {
              { 'parsed' => $content }
            }
            notice($yaml_data)
          PUPPET

          logs = []
          Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
            Puppet[:code] = code
            Puppet::Parser::Compiler.compile(node)

            # Write content with the same size
            File.write(data_path, "a: value b\n")

            # Ensure mtime is at least 1 second ahead
            FileUtils.touch(data_path, :mtime => old_mtime + 1)

            Puppet::Parser::Compiler.compile(node)
          end
          logs = logs.select { |log| log.level == :notice }.map { |log| log.message }
          expect(logs).to eql(["{parsed => a: value a\n}", "{parsed => a: value b\n}"])
        end

        it 'will invalidate cache if file changes inode' do
          code = <<-PUPPET.unindent
              $ctx = Puppet::LookupContext.new(nil)
              $yaml_data = $ctx.cached_file_data('#{data_path}') |$content| {
                { 'parsed' => $content }
              }
              notice($yaml_data)
          PUPPET

          logs = []
          Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
            Puppet[:code] = code
            Puppet::Parser::Compiler.compile(node)

            # Change inode!
            File.delete(data_path);
            # Write content with the same size
            File.write(data_path, "a: value b\n")
            Puppet::Parser::Compiler.compile(node)
          end
          logs = logs.select { |log| log.level == :notice }.map { |log| log.message }
          expect(logs).to eql(["{parsed => a: value a\n}", "{parsed => a: value b\n}"])
        end
      end
    end

    context 'when used in an Invocation' do
      let(:node) { Puppet::Node.new('test') }
      let(:compiler) { Puppet::Parser::Compiler.new(node) }
      let(:invocation) { Invocation.new(compiler.topscope) }
      let(:invocation_with_explain) { Invocation.new(compiler.topscope, {}, {}, true) }

      def compile_and_get_notices(code, scope_vars = {})
        Puppet[:code] = code
        scope = compiler.topscope
        scope_vars.each_pair { |k,v| scope.setvar(k, v) }
        node.environment.check_for_reparse
        logs = []
        Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
          compiler.compile
        end
        logs = logs.select { |log| log.level == :notice }.map { |log| log.message }
        logs
      end

      it 'will not call explain unless explanations are active' do
        invocation.lookup('dummy', nil) do
          code = <<-PUPPET.unindent
            $ctx = Puppet::LookupContext.new('m')
            $ctx.explain || { notice('stop calling'); 'bad' }
          PUPPET
          expect(compile_and_get_notices(code)).to be_empty
        end
      end

      it 'will call explain when explanations are active' do
        invocation_with_explain.lookup('dummy', nil) do
          code = <<-PUPPET.unindent
            $ctx = Puppet::LookupContext.new('m')
            $ctx.explain || { notice('called'); 'good' }
          PUPPET
          expect(compile_and_get_notices(code)).to eql(['called'])
        end
        expect(invocation_with_explain.explainer.explain).to eql("good\n")
      end

      it 'will call interpolate to resolve interpolation' do
        invocation.lookup('dummy', nil) do
          code = <<-PUPPET.unindent
            $ctx = Puppet::LookupContext.new('m')
            notice($ctx.interpolate('-- %{testing} --'))
          PUPPET
          expect(compile_and_get_notices(code, { 'testing' => 'called' })).to eql(['-- called --'])
        end
      end
    end
  end
end
end
end
