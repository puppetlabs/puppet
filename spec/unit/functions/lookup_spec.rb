#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/compiler'
require 'puppet_spec/files'
require 'puppet/pops'
require 'deep_merge/core'

describe "The lookup function" do
  include PuppetSpec::Compiler
  include PuppetSpec::Files

  context 'with an environment' do
    let(:env_name) { 'spec' }
    let(:env_dir) { tmpdir('environments') }
    let(:environment_files) do
      {
        env_name => {
          'modules' => {},
          'hiera.yaml' => <<-YAML.unindent,
          ---
          version: 5
          hierarchy:
            - name: "Common"
              data_hash: yaml_data
              path: "common.yaml"
        YAML
        'data' => {
          'common.yaml' => <<-YAML.unindent
            ---
            a: value a
            mod_a::a: value mod_a::a (from environment)
            mod_a::hash_a:
              a: value mod_a::hash_a.a (from environment)
            mod_a::hash_b:
              a: value mod_a::hash_b.a (from environment)
            hash_b:
              hash_ba:
                bab: value hash_b.hash_ba.bab (from environment)
            hash_c:
              hash_ca:
                caa: value hash_c.hash_ca.caa (from environment)
            lookup_options:
              mod_a::hash_b:
                merge: hash
              hash_c:
                merge: hash
            YAML
          }
        }
      }
    end

    let(:logs) { [] }
    let(:notices) { logs.select { |log| log.level == :notice }.map { |log| log.message } }
    let(:warnings) { logs.select { |log| log.level == :warning }.map { |log| log.message } }
    let(:debugs) { logs.select { |log| log.level == :debug }.map { |log| log.message } }
    let(:env) { Puppet::Node::Environment.create(env_name.to_sym, [File.join(populated_env_dir, env_name, 'modules')]) }
    let(:environments) { Puppet::Environments::Directories.new(populated_env_dir, []) }
    let(:node) { Puppet::Node.new('test_lookup', :environment => env) }
    let(:compiler) { Puppet::Parser::Compiler.new(node) }
    let(:lookup_func) { Puppet.lookup(:loaders).puppet_system_loader.load(:function, 'lookup') }
    let(:defaults) {
      {
        'mod_a::xd' => 'value mod_a::xd (from default)',
        'mod_a::xd_found' => 'value mod_a::xd_found (from default)',
        'scope_xd' => 'value scope_xd (from default)'
      }}
    let(:overrides) {
      {
        'mod_a::xo' => 'value mod_a::xo (from override)',
        'scope_xo' => 'value scope_xo (from override)'
      }}
    let(:invocation_with_explain) { Puppet::Pops::Lookup::Invocation.new(compiler.topscope, {}, {}, true) }
    let(:explanation) { invocation_with_explain.explainer.explain }

    let(:populated_env_dir) do
      dir_contained_in(env_dir, environment_files)
      env_dir
    end

    around(:each) do |example|
      Puppet.override(:environments => environments, :current_environment => env) do
        example.run
      end
    end

    def collect_notices(code, explain = false, &block)
      Puppet[:code] = code
      Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
        scope = compiler.topscope
        scope['scope_scalar'] = 'scope scalar value'
        scope['scope_hash'] = { 'a' => 'scope hash a', 'b' => 'scope hash b' }
        if explain
          begin
            invocation_with_explain.lookup('dummy', nil) do
              if block_given?
                compiler.compile { |catalog| block.call(compiler.topscope); catalog }
              else
                compiler.compile
              end
            end
          rescue Puppet::DataBinding::LookupError => e
            invocation_with_explain.report_text { e.message }
          end
        else
          if block_given?
            compiler.compile { |catalog| block.call(compiler.topscope); catalog }
          else
            compiler.compile
          end
        end
      end
      nil
    end

    def lookup(key, options = {}, explain = false)
      nc_opts = options.empty? ? '' : ", #{Puppet::Pops::Types::TypeFormatter.string(options)}"
      keys = key.is_a?(Array) ? key : [key]
      collect_notices(keys.map { |k| "notice(String(lookup('#{k}'#{nc_opts}), '%p'))" }.join("\n"), explain)
      if explain
        explanation
      else
        result = notices.map { |n| Puppet::Pops::Types::TypeParser.singleton.parse_literal(n) }
        key.is_a?(Array) ? result : result[0]
      end
    end

    def explain(key, options = {})
      lookup(key, options, true)[1]
      explanation
    end

    it 'finds data in the environment' do
      expect(lookup('a')).to eql('value a')
    end

    context 'that has no lookup configured' do
      let(:environment_files) do
        {
          env_name => {
            'modules' => {},
            'data' => {
              'common.yaml' => <<-YAML.unindent
              ---
              a: value a
            YAML
            }
          }
        }
      end

      it 'does not find data in the environment' do
        expect { lookup('a') }.to raise_error(Puppet::DataBinding::LookupError, /did not find a value for the name 'a'/)
      end

      context "but an environment.conf with 'environment_data_provider=hiera'" do
        let(:environment_files_1) do
          DeepMerge.deep_merge!(environment_files, 'environment.conf' => "environment_data_provider=hiera\n")
        end

        let(:populated_env_dir) do
          dir_contained_in(env_dir, DeepMerge.deep_merge!(environment_files, env_name => environment_files_1))
          env_dir
        end

        it 'finds data in the environment and reports deprecation warning for environment.conf' do
          expect(lookup('a')).to eql('value a')
          expect(warnings).to include(/Defining environment_data_provider='hiera' in environment.conf is deprecated. A 'hiera.yaml' file should be used instead/)
        end

        context 'and a hiera.yaml file' do
          let(:environment_files_2) { DeepMerge.deep_merge!(environment_files_1,'hiera.yaml' => <<-YAML.unindent) }
            ---
            version: 4
            hierarchy:
              - name: common
                backend: yaml
            YAML

          let(:populated_env_dir) do
            dir_contained_in(env_dir, DeepMerge.deep_merge!(environment_files, env_name => environment_files_2))
            env_dir
          end

          it 'finds data in the environment and reports deprecation warnings for both environment.conf and hiera.yaml' do
            expect(lookup('a')).to eql('value a')
            expect(warnings).to include(/Defining environment_data_provider='hiera' in environment.conf is deprecated/)
            expect(warnings).to include(/Use of 'hiera.yaml' version 4 is deprecated. It should be converted to version 5/)
          end
        end
      end

      context "but an environment.conf with 'environment_data_provider=function'" do
        let(:environment_files) do
          {
            env_name => {
              'environment.conf' => "environment_data_provider=function\n",
              'functions' => { 'data.pp' => <<-PUPPET.unindent }
                    function environment::data() {
                      { 'a' => 'value a' }
                    }
              PUPPET
            }
          }
        end

        it 'finds data in the environment and reports deprecation warning for environment.conf' do
          expect(lookup('a')).to eql('value a')
          expect(warnings).to include(/Defining environment_data_provider='function' in environment.conf is deprecated. A 'hiera.yaml' file should be used instead/)
          expect(warnings).to include(/Using of legacy data provider function 'environment::data'. Please convert to a 'data_hash' function/)
        end
      end
    end

    context 'that has interpolated paths configured' do
      let(:environment_files) do
        {
          env_name => {
            'hiera.yaml' => <<-YAML.unindent,
              ---
              version: 5
              hierarchy:
                - name: "Varying"
                  data_hash: yaml_data
                  path: "x%{::var}.yaml"
              YAML
            'modules' => {},
            'data' => {
              'x.yaml' => <<-YAML.unindent,
                y: value y from x
              YAML
              'x_d.yaml' => <<-YAML.unindent
                y: value y from x_d
              YAML
            }
          }
        }
      end

      it 'reloads the configuration if interpolated values change' do
        Puppet[:log_level] = 'debug'
        collect_notices("notice('success')") do |scope|
          expect(lookup_func.call(scope, 'y')).to eql('value y from x')
          scope['var'] = '_d'
          expect(lookup_func.call(scope, 'y')).to eql('value y from x_d')
        end
        expect(notices).to eql(['success'])
        expect(debugs.any? { |m| m =~ /Hiera configuration recreated due to change of scope variables used in interpolation expressions/ }).to be_truthy
      end
    end

    context 'and a global Hiera v3 configuration' do
      let(:code_dir) { tmpdir('code') }
      let(:code_dir_files) do
        {
          'hiera.yaml' => <<-YAML.unindent,
            ---
            :backends:
              - yaml
              - json
            :yaml:
              :datadir: #{code_dir}/hieradata
            :json:
              :datadir: #{code_dir}/hieradata
            :hierarchy:
              - common
            :merge_behavior: deeper
            YAML
          'hieradata' => {
            'common.yaml' =>  <<-YAML.unindent,
              a: value a (from global)
              hash_b:
                hash_ba:
                  bab: value hash_b.hash_ba.bab (from global)
              hash_c:
                hash_ca:
                  cab: value hash_c.hash_ca.cab (from global)
              YAML
            'common.json' =>  <<-JSON.unindent,
              {
                "hash_b": {
                  "hash_ba": {
                    "bac": "value hash_b::hash_ba.bac (from global json)"
                  }
                },
                "hash_c": {
                  "hash_ca": {
                    "cac": "value hash_c::hash_ca.cac (from global json)"
                  }
                }
              }
              JSON
          }
        }
      end

      let(:populated_code_dir) do
        dir_contained_in(code_dir, code_dir_files)
        code_dir
      end

      before(:each) do
        # Need to set here since spec_helper defines these settings in its "before each"
        Puppet.settings[:codedir] = populated_code_dir
        Puppet.settings[:hiera_config] = File.join(code_dir, 'hiera.yaml')
      end

      around(:each) do |example|
        Puppet.override(:environments => environments, :current_environment => env) do
          example.run
        end
      end

      it 'finds data in the environment and reports deprecation warnings for both environment.conf and hiera.yaml' do
        expect(lookup('a')).to eql('value a (from global)')
        expect(warnings).to include(/Use of 'hiera.yaml' version 3 is deprecated. It should be converted to version 5/)
      end

      it 'explain contains output from global layer' do
        explanation = explain('a')
        expect(explanation).to include('Global Data Provider (hiera configuration version 3)')
        expect(explanation).to include('Hierarchy entry "yaml"')
        expect(explanation).to include('Hierarchy entry "json"')
        expect(explanation).to include('Found key: "a" value: "value a (from global)"')
      end

      it 'uses the merge behavior specified in global hiera.yaml to merge only global backends' do
        expect(lookup('hash_b')).to eql(
          { 'hash_ba' => { 'bab' => 'value hash_b.hash_ba.bab (from global)', 'bac' => 'value hash_b::hash_ba.bac (from global json)' } })
      end

      it 'uses the merge from lookup options to merge all layers and override merge_behavior specified in global hiera.yaml' do
        expect(lookup('hash_c')).to eql(
          { 'hash_ca' => { 'cab' => 'value hash_c.hash_ca.cab (from global)' } })
      end

      it 'uses the explicitly given merge to override lookup options and to merge all layers' do
        expect(lookup('hash_c', 'merge' => 'deep')).to eql(
          { 'hash_ca' => { 'caa' => 'value hash_c.hash_ca.caa (from environment)', 'cab' => 'value hash_c.hash_ca.cab (from global)', 'cac' => 'value hash_c::hash_ca.cac (from global json)'} })
      end
    end

    context 'and a module' do
      let(:mod_a_files) { {} }

      let(:populated_env_dir) do
        dir_contained_in(env_dir, DeepMerge.deep_merge!(environment_files, env_name => { 'modules' => mod_a_files }))
        env_dir
      end

      context 'that has no lookup configured' do
        let(:mod_a_files) do
          {
            'mod_a' => {
              'data' => {
                'common.yaml' => <<-YAML.unindent
                ---
                mod_a::b: value mod_a::b (from mod_a)
              YAML
              }
            }
          }
        end

        it 'does not find data in the module' do
          expect { lookup('mod_a::b') }.to raise_error(Puppet::DataBinding::LookupError, /did not find a value for the name 'mod_a::b'/)
        end

        context "but a metadata.json with 'module_data_provider=hiera'" do
          let(:mod_a_files_1) { DeepMerge.deep_merge!(mod_a_files, 'mod_a' => { 'metadata.json' => <<-JSON.unindent }) }
              {
                  "name": "example/mod_a",
                  "version": "0.0.2",
                  "source": "git@github.com/example/mod_a.git",
                  "dependencies": [],
                  "author": "Bob the Builder",
                  "license": "Apache-2.0",
                  "data_provider": "hiera"
              }
              JSON

          let(:populated_env_dir) do
            dir_contained_in(env_dir, DeepMerge.deep_merge!(environment_files, env_name => { 'modules' => mod_a_files_1 }))
            env_dir
          end

          it 'finds data in the module and reports deprecation warning for metadata.json' do
            expect(lookup('mod_a::b')).to eql('value mod_a::b (from mod_a)')
            expect(warnings).to include(/Defining "data_provider": "hiera" in metadata.json is deprecated. A 'hiera.yaml' file should be used instead/)
          end

          context 'and a hiera.yaml file' do
            let(:mod_a_files_2) { DeepMerge.deep_merge!(mod_a_files_1, 'mod_a' => { 'hiera.yaml' => <<-YAML.unindent }) }
            ---
            version: 4
            hierarchy:
              - name: common
                backend: yaml
            YAML

            let(:populated_env_dir) do
              dir_contained_in(env_dir, DeepMerge.deep_merge!(environment_files, env_name => { 'modules' => mod_a_files_2 }))
              env_dir
            end

            it 'finds data in the module and reports deprecation warnings for both metadata.json and hiera.yaml' do
              expect(lookup('mod_a::b')).to eql('value mod_a::b (from mod_a)')
              expect(warnings).to include(/Defining "data_provider": "hiera" in metadata.json is deprecated/)
              expect(warnings).to include(/Use of 'hiera.yaml' version 4 is deprecated. It should be converted to version 5/)
            end
          end
        end
      end

      context 'using a data_hash that reads a yaml file' do
        let(:mod_a_files) do
          {
            'mod_a' => {
              'data' => {
                'verbatim.yaml' => <<-YAML.unindent,
                ---
                mod_a::vbt: "verbatim %{scope_xo} --"
                YAML
                'common.yaml' => <<-YAML.unindent
                ---
                mod_a::a: value mod_a::a (from mod_a)
                mod_a::b: value mod_a::b (from mod_a)
                mod_a::xo: value mod_a::xo (from mod_a)
                mod_a::xd_found: value mod_a::xd_found (from mod_a)
                mod_a::interpolate_xo: "-- %{lookup('mod_a::xo')} --"
                mod_a::interpolate_xd: "-- %{lookup('mod_a::xd')} --"
                mod_a::interpolate_scope_xo: "-- %{scope_xo} --"
                mod_a::interpolate_scope_xd: "-- %{scope_xd} --"
                mod_a::hash_a:
                  a: value mod_a::hash_a.a (from mod_a)
                  b: value mod_a::hash_a.b (from mod_a)
                mod_a::hash_b:
                  a: value mod_a::hash_b.a (from mod_a)
                  b: value mod_a::hash_b.b (from mod_a)
                mod_a::interpolated: "-- %{lookup('mod_a::a')} --"
                mod_a::a_a: "-- %{lookup('mod_a::hash_a.a')} --"
                mod_a::a_b: "-- %{lookup('mod_a::hash_a.b')} --"
                mod_a::b_a: "-- %{lookup('mod_a::hash_b.a')} --"
                mod_a::b_b: "-- %{lookup('mod_a::hash_b.b')} --"
                mod_a::interpolate_array:
                  - "-- %{lookup('mod_a::a')} --"
                  - "-- %{lookup('mod_a::b')} --"
                mod_a::interpolate_literal: "-- %{literal('hello')} --"
                mod_a::interpolate_scope: "-- %{scope_scalar} --"
                mod_a::interpolate_scope_not_found: "-- %{scope_nope} --"
                mod_a::interpolate_scope_dig: "-- %{scope_hash.a} --"
                mod_a::interpolate_scope_dig_not_found: "-- %{scope_hash.nope} --"
                mod_a::quoted_interpolation: '-- %{lookup(''"mod_a::a.quoted.key"'')} --'
                "mod_a::a.quoted.key": "value mod_a::a.quoted.key (from mod_a)"
              YAML
              },
              'hiera.yaml' => <<-YAML.unindent,
              ---
              version: 5
              hierarchy:
                - name: "Common"
                  data_hash: yaml_data
                  path: "common.yaml"
                - name: "Verbatim"
                  data_hash: yaml_data
                  path: "verbatim.yaml"
                  options:
                    verbatim: true
            YAML
            }
          }
        end

        it 'finds data in the module' do
          expect(lookup('mod_a::b')).to eql('value mod_a::b (from mod_a)')
        end

        it 'environment data has higher priority than module data' do
          expect(lookup('mod_a::a')).to eql('value mod_a::a (from environment)')
        end

        it 'environment data has higher priority than module data in interpolated module data' do
          expect(lookup('mod_a::interpolated')).to eql('-- value mod_a::a (from environment) --')
        end

        it 'overrides have higher priority than found data' do
          expect(lookup('mod_a::xo', { 'override' => overrides })).to eql('value mod_a::xo (from override)')
        end

        it 'overrides have higher priority than found data in lookup interpolations' do
          expect(lookup('mod_a::interpolate_xo', { 'override' => overrides })).to eql('-- value mod_a::xo (from override) --')
        end

        it 'overrides have higher priority than found data in scope interpolations' do
          expect(lookup('mod_a::interpolate_scope_xo', { 'override' => overrides })).to eql('-- value scope_xo (from override) --')
        end

        it 'defaults have lower priority than found data' do
          expect(lookup('mod_a::xd_found', { 'default_values_hash' => defaults })).to eql('value mod_a::xd_found (from mod_a)')
        end

        it 'defaults are used when data is not found' do
          expect(lookup('mod_a::xd', { 'default_values_hash' => defaults })).to eql('value mod_a::xd (from default)')
        end

        it 'defaults are used when data is not found in lookup interpolations' do
          expect(lookup('mod_a::interpolate_xd', { 'default_values_hash' => defaults })).to eql('-- value mod_a::xd (from default) --')
        end

        it 'defaults are used when data is not found in scope interpolations' do
          expect(lookup('mod_a::interpolate_scope_xd', { 'default_values_hash' => defaults })).to eql('-- value scope_xd (from default) --')
        end

        it 'merges hashes from environment and module unless strategy hash is used' do
          expect(lookup('mod_a::hash_a')).to eql({'a' => 'value mod_a::hash_a.a (from environment)'})
        end

        it 'merges hashes from environment and module when merge strategy hash is used' do
          expect(lookup('mod_a::hash_a', :merge => 'hash')).to eql(
            {'a' => 'value mod_a::hash_a.a (from environment)', 'b' => 'value mod_a::hash_a.b (from mod_a)'})
        end

        it 'will not merge hashes from environment and module in interpolated expressions' do
          expect(lookup(['mod_a::a_a', 'mod_a::a_b'])).to eql(
            ['-- value mod_a::hash_a.a (from environment) --', '--  --']) # root key found in environment, no hash merge is performed
        end

        it 'interpolates arrays' do
          expect(lookup('mod_a::interpolate_array')).to eql(['-- value mod_a::a (from environment) --', '-- value mod_a::b (from mod_a) --'])
        end

        it 'can dig into arrays using subkeys' do
          expect(lookup('mod_a::interpolate_array.1')).to eql('-- value mod_a::b (from mod_a) --')
        end

        it 'treats an out of range subkey as not found' do
          expect(explain('mod_a::interpolate_array.2')).to match(/No such key: "2"/)
        end

        it 'interpolates a literal' do
          expect(lookup('mod_a::interpolate_literal')).to eql('-- hello --')
        end

        it 'does not interpolate when options { "verbatim" => true }' do
          expect(lookup('mod_a::vbt')).to eql('verbatim %{scope_xo} --')
        end

        it 'interpolates scalar from scope' do
          expect(lookup('mod_a::interpolate_scope')).to eql('-- scope scalar value --')
        end

        it 'interpolates not found in scope as empty string' do
          expect(lookup('mod_a::interpolate_scope_not_found')).to eql('--  --')
        end

        it 'interpolates dotted key from scope' do
          expect(lookup('mod_a::interpolate_scope_dig')).to eql('-- scope hash a --')
        end

        it 'treates interpolated dotted key but not found in scope as empty string' do
          expect(lookup('mod_a::interpolate_scope_dig_not_found')).to eql('--  --')
        end

        it 'can use quoted keys in interpolation' do
          expect(lookup('mod_a::quoted_interpolation')).to eql('-- value mod_a::a.quoted.key (from mod_a) --') # root key found in environment, no hash merge is performed
        end

        it 'merges hashes from environment and module in interpolated expressions if hash merge is specified in lookup options' do
          expect(lookup(['mod_a::b_a', 'mod_a::b_b'])).to eql(
            ['-- value mod_a::hash_b.a (from environment) --', '-- value mod_a::hash_b.b (from mod_a) --'])
        end
      end

      context 'using a lookup_key that is a puppet function' do
        let(:mod_a_files) do
          {
            'mod_a' => {
              'functions' => {
                'pp_lookup_key.pp' => <<-PUPPET.unindent
                function mod_a::pp_lookup_key($key, $options, $context) {
                  case $key {
                    'mod_a::really_interpolated': { $context.interpolate("-- %{lookup('mod_a::a')} --") }
                    'mod_a::recursive': { lookup($key) }
                    default: {
                      if $context.cache_has_key(mod_a::a) {
                        $context.explain || { 'reusing cache' }
                      } else {
                        $context.explain || { 'initializing cache' }
                        $context.cache_all({
                          mod_a::a => 'value mod_a::a (from mod_a)',
                          mod_a::b => 'value mod_a::b (from mod_a)',
                          mod_a::c => 'value mod_a::c (from mod_a)',
                          mod_a::hash_a => {
                            a => 'value mod_a::hash_a.a (from mod_a)',
                            b => 'value mod_a::hash_a.b (from mod_a)'
                          },
                          mod_a::hash_b => {
                            a => 'value mod_a::hash_b.a (from mod_a)',
                            b => 'value mod_a::hash_b.b (from mod_a)'
                          },
                          mod_a::interpolated => "-- %{lookup('mod_a::a')} --",
                          mod_a::a_a => "-- %{lookup('mod_a::hash_a.a')} --",
                          mod_a::a_b => "-- %{lookup('mod_a::hash_a.b')} --",
                          mod_a::b_a => "-- %{lookup('mod_a::hash_b.a')} --",
                          mod_a::b_b => "-- %{lookup('mod_a::hash_b.b')} --",
                          'mod_a::a.quoted.key' => 'value mod_a::a.quoted.key (from mod_a)',
                          mod_a::sensitive => Sensitive('reduct me please'),
                          mod_a::type => Object[{name => 'FindMe', 'attributes' => {'x' => String}}],
                          mod_a::version => SemVer('3.4.1'),
                          mod_a::version_range => SemVerRange('>=3.4.1'),
                          mod_a::timestamp => Timestamp("1994-03-25T19:30:00"),
                          mod_a::timespan => Timespan("3-10:00:00")
                        })
                      }
                      if !$context.cache_has_key($key) {
                        $context.not_found
                      }
                      $context.explain || { "returning value for $key" }
                      $context.cached_value($key)
                    }
                  }
                }
              PUPPET
              },
              'hiera.yaml' => <<-YAML.unindent,
              ---
              version: 5
              hierarchy:
                - name: "Common"
                  lookup_key: mod_a::pp_lookup_key
            YAML
            }
          }
        end

        it 'finds data in the module' do
          expect(lookup('mod_a::b')).to eql('value mod_a::b (from mod_a)')
        end

        it 'environment data has higher priority than module data' do
          expect(lookup('mod_a::a')).to eql('value mod_a::a (from environment)')
        end

        it 'finds quoted keys in the module' do
          expect(lookup('"mod_a::a.quoted.key"')).to eql('value mod_a::a.quoted.key (from mod_a)')
        end

        it 'will not resolve interpolated expressions' do
          expect(lookup('mod_a::interpolated')).to eql("-- %{lookup('mod_a::a')} --")
        end

        it 'resolves interpolated expressions using Context#interpolate' do
          expect(lookup('mod_a::really_interpolated')).to eql("-- value mod_a::a (from environment) --")
        end

        it 'will not merge hashes from environment and module unless strategy hash is used' do
          expect(lookup('mod_a::hash_a')).to eql({ 'a' => 'value mod_a::hash_a.a (from environment)' })
        end

        it 'merges hashes from environment and module when merge strategy hash is used' do
          expect(lookup('mod_a::hash_a', :merge => 'hash')).to eql({ 'a' => 'value mod_a::hash_a.a (from environment)', 'b' => 'value mod_a::hash_a.b (from mod_a)' })
        end

        it 'traps recursive lookup trapped' do
          expect(explain('mod_a::recursive')).to include('Recursive lookup detected')
        end

        it 'private cache is persisted over multiple calls' do
          collect_notices("notice(lookup('mod_a::b')) notice(lookup('mod_a::c'))", true)
          expect(notices).to eql(['value mod_a::b (from mod_a)', 'value mod_a::c (from mod_a)'])
          expect(explanation).to match(/initializing cache.*reusing cache/m)
          expect(explanation).not_to match(/initializing cache.*initializing cache/m)
        end

        it 'the same key is requested only once' do
          collect_notices("notice(lookup('mod_a::b')) notice(lookup('mod_a::b'))", true)
          expect(notices).to eql(['value mod_a::b (from mod_a)', 'value mod_a::b (from mod_a)'])
          expect(explanation).to match(/Found key: "mod_a::b".*Found key: "mod_a::b"/m)
          expect(explanation).to match(/returning value for mod_a::b/m)
          expect(explanation).not_to match(/returning value for mod_a::b.*returning value for mod_a::b/m)
        end

        context 'and calling function via API' do
          it 'finds and delivers rich data' do
            collect_notices("notice('success')") do |scope|
              expect(lookup_func.call(scope, 'mod_a::sensitive')).to be_a(Puppet::Pops::Types::PSensitiveType::Sensitive)
              expect(lookup_func.call(scope, 'mod_a::type')).to be_a(Puppet::Pops::Types::PObjectType)
              expect(lookup_func.call(scope, 'mod_a::version')).to eql(SemanticPuppet::Version.parse('3.4.1'))
              expect(lookup_func.call(scope, 'mod_a::version_range')).to eql(SemanticPuppet::VersionRange.parse('>=3.4.1'))
              expect(lookup_func.call(scope, 'mod_a::timestamp')).to eql(Puppet::Pops::Time::Timestamp.parse('1994-03-25T19:30:00'))
              expect(lookup_func.call(scope, 'mod_a::timespan')).to eql(Puppet::Pops::Time::Timespan.parse('3-10:00:00'))
            end
            expect(notices).to eql(['success'])
          end
        end
      end

      context 'using a data_dig that is a ruby function' do
        let(:mod_a_files) do
          {
            'mod_a' => {
              'lib' => {
                'puppet' => {
                  'functions' => {
                    'mod_a' => {
                      'ruby_dig.rb' => <<-RUBY.unindent
                      Puppet::Functions.create_function(:'mod_a::ruby_dig') do
                        dispatch :ruby_dig do
                          param 'Array[String[1]]', :segments
                          param 'Hash[String,Any]', :options
                          param 'Puppet::LookupContext', :context
                        end

                        def ruby_dig(segments, options, context)
                          sub_segments = segments.dup
                          root_key = sub_segments.shift
                          case root_key
                          when 'mod_a::options'
                            hash = { 'mod_a::options' => options }
                          when 'mod_a::lookup'
                            return call_function('lookup', segments.join('.'))
                          else
                            hash = {
                              'mod_a::a' => 'value mod_a::a (from mod_a)',
                              'mod_a::b' => 'value mod_a::b (from mod_a)',
                              'mod_a::hash_a' => {
                                'a' => 'value mod_a::hash_a.a (from mod_a)',
                                'b' => 'value mod_a::hash_a.b (from mod_a)'
                              },
                              'mod_a::hash_b' => {
                                'a' => 'value mod_a::hash_b.a (from mod_a)',
                                'b' => 'value mod_a::hash_b.b (from mod_a)'
                              },
                              'mod_a::interpolated' => "-- %{lookup('mod_a::a')} --",
                              'mod_a::really_interpolated' => "-- %{lookup('mod_a::a')} --",
                              'mod_a::a_a' => "-- %{lookup('mod_a::hash_a.a')} --",
                              'mod_a::a_b' => "-- %{lookup('mod_a::hash_a.b')} --",
                              'mod_a::b_a' => "-- %{lookup('mod_a::hash_b.a')} --",
                              'mod_a::b_b' => "-- %{lookup('mod_a::hash_b.b')} --",
                              'mod_a::bad_type' => :oops,
                              'mod_a::bad_type_in_hash' => { 'a' => :oops },
                            }
                            end
                          context.not_found unless hash.include?(root_key)
                          value = sub_segments.reduce(hash[root_key]) do |memo, segment|
                            context.not_found unless memo.is_a?(Hash) && memo.include?(segment)
                            memo[segment]
                          end
                          root_key == 'mod_a::really_interpolated' ? context.interpolate(value) : value
                        end
                      end
                    RUBY
                    }
                  }
                }
              },
              'hiera.yaml' => <<-YAML.unindent,
              ---
              version: 5
              hierarchy:
                - name: "Common"
                  data_dig: mod_a::ruby_dig
                  uri: "http://www.example.com/passed/as/option"
                  options:
                    option_a: Option value a
                    option_b:
                      x: Option value b.x
                      y: Option value b.y
            YAML
            }
          }
        end

        it 'finds data in the module' do
          expect(lookup('mod_a::b')).to eql('value mod_a::b (from mod_a)')
        end

        it 'environment data has higher priority than module data' do
          expect(lookup('mod_a::a')).to eql('value mod_a::a (from environment)')
        end

        it 'will not resolve interpolated expressions' do
          expect(lookup('mod_a::interpolated')).to eql("-- %{lookup('mod_a::a')} --")
        end

        it 'resolves interpolated expressions using Context#interpolate' do
          expect(lookup('mod_a::really_interpolated')).to eql("-- value mod_a::a (from environment) --")
        end

        it 'does not accept return of runtime type from function' do
          expect(explain('mod_a::bad_type')).to include('Value returned from Hierarchy entry "Common" has wrong type')
        end

        it 'does not accept return of runtime type embedded in hash from function' do
          expect(explain('mod_a::bad_type_in_hash')).to include('Value returned from Hierarchy entry "Common" has wrong type')
        end

        it 'will not merge hashes from environment and module unless strategy hash is used' do
          expect(lookup('mod_a::hash_a')).to eql({'a' => 'value mod_a::hash_a.a (from environment)'})
        end

        it 'hierarchy entry options are passed to the function' do
          expect(lookup('mod_a::options.option_b.x')).to eql('Option value b.x')
        end

        it 'hierarchy entry "uri" is passed as location option to the function' do
          expect(lookup('mod_a::options.uri')).to eql('http://www.example.com/passed/as/option')
        end

        it 'recursive lookup is trapped' do
          expect(explain('mod_a::lookup.mod_a::lookup')).to include('Recursive lookup detected')
        end

        context 'with merge strategy hash' do
          it 'merges hashes from environment and module' do
            expect(lookup('mod_a::hash_a', :merge => 'hash')).to eql({'a' => 'value mod_a::hash_a.a (from environment)', 'b' => 'value mod_a::hash_a.b (from mod_a)'})
          end

          it 'will "undig" value from data_dig function, merge root hashes, and then dig to get values by subkey' do
            expect(lookup(['mod_a::hash_a.a', 'mod_a::hash_a.b'], :merge => 'hash')).to eql(
              ['value mod_a::hash_a.a (from environment)', 'value mod_a::hash_a.b (from mod_a)'])
          end
        end
      end
    end
  end
end
