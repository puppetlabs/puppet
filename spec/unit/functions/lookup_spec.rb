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
    let(:code_dir_files) { {} }
    let(:code_dir) { tmpdir('code') }
    let(:ruby_dir) { tmpdir('ruby') }
    let(:env_modules) { {} }
    let(:env_hiera_yaml) do
      <<-YAML.unindent
        ---
        version: 5
        hierarchy:
          - name: "Common"
            data_hash: yaml_data
            path: "common.yaml"
        YAML
    end

    let(:env_data) do
      {
        'common.yaml' => <<-YAML.unindent
          ---
          a: value a (from environment)
          c:
            c_b: value c_b (from environment)
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
    end

    let(:environment_files) do
      {
        env_name => {
          'modules' => env_modules,
          'hiera.yaml' => env_hiera_yaml,
          'data' => env_data
        }
      }
    end

    let(:ruby_dir_files) do
      {
        'hiera' => {
          'backend' => {
            'custom_backend.rb' => <<-RUBY.unindent,
              class Hiera::Backend::Custom_backend
                def lookup(key, scope, order_override, resolution_type, context)
                  case key
                  when 'hash_c'
                    { 'hash_ca' => { 'cad' => 'value hash_c.hash_ca.cad (from global custom)' }}
                  when 'h'
                    [ 'x5,x6' ]
                  when 'datasources'
                    Hiera::Backend.datasources(scope, order_override) { |source| source }
                  else
                    throw :no_such_key
                  end
                end
              end
              RUBY
            'other_backend.rb' => <<-RUBY.unindent,
              class Hiera::Backend::Other_backend
                def lookup(key, scope, order_override, resolution_type, context)
                  value = Hiera::Config[:other][key.to_sym]
                  throw :no_such_key if value.nil?
                  value
                end
              end
              RUBY
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

    let(:populated_code_dir) do
      dir_contained_in(code_dir, code_dir_files)
      code_dir
    end

    let(:populated_ruby_dir) do
      dir_contained_in(ruby_dir, ruby_dir_files)
      ruby_dir
    end

    let(:env_dir) do
      d = File.join(populated_code_dir, 'environments')
      Dir.mkdir(d)
      d
    end

    let(:populated_env_dir) do
      dir_contained_in(env_dir, environment_files)
      env_dir
    end

    before(:each) do
      Puppet.settings[:codedir] = code_dir
      Puppet.push_context(:environments => environments, :current_environment => env)
    end

    after(:each) do
      Puppet.pop_context
      if Object.const_defined?(:Hiera)
        Hiera.send(:remove_instance_variable, :@config) if Hiera.instance_variable_defined?(:@config)
        Hiera.send(:remove_instance_variable, :@logger) if Hiera.instance_variable_defined?(:@logger)
        if Hiera.const_defined?(:Config)
          Hiera::Config.send(:remove_instance_variable, :@config) if Hiera::Config.instance_variable_defined?(:@config)
        end
        if Hiera.const_defined?(:Backend)
          Hiera::Backend.clear!
        end
      end
    end

    def collect_notices(code, explain = false, &block)
      Puppet[:code] = code
      Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
        scope = compiler.topscope
        scope['environment'] = env_name
        scope['domain'] = 'example.com'
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
          rescue RuntimeError => e
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
      expect(lookup('a')).to eql('value a (from environment)')
    end

    context 'that has no lookup configured' do
      let(:environment_files) do
        {
          env_name => {
            'data' => env_data
          }
        }
      end

      it 'does not find data in the environment' do
        expect { lookup('a') }.to raise_error(Puppet::DataBinding::LookupError, /did not find a value for the name 'a'/)
      end

      context "but an environment.conf with 'environment_data_provider=hiera'" do
        let(:environment_files) do
          {
            env_name => {
              'environment.conf' => "environment_data_provider=hiera\n",
              'data' => env_data
            }
          }
        end

        it 'finds data in the environment and reports deprecation warning for environment.conf' do
          expect(lookup('a')).to eql('value a (from environment)')
          expect(warnings).to include(/Defining environment_data_provider='hiera' in environment.conf is deprecated. A 'hiera.yaml' file should be used instead/)
        end

        context 'and a hiera.yaml file' do
          let(:env_hiera_yaml) do
            <<-YAML.unindent
              ---
              version: 4
              hierarchy:
                - name: common
                  backend: yaml
              YAML
          end

          let(:environment_files) do
            {
              env_name => {
                'hiera.yaml' => env_hiera_yaml,
                'environment.conf' => "environment_data_provider=hiera\n",
                'data' => env_data
              }
            }
          end

          it 'finds data in the environment and reports deprecation warnings for both environment.conf and hiera.yaml' do
            expect(lookup('a')).to eql('value a (from environment)')
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
              'functions' => {
                'environment' => { 'data.pp' => <<-PUPPET.unindent }
                    function environment::data() {
                      { 'a' => 'value a' }
                    }
                    PUPPET
              }
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
      let(:env_hiera_yaml) do
        <<-YAML.unindent
          ---
          version: 5
          hierarchy:
            - name: "Varying"
              data_hash: yaml_data
              path: "x%{::var.sub}.yaml"
          YAML
      end

      let(:environment_files) do
        {
          env_name => {
            'hiera.yaml' => env_hiera_yaml,
            'modules' => {},
            'data' => {
              'x.yaml' => <<-YAML.unindent,
                y: value y from x
              YAML
              'x_d.yaml' => <<-YAML.unindent,
                y: value y from x_d
              YAML
              'x_e.yaml' => <<-YAML.unindent
                y: value y from x_e
              YAML
            }
          }
        }
      end

      it 'reloads the configuration if interpolated values change' do
        Puppet[:log_level] = 'debug'
        collect_notices("notice('success')") do |scope|
          expect(lookup_func.call(scope, 'y')).to eql('value y from x')
          var = { 'sub' => '_d' }
          scope['var'] = var
          expect(lookup_func.call(scope, 'y')).to eql('value y from x_d')
          var['sub'] = '_e'
          expect(lookup_func.call(scope, 'y')).to eql('value y from x_e')
        end
        expect(notices).to eql(['success'])
        expect(debugs.any? { |m| m =~ /Hiera configuration recreated due to change of scope variables used in interpolation expressions/ }).to be_truthy
      end
    end

    context 'that uses reserved option' do
      let(:environment_files) do
        {
          env_name => {
            'hiera.yaml' => <<-YAML.unindent,
              ---
              version: 5
              hierarchy:
                - name: "Illegal"
                  options:
                    #{opt_spec}
                  data_hash: yaml_data
              YAML
            'data' => {
              'foo.yaml' => "a: The value a\n"
            }
          }
        }
      end

      context 'path' do
        let(:opt_spec) { 'path: data/foo.yaml' }

        it 'fails and reports the reserved option key' do
          expect { lookup('a') }.to raise_error do |e|
            expect(e.message).to match(/Option key 'path' used in hierarchy 'Illegal' is reserved by Puppet/)
          end
        end
      end

      context 'uri' do
        let(:opt_spec) { 'uri: file:///data/foo.yaml' }

        it 'fails and reports the reserved option key' do
          expect { lookup('a') }.to raise_error do |e|
            expect(e.message).to match(/Option key 'uri' used in hierarchy 'Illegal' is reserved by Puppet/)
          end
        end
      end
    end

    context 'with yaml data file' do
      let(:environment_files) do
        {
          env_name => {
            'hiera.yaml' => <<-YAML.unindent,
              ---
              version: 5
              YAML
            'data' => {
              'common.yaml' => common_yaml
            }
          }
        }
      end

      context 'that contains hash values with interpolated keys' do
        let(:common_yaml) do
          <<-YAML.unindent
          ---
          a:
              "%{key}": "the %{value}"
          b:  "Detail in %{lookup('a.a_key')}"
          YAML
        end

        it 'interpolates both key and value"' do
          Puppet[:log_level] = 'debug'
          collect_notices("notice('success')") do |scope|
            expect(lookup_func.call(scope, 'a')).to eql({'' => 'the '})
            scope['key'] = 'a_key'
            scope['value'] = 'interpolated value'
            expect(lookup_func.call(scope, 'a')).to eql({'a_key' => 'the interpolated value'})
          end
          expect(notices).to eql(['success'])
        end

        it 'navigates to a value behind an interpolated key"' do
          Puppet[:log_level] = 'debug'
          collect_notices("notice('success')") do |scope|
            scope['key'] = 'a_key'
            scope['value'] = 'interpolated value'
            expect(lookup_func.call(scope, 'a.a_key')).to eql('the interpolated value')
          end
          expect(notices).to eql(['success'])
        end

        it 'navigates to a value behind an interpolated key using an interpolated value"' do
          Puppet[:log_level] = 'debug'
          collect_notices("notice('success')") do |scope|
            scope['key'] = 'a_key'
            scope['value'] = 'interpolated value'
            expect(lookup_func.call(scope, 'b')).to eql('Detail in the interpolated value')
          end
          expect(notices).to eql(['success'])
        end
      end

      context 'that is empty' do
        let(:common_yaml) { '' }

        it 'fails with a "did not find"' do
          expect { lookup('a') }.to raise_error do |e|
            expect(e.message).to match(/did not find a value for the name 'a'/)
          end
        end

        it 'logs a warning that the file does not contain a hash' do
          expect { lookup('a') }.to raise_error(Puppet::DataBinding::LookupError)
          expect(warnings).to include(/spec\/data\/common.yaml: file does not contain a valid yaml hash/)
        end
      end

      context 'that contains illegal yaml' do
        let(:common_yaml) { "@!#%**&:\n" }

        it 'fails lookup and that the key is not found' do
          expect { lookup('a') }.to raise_error do |e|
            expect(e.message).to match(/Unable to parse/)
          end
        end
      end

      context 'that contains a legal yaml that is not a hash' do
        let(:common_yaml) { "- A list\n- of things" }

        it 'fails with a "did not find"' do
          expect { lookup('a') }.to raise_error do |e|
            expect(e.message).to match(/did not find a value for the name 'a'/)
          end
        end

        it 'logs a warning that the file does not contain a hash' do
          expect { lookup('a') }.to raise_error(Puppet::DataBinding::LookupError)
          expect(warnings).to include(/spec\/data\/common.yaml: file does not contain a valid yaml hash/)
        end
      end

      context 'that contains a legal yaml hash with illegal types' do
        let(:common_yaml) do
          <<-YAML.unindent
          ---
          a: !ruby/object:Puppet::Graph::Key
              value: x
          YAML
        end

        it 'fails lookup and reports a type mismatch' do
          expect { lookup('a') }.to raise_error do |e|
            expect(e.message).to match(/wrong type, expects a value of type Scalar, Sensitive, Type, Hash, or Array, got Runtime/)
          end
        end
      end
    end

    context 'with lookup_options configured using patterns' do
      let(:mod_common) {
        <<-YAML.unindent
          mod::hash_a:
            aa:
              aaa: aaa (from module)
            ab:
              aba: aba (from module)
          mod::hash_b:
            ba:
              baa: baa (from module)
            bb:
              bba: bba (from module)
          lookup_options:
            '^mod::ha.*_a':
              merge: deep
            '^mod::ha.*_b':
              merge: deep
        YAML
      }

      let(:mod_base) do
        {
          'hiera.yaml' => <<-YAML.unindent,
            version: 5
            YAML
          'data' => {
            'common.yaml' => mod_common
          }
        }
      end

      let(:env_modules) do
        {
          'mod' => mod_base
        }
      end

      let(:env_hiera_yaml) do
        <<-YAML.unindent
          ---
          version: 5
          hierarchy:
            - name: X
              paths:
              - first.yaml
              - second.yaml
          YAML
      end

      let(:env_data) do
        {
          'first.yaml' => <<-YAML.unindent,
                a:
                  aa:
                    aaa: a.aa.aaa
                b:
                  ba:
                    baa: b.ba.baa
                  bb:
                    bba: b.bb.bba
                c:
                  ca:
                    caa: c.ca.caa
                mod::hash_a:
                  aa:
                    aab: aab (from environment)
                  ab:
                    aba: aba (from environment)
                    abb: abb (from environment)
                mod::hash_b:
                  ba:
                    bab: bab (from environment)
                  bc:
                    bca: bca (from environment)
                lookup_options:
                  b:
                    merge: hash
                  '^[^b]$':
                     merge: deep
                  '^c':
                     merge: first
                  '^b':
                     merge: first
                  '^mod::ha.*_b':
                    merge: hash
        YAML
        'second.yaml' => <<-YAML.unindent,
                a:
                  aa:
                    aab: a.aa.aab
                b:
                  ba:
                    bab: b.ba.bab
                  bb:
                    bbb: b.bb.bbb
                c:
                  ca:
                    cab: c.ca.cab
        YAML
        }
      end

      it 'finds lookup_options that matches a pattern' do
        expect(lookup('a')).to eql({'aa' => { 'aaa' => 'a.aa.aaa', 'aab' => 'a.aa.aab' }})
      end

      it 'gives a direct key match higher priority than a matching pattern' do
        expect(lookup('b')).to eql({'ba' => { 'baa' => 'b.ba.baa' }, 'bb' => { 'bba'=>'b.bb.bba' }})
      end

      it 'uses the first matching pattern' do
        expect(lookup('c')).to eql({'ca' => { 'caa' => 'c.ca.caa', 'cab' => 'c.ca.cab' }})
      end

      it 'uses lookup_option found by pattern from module' do
        expect(lookup('mod::hash_a')).to eql({
          'aa' => {
            'aaa' => 'aaa (from module)',
            'aab' => 'aab (from environment)'
          },
          'ab' => {
            'aba' => 'aba (from environment)',
            'abb' => 'abb (from environment)'
          }
        })
      end

      it 'merges lookup_options found by pattern in environment and module (environment wins)' do
        expect(lookup('mod::hash_b')).to eql({
          'ba' => {
            'bab' => 'bab (from environment)'
          },
          'bb' => {
            'bba' => 'bba (from module)'
          },
          'bc' => {
            'bca' => 'bca (from environment)'
          }
        })
      end

      context 'and patterns in module are not limited to module keys' do
        let(:mod_common) {
          <<-YAML.unindent
          mod::hash_a:
            aa:
              aaa: aaa (from module)
            ab:
              aba: aba (from module)
          lookup_options:
            '^.*_a':
              merge: deep
          YAML
        }

        it 'fails with error' do
          expect { lookup('mod::a') }.to raise_error(Puppet::DataBinding::LookupError, /all lookup_options patterns must match a key starting with module name/)
        end
      end
    end

    context 'and a global Hiera v4 configuration' do
      let(:code_dir_files) do
        {
          'hiera.yaml' => <<-YAML.unindent,
            ---
            version: 4
        YAML
        }
      end

      before(:each) do
        # Need to set here since spec_helper defines these settings in its "before each"
        Puppet.settings[:codedir] = populated_code_dir
        Puppet.settings[:hiera_config] = File.join(code_dir, 'hiera.yaml')
      end

      it 'raises an error' do
        expect { lookup('a') }.to raise_error(Puppet::Error, /hiera configuration version 4 cannot be used in the global layer/)
      end
    end

    context 'and an environment Hiera v3 configuration' do
      let(:env_hiera_yaml) do
        <<-YAML.unindent
          ---
          :backends: yaml
          :yaml:
            :datadir:  #{env_dir}/#{env_name}/hieradata
          YAML
      end

      let(:environment_files) do
        {
          env_name => {
            'hiera.yaml' => env_hiera_yaml,
            'hieradata' => {
              'common.yaml' => <<-YAML.unindent,
                g: Value g
                YAML
            }
          }
        }
      end

      it 'will raise an error if --strict is set to error' do
        Puppet[:strict] = :error
        expect { lookup('g') }.to raise_error(Puppet::Error, /hiera configuration version 3 cannot be used in an environment/)
      end

      it 'will log a warning and ignore the file if --strict is set to warning' do
        Puppet[:strict] = :warning
        expect { lookup('g') }.to raise_error(Puppet::Error, /did not find a value for the name 'g'/)
      end

      it 'will not log a warning and ignore the file if --strict is set to off' do
        Puppet[:strict] = :off
        expect { lookup('g') }.to raise_error(Puppet::Error, /did not find a value for the name 'g'/)
        expect(warnings).to include(/hiera.yaml version 3 found at the environment root was ignored/)
      end

      it 'will use the configuration if appointed by global setting but still warn when encountered by environment data provider' do
        Puppet[:strict] = :warning
        Puppet.settings[:hiera_config] = File.join(env_dir, env_name, 'hiera.yaml')
        expect(lookup('g')).to eql('Value g')
        expect(warnings).to include(/hiera.yaml version 3 found at the environment root was ignored/)
      end
    end

    context 'and a global empty Hiera configuration' do
      let(:hiera_yaml_path) { File.join(code_dir, 'hiera.yaml') }
      let(:code_dir_files) do
        {
          'hiera.yaml' => '',
        }
      end

      let(:environment_files) do
        {
          env_name => {
            'hieradata' => {
              'common.yaml' =>  <<-YAML.unindent,
                x: value x (from environment)
                YAML
            }
          }
        }
      end

      before(:each) do
        # Need to set here since spec_helper defines these settings in its "before each"
        Puppet.settings[:hiera_config] = hiera_yaml_path
      end

      it 'uses a Hiera version 3 defaults' do
        expect(lookup('x')).to eql('value x (from environment)')
      end

      context 'obtained using /dev/null', :unless => Puppet.features.microsoft_windows? do
        let(:code_dir_files) { {} }

        it 'uses a Hiera version 3 defaults' do
          Puppet[:hiera_config] = '/dev/null'
          expect(lookup('x')).to eql('value x (from environment)')
        end
      end
    end

    context 'and a global configuration' do
      let(:hiera_yaml) do
        <<-YAML.unindent
        ---
        :backends:
          - yaml
          - json
          - custom
          - hocon
        :yaml:
          :datadir: #{code_dir}/hieradata
        :json:
          :datadir: #{code_dir}/hieradata
        :hocon:
          :datadir: #{code_dir}/hieradata
        :hierarchy:
          - common
          - "%{domain}"
        :merge_behavior: deeper
        YAML
      end

      let(:code_dir_files) do
        {
          'hiera.yaml' => hiera_yaml,
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
            'example.com.yaml' =>  <<-YAML.unindent,
              x: value x (from global example.com.yaml)
              YAML
            'common.json' =>  <<-JSON.unindent,
              {
                "hash_b": {
                  "hash_ba": {
                    "bac": "value hash_b.hash_ba.bac (from global json)"
                  }
                },
                "hash_c": {
                  "hash_ca": {
                    "cac": "value hash_c.hash_ca.cac (from global json)"
                  }
                }
              }
              JSON
            'common.conf' =>  <<-HOCON.unindent,
              // The 'xs' is a value used for testing
              xs = { subkey = value xs.subkey (from global hocon) }
              HOCON
          }
        }
      end

      before(:each) do
        # Need to set here since spec_helper defines these settings in its "before each"
        Puppet.settings[:codedir] = populated_code_dir
        Puppet.settings[:hiera_config] = File.join(code_dir, 'hiera.yaml')
      end

      around(:each) do |example|
        # Faking the load path to enable 'require' to load from 'ruby_stuff'. It removes the need for a static fixture
        # for the custom backend
        $LOAD_PATH.unshift(populated_ruby_dir)
        begin
          Puppet.override(:environments => environments, :current_environment => env) do
            example.run
          end
        ensure
          if Kernel.const_defined?(:Hiera) && Hiera.const_defined?(:Backend)
            Hiera::Backend.send(:remove_const, :Custom_backend) if Hiera::Backend.const_defined?(:Custom_backend)
            Hiera::Backend.send(:remove_const, :Other_backend) if Hiera::Backend.const_defined?(:Other_backend)
          end
          $LOAD_PATH.shift
        end
      end

      context 'version 3' do
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
            { 'hash_ba' => { 'bab' => 'value hash_b.hash_ba.bab (from global)', 'bac' => 'value hash_b.hash_ba.bac (from global json)' } })
        end

        it 'uses the merge from lookup options to merge all layers and override merge_behavior specified in global hiera.yaml' do
          expect(lookup('hash_c')).to eql(
            { 'hash_ca' => { 'cab' => 'value hash_c.hash_ca.cab (from global)' } })
        end

        it 'uses the explicitly given merge to override lookup options and to merge all layers' do
          expect(lookup('hash_c', 'merge' => 'deep')).to eql(
            {
              'hash_ca' =>
              {
                'caa' => 'value hash_c.hash_ca.caa (from environment)',
                'cab' => 'value hash_c.hash_ca.cab (from global)',
                'cac' => 'value hash_c.hash_ca.cac (from global json)',
                'cad' => 'value hash_c.hash_ca.cad (from global custom)'
              }
            })
        end

        it 'paths are interpolated' do
          expect(lookup('x')).to eql('value x (from global example.com.yaml)')
        end

        it 'backend data sources are propagated to custom backend' do
          expect(lookup('datasources')).to eql(['common', 'example.com'])
        end

        it 'delegates configured hocon backend to hocon_data function' do
          expect(explain('xs')).to match(/Hierarchy entry "hocon"\n.*\n.*\n.*"common"\n\s*Found key: "xs"/m)
        end

        it 'can dig down into subkeys provided by hocon_data function' do
          expect(lookup('xs.subkey')).to eql('value xs.subkey (from global hocon)')
        end

        context 'using an eyaml backend' do
          let(:private_key_name) { 'private_key.pkcs7.pem' }
          let(:public_key_name) { 'public_key.pkcs7.pem' }

          let(:private_key) do
            <<-PKCS7.unindent
              -----BEGIN RSA PRIVATE KEY-----
              MIIEogIBAAKCAQEAwHB3GvImq59em4LV9DMfP0Zjs21eW3Jd5I9fuY0jLJhIkH6f
              CR7tyOpYV6xUj+TF8giq9WLxZI7sourMJMWjEWhVjgUr5lqp1RLv4lwfDv3Wk4XC
              2LUuqj1IAErUXKeRz8i3lUSZW1Pf4CaMpnIiPdWbz6f0KkaJSFi9bqexONBx4fKQ
              NlgZwm2/aYjjrYng788I0QhWDKUqsQOi5mZKlHNRsDlk7J3Afhsx/jTLrCX/G8+2
              tPtLsHyRN39kluM5vYHbKXDsCG/a88Z2yUE2+r4Clp0FUKffiEDBPm0/H0sQ4Q1o
              EfQFDQRKaIkhpsm0nOnLYTy3/xJc5uqDNkLiawIDAQABAoIBAE98pNXOe8ab93oI
              mtNZYmjCbGAqprTjEoFb71A3SfYbmK2Gf65GxjUdBwx/tBYTiuekSOk+yzKcDoZk
              sZnmwKpqDByzaiSmAkxunANFxdZtZvpcX9UfUX0j/t+QCROUa5gF8j6HrUiZ5nkx
              sxr1PcuItekaGLJ1nDLz5JsWTQ+H4M+GXQw7/t96x8v8g9el4exTiAHGk6Fv16kD
              017T02M9qTTmV3Ab/enDIBmKVD42Ta36K/wc4l1aoUQNiRbIGVh96Cgd1CFXLF3x
              CsaNbYT4SmRXaYqoj6MKq+QFEGxadFmJy48NoSd4joirIn2lUjHxJebw3lLbNLDR
              uvQnQ2ECgYEA/nD94wEMr6078uMv6nKxPpNGq7fihwSKf0G/PQDqrRmjUCewuW+k
              /iXMe1Y/y0PjFeNlSbUsUvKQ5xF7F/1AnpuPHIrn3cjGVLb71W+zen1m8SnhsW/f
              7dPgtcb4SCvfhmLgoov+P34YcNfGi6qgPUu6319IqoB3BIi7PvfEomkCgYEAwZ4+
              V0bMjFdDn2hnYzjTNcF2aUQ1jPvtuETizGwyCbbMLl9522lrjC2DrH41vvqX35ct
              CBJkhQFbtHM8Gnmozv0vxhI2jP+u14mzfePZsaXuYrEgWRj+BCsYUHodXryxnEWj
              yVrTNskab1B5jFm2SCJDmKcycBOYpRBLCMx6W7MCgYBA99z7/6KboOIzzKrJdGup
              jLV410UyMIikoccQ7pD9jhRTPS80yjsY4dHqlEVJw5XSWvPb9DTTITi6p44EvBep
              6BKMuTMnQELUEr0O7KypVCfa4FTOl8BX28f+4kU3OGykxc6R8qkC0VGwTohV1UWB
              ITsgGhZV4uOA9uDI3T8KMQKBgEnQY2HwmuDSD/TA39GDA3qV8+ez2lqSXRGIKZLX
              mMf9SaBQQ+uzKA4799wWDbVuYeIbB07xfCL83pJP8FUDlqi6+7Celu9wNp7zX1ua
              Nw8z/ErhzjxJe+Xo7A8aTwIkG+5A2m1UU/up9YsEeiJYvVaIwY58B42U2vfq20BS
              fD9jAoGAX2MscBzIsmN+U9R0ptL4SXcPiVnOl8mqvQWr1B4OLgxX7ghht5Fs956W
              bHipxOWMFCPJA/AhNB8q1DvYiD1viZbIALSCJVUkzs4AEFIjiPsCBKxerl7jF6Xp
              1WYSaCmfvoCVEpFNt8cKp4Gq+zEBYAV4Q6TkcD2lDtEW49MuN8A=
              -----END RSA PRIVATE KEY-----
              PKCS7
          end

          let(:public_key) do
            <<-PKCS7.unindent
              -----BEGIN CERTIFICATE-----
              MIIC2TCCAcGgAwIBAgIBATANBgkqhkiG9w0BAQUFADAAMCAXDTE3MDExMzA5MTY1
              MloYDzIwNjcwMTAxMDkxNjUyWjAAMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIB
              CgKCAQEAwHB3GvImq59em4LV9DMfP0Zjs21eW3Jd5I9fuY0jLJhIkH6fCR7tyOpY
              V6xUj+TF8giq9WLxZI7sourMJMWjEWhVjgUr5lqp1RLv4lwfDv3Wk4XC2LUuqj1I
              AErUXKeRz8i3lUSZW1Pf4CaMpnIiPdWbz6f0KkaJSFi9bqexONBx4fKQNlgZwm2/
              aYjjrYng788I0QhWDKUqsQOi5mZKlHNRsDlk7J3Afhsx/jTLrCX/G8+2tPtLsHyR
              N39kluM5vYHbKXDsCG/a88Z2yUE2+r4Clp0FUKffiEDBPm0/H0sQ4Q1oEfQFDQRK
              aIkhpsm0nOnLYTy3/xJc5uqDNkLiawIDAQABo1wwWjAPBgNVHRMBAf8EBTADAQH/
              MB0GA1UdDgQWBBSejWrVnw7QaBjNFCHMNFi+doSOcTAoBgNVHSMEITAfgBSejWrV
              nw7QaBjNFCHMNFi+doSOcaEEpAIwAIIBATANBgkqhkiG9w0BAQUFAAOCAQEAAe85
              BQ1ydAHFqo0ib38VRPOwf5xPHGbYGhvQi4/sU6aTuR7pxaOJPYz05jLhS+utEmy1
              sknBq60G67yhQE7IHcfwrl1arirG2WmKGvAbjeYL2K1UiU0pVD3D+Klkv/pK6jIQ
              eOJRGb3qNUn0Sq9EoYIOXiGXQ641F0bZZ0+5H92kT1lmnF5oLfCb84ImD9T3snH6
              pIr5RKRx/0YmJIcv3WdpoPT903rOJiRIEgIj/hDk9QZTBpm222Ul5yQQ5pBywpSp
              xh0bmJKAQWhQm7QlybKfyaQmg5ot1jEzWAvD2I5FjHQxmAlchjb6RreaRhExj+JE
              5O117dMBdzDBjcNMOA==
              -----END CERTIFICATE-----
              PKCS7
          end

          let(:keys_dir) do
            keys = tmpdir('keys')
            dir_contained_in(keys, {
              private_key_name => private_key,
              public_key_name => public_key
            })
            keys
          end

          let(:private_key_path) { File.join(keys_dir, private_key_name) }
          let(:public_key_path) { File.join(keys_dir, public_key_name) }
          let(:hiera_yaml) do
            <<-YAML.unindent
            :backends:
              - eyaml
              - yaml
            :eyaml:
              :datadir: #{code_dir}/hieradata
              :pkcs7_private_key: #{private_key_path}
              :pkcs7_public_key: #{public_key_path}
            :yaml:
              :datadir: #{code_dir}/hieradata
            :hierarchy:
              - common
           YAML
          end

          let(:data_files) do
            {
              'common.yaml' => <<-YAML.unindent,
                b: value 'b' (from global)
                c:
                  c_a: value c_a (from global)
                YAML
              'common.eyaml' => <<-YAML.unindent
                a: >
                  ENC[PKCS7,MIIBmQYJKoZIhvcNAQcDoIIBijCCAYYCAQAxggEhMIIBHQIBADAFMAACAQEw
                  DQYJKoZIhvcNAQEBBQAEggEAH457bsfL8kYw9O50roE3dcE21nCnmPnQ2XSX
                  LYRJ2C78LarbfFonKz0gvDW7tyhsLWASFCFaiU8T1QPBd2b3hoQK8E4B2Ual
                  xga/K7r9y3OSgRomTm9tpTltC6re0Ubh3Dy71H61obwxEdNVTqjPe95+m2b8
                  6zWZVnzZzXXsTG1S17yJn1zaB/LXHbWNy4KyLLKCGAml+Gfl6ZMjmaplTmUA
                  QIC5rI8abzbPP3TDMmbLOGNkrmLqI+3uS8tSueTMoJmWaMF6c+H/cA7oRxmV
                  QCeEUVXjyFvCHcmbA+keS/RK9XF+vc07/XS4XkYSPs/I5hLQji1y9bkkGAs0
                  tehxQjBcBgkqhkiG9w0BBwEwHQYJYIZIAWUDBAEqBBDHpA6Fcl/R16aIYcow
                  oiO4gDAvfFH6jLUwXkcYtagnwdmhkd9TQJtxNWcIwMpvmk036MqIoGwwhQdg
                  gV4beiCFtLU=]
                a_ref: "A reference to %{hiera('a')}"
                b_ref: "A reference to %{hiera('b')}"
                c_ref: "%{alias('c')}"
                YAML
            }
          end

          let(:code_dir_files) do
            {
              'hiera.yaml' => hiera_yaml,
              'hieradata' => data_files
            }
          end

          before(:each) do
            Puppet.settings[:hiera_config] = File.join(code_dir, 'hiera.yaml')
          end

          it 'finds data in the global layer' do
            expect(lookup('a')).to eql("Encrypted value 'a' (from global)")
          end

          it 'can use a hiera interpolation' do
            expect(lookup('a_ref')).to eql("A reference to Encrypted value 'a' (from global)")
          end

          it 'can use a hiera interpolation that refers back to yaml' do
            expect(lookup('b_ref')).to eql("A reference to value 'b' (from global)")
          end

          it 'can use a hiera interpolation that refers back to yaml, but only in global layer' do
            expect(lookup(['c', 'c_ref'], 'merge' => 'deep')).to eql([{'c_a' => 'value c_a (from global)', 'c_b' => 'value c_b (from environment)'}, { 'c_a' => 'value c_a (from global)' }])
          end

          it 'delegates configured eyaml backend to eyaml_lookup_key function' do
            expect(explain('a')).to match(/Hierarchy entry "eyaml"\n.*\n.*\n.*"common"\n\s*Found key: "a"/m)
          end
        end

        context 'using deep_merge_options supported by deep_merge gem but not supported by Puppet' do

          let(:hiera_yaml) do
            <<-YAML.unindent
              ---
              :backends:
                - yaml
              :yaml:
                :datadir: #{code_dir}/hieradata
              :hierarchy:
                - other
                - common
              :merge_behavior: deeper
              :deep_merge_options:
                :unpack_arrays: ','
              YAML
          end

          let(:code_dir_files) do
            {
              'hiera.yaml' => hiera_yaml,
              'hieradata' => {
                'common.yaml' => <<-YAML.unindent,
                  h:
                    - x1,x2
                  str: a string
                  mixed:
                    x: hx
                    y: hy
                  YAML
                'other.yaml' => <<-YAML.unindent,
                  h:
                    - x3
                    - x4
                  str: another string
                  mixed:
                    - h1
                    - h2
                  YAML
              }
            }
          end

          it 'honors option :unpack_arrays: (unsupported by puppet)' do
            expect(lookup('h')).to eql(%w(x1 x2 x3 x4))
          end

          it 'will treat merge of strings as a unique (first found)' do
            expect(lookup('str')).to eql('another string')
          end

          it 'will treat merge of array and hash as a unique (first found)' do
            expect(lookup('mixed')).to eql(%w(h1 h2))
          end

          context 'together with a custom backend' do
            let(:hiera_yaml) do
              <<-YAML.unindent
                ---
                :backends:
                  - custom
                  - yaml
                :yaml:
                  :datadir: #{code_dir}/hieradata
                :hierarchy:
                  - other
                  - common
                :merge_behavior: #{merge_behavior}
                :deep_merge_options:
                  :unpack_arrays: ','
                YAML
            end

            context "using 'deeper'" do
              let(:merge_behavior) { 'deeper' }
              it 'honors option :unpack_arrays: (unsupported by puppet)' do
                expect(lookup('h')).to eql(%w(x1 x2 x3 x4 x5 x6))
              end
            end

            context "using 'deep'" do
              let(:merge_behavior) { 'deep' }
              it 'honors option :unpack_arrays: (unsupported by puppet)' do
                expect(lookup('h')).to eql(%w(x5 x6 x3 x4 x1 x2))
              end
            end
          end
        end

        context 'using relative datadir paths' do
          let(:hiera_yaml) do
            <<-YAML.unindent
          ---
          :backends:
            - yaml
          :yaml:
            :datadir: relative_data
          :hierarchy:
            - common
            YAML
          end

          let(:populated_code_dir) do
            dir_contained_in(code_dir, code_dir_files.merge({
              'fake_cwd' => {
                'relative_data' => {
                  'common.yaml' => <<-YAML.unindent
                    a: value a (from fake_cwd/relative_data/common.yaml)
                  YAML
                }
              }
            }))
            code_dir
          end

          around(:each) do |example|
            cwd = Dir.pwd
            Dir.chdir(File.join(code_dir, 'fake_cwd'))
            begin
              example.run
            ensure
              Dir.chdir(cwd)
            end
          end

          it 'finds data from data file beneath relative datadir' do
            expect(lookup('a')).to eql('value a (from fake_cwd/relative_data/common.yaml)')
          end
        end
      end

      context 'version 5' do
        let(:hiera_yaml) do
          <<-YAML.unindent
          ---
          version: 5
          defaults:
            datadir: hieradata

          hierarchy:
            - name: Yaml
              data_hash: yaml_data
              paths:
                - common.yaml
                - "%{domain}.yaml"
            - name: Json
              data_hash: json_data
              paths:
                - common.json
                - "%{domain}.json"
            - name: Hocon
              data_hash: hocon_data
              paths:
                - common.conf
                - "%{domain}.conf"
            - name: Custom
              hiera3_backend: custom
              paths:
                - common.custom
                - "%{domain}.custom"
            - name: Other
              hiera3_backend: other
              options:
                other_option: value of other_option
              paths:
                - common.other
                - "%{domain}.other"
              YAML
        end

        it 'finds global data and reports no deprecation warnings' do
          expect(lookup('a')).to eql('value a (from global)')
          expect(warnings).to be_empty
        end

        it 'explain contains output from global layer' do
          explanation = explain('a')
          expect(explanation).to include('Global Data Provider (hiera configuration version 5)')
          expect(explanation).to include('Hierarchy entry "Yaml"')
          expect(explanation).to include('Hierarchy entry "Json"')
          expect(explanation).to include('Hierarchy entry "Hocon"')
          expect(explanation).to include('Hierarchy entry "Custom"')
          expect(explanation).to include('Found key: "a" value: "value a (from global)"')
        end

        it 'uses the explicitly given merge to override lookup options and to merge all layers' do
          expect(lookup('hash_c', 'merge' => 'deep')).to eql(
            {
              'hash_ca' =>
                {
                  'caa' => 'value hash_c.hash_ca.caa (from environment)',
                  'cab' => 'value hash_c.hash_ca.cab (from global)',
                  'cac' => 'value hash_c.hash_ca.cac (from global json)',
                  'cad' => 'value hash_c.hash_ca.cad (from global custom)'
                }
            })
        end

        it 'backend data sources are propagated to custom backend' do
          expect(lookup('datasources')).to eql(['common', 'example.com'])
        end

        it 'backend specific options are propagated to custom backend' do
          expect(lookup('other_option')).to eql('value of other_option')
        end

        it 'multiple hiera3_backend declarations can be used and are merged into the generated config' do
          expect(lookup(['datasources', 'other_option'])).to eql([['common', 'example.com'], 'value of other_option'])
          expect(Hiera::Config.instance_variable_get(:@config)).to eql(
            {
              :backends => ['custom', 'other'],
              :hierarchy => ['common', '%{domain}'],
              :custom => { :datadir => "#{code_dir}/hieradata" },
              :other => { :other_option => 'value of other_option', :datadir=>"#{code_dir}/hieradata" },
              :logger => 'puppet'
            })
        end

        it 'provides a sensible error message when the hocon library is not loaded' do
          Puppet.features.stubs(:hocon?).returns(false)

          expect { lookup('a') }.to raise_error do |e|
            expect(e.message).to match(/Lookup using Hocon data_hash function is not supported without hocon library/)
          end
        end
      end

      context 'with a hiera3_backend that has no paths' do
        let(:hiera_yaml) do
          <<-YAML.unindent
          ---
          version: 5
          hierarchy:
            - name: Custom
              hiera3_backend: custom
          YAML
        end

        it 'calls the backend' do
          expect(lookup('hash_c')).to eql(
            { 'hash_ca' => { 'cad' => 'value hash_c.hash_ca.cad (from global custom)' }})
        end
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

        context 'with a Hiera v3 configuration' do
          let(:mod_a_files) do
            {
              'mod_a' => {
                'hiera.yaml' => <<-YAML.unindent
                  ---
                  :backends: yaml
                  YAML
              }
            }
          end

          it 'raises an error' do
            expect { lookup('mod_a::a') }.to raise_error(Puppet::Error, /hiera configuration version 3 cannot be used in a module/)
          end
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

      context 'using a lookup_key that uses a path' do
        let(:mod_a_files) do
          {
            'mod_a' => {
              'functions' => {
                'pp_lookup_key.pp' => <<-PUPPET.unindent
                  function mod_a::pp_lookup_key($key, $options, $context) {
                    if !$context.cache_has_key(undef) {
                      $context.cache_all(yaml_data($options, $context))
                      $context.cache(undef, true)
                    }
                    if $context.cache_has_key($key) { $context.cached_value($key) } else { $context.not_found }
                  }
                  PUPPET
              },
              'hiera.yaml' => <<-YAML.unindent,
                ---
                version: 5
                hierarchy:
                  - name: "Common"
                    lookup_key: mod_a::pp_lookup_key
                    path: common.yaml
                YAML
              'data' => {
                'common.yaml' => <<-YAML.unindent
                  mod_a::b: value mod_a::b (from mod_a)
                  YAML
              }
            }
          }
        end

        it 'finds data in the module' do
          expect(lookup('mod_a::b')).to eql('value mod_a::b (from mod_a)')
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

    context 'and an eyaml lookup_key function' do
      let(:private_key_name) { 'private_key.pkcs7.pem' }
      let(:public_key_name) { 'public_key.pkcs7.pem' }

      let(:private_key) do
        <<-PKCS7.unindent
          -----BEGIN RSA PRIVATE KEY-----
          MIIEogIBAAKCAQEAwHB3GvImq59em4LV9DMfP0Zjs21eW3Jd5I9fuY0jLJhIkH6f
          CR7tyOpYV6xUj+TF8giq9WLxZI7sourMJMWjEWhVjgUr5lqp1RLv4lwfDv3Wk4XC
          2LUuqj1IAErUXKeRz8i3lUSZW1Pf4CaMpnIiPdWbz6f0KkaJSFi9bqexONBx4fKQ
          NlgZwm2/aYjjrYng788I0QhWDKUqsQOi5mZKlHNRsDlk7J3Afhsx/jTLrCX/G8+2
          tPtLsHyRN39kluM5vYHbKXDsCG/a88Z2yUE2+r4Clp0FUKffiEDBPm0/H0sQ4Q1o
          EfQFDQRKaIkhpsm0nOnLYTy3/xJc5uqDNkLiawIDAQABAoIBAE98pNXOe8ab93oI
          mtNZYmjCbGAqprTjEoFb71A3SfYbmK2Gf65GxjUdBwx/tBYTiuekSOk+yzKcDoZk
          sZnmwKpqDByzaiSmAkxunANFxdZtZvpcX9UfUX0j/t+QCROUa5gF8j6HrUiZ5nkx
          sxr1PcuItekaGLJ1nDLz5JsWTQ+H4M+GXQw7/t96x8v8g9el4exTiAHGk6Fv16kD
          017T02M9qTTmV3Ab/enDIBmKVD42Ta36K/wc4l1aoUQNiRbIGVh96Cgd1CFXLF3x
          CsaNbYT4SmRXaYqoj6MKq+QFEGxadFmJy48NoSd4joirIn2lUjHxJebw3lLbNLDR
          uvQnQ2ECgYEA/nD94wEMr6078uMv6nKxPpNGq7fihwSKf0G/PQDqrRmjUCewuW+k
          /iXMe1Y/y0PjFeNlSbUsUvKQ5xF7F/1AnpuPHIrn3cjGVLb71W+zen1m8SnhsW/f
          7dPgtcb4SCvfhmLgoov+P34YcNfGi6qgPUu6319IqoB3BIi7PvfEomkCgYEAwZ4+
          V0bMjFdDn2hnYzjTNcF2aUQ1jPvtuETizGwyCbbMLl9522lrjC2DrH41vvqX35ct
          CBJkhQFbtHM8Gnmozv0vxhI2jP+u14mzfePZsaXuYrEgWRj+BCsYUHodXryxnEWj
          yVrTNskab1B5jFm2SCJDmKcycBOYpRBLCMx6W7MCgYBA99z7/6KboOIzzKrJdGup
          jLV410UyMIikoccQ7pD9jhRTPS80yjsY4dHqlEVJw5XSWvPb9DTTITi6p44EvBep
          6BKMuTMnQELUEr0O7KypVCfa4FTOl8BX28f+4kU3OGykxc6R8qkC0VGwTohV1UWB
          ITsgGhZV4uOA9uDI3T8KMQKBgEnQY2HwmuDSD/TA39GDA3qV8+ez2lqSXRGIKZLX
          mMf9SaBQQ+uzKA4799wWDbVuYeIbB07xfCL83pJP8FUDlqi6+7Celu9wNp7zX1ua
          Nw8z/ErhzjxJe+Xo7A8aTwIkG+5A2m1UU/up9YsEeiJYvVaIwY58B42U2vfq20BS
          fD9jAoGAX2MscBzIsmN+U9R0ptL4SXcPiVnOl8mqvQWr1B4OLgxX7ghht5Fs956W
          bHipxOWMFCPJA/AhNB8q1DvYiD1viZbIALSCJVUkzs4AEFIjiPsCBKxerl7jF6Xp
          1WYSaCmfvoCVEpFNt8cKp4Gq+zEBYAV4Q6TkcD2lDtEW49MuN8A=
          -----END RSA PRIVATE KEY-----
          PKCS7
      end

      let(:public_key) do
        <<-PKCS7.unindent
          -----BEGIN CERTIFICATE-----
          MIIC2TCCAcGgAwIBAgIBATANBgkqhkiG9w0BAQUFADAAMCAXDTE3MDExMzA5MTY1
          MloYDzIwNjcwMTAxMDkxNjUyWjAAMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIB
          CgKCAQEAwHB3GvImq59em4LV9DMfP0Zjs21eW3Jd5I9fuY0jLJhIkH6fCR7tyOpY
          V6xUj+TF8giq9WLxZI7sourMJMWjEWhVjgUr5lqp1RLv4lwfDv3Wk4XC2LUuqj1I
          AErUXKeRz8i3lUSZW1Pf4CaMpnIiPdWbz6f0KkaJSFi9bqexONBx4fKQNlgZwm2/
          aYjjrYng788I0QhWDKUqsQOi5mZKlHNRsDlk7J3Afhsx/jTLrCX/G8+2tPtLsHyR
          N39kluM5vYHbKXDsCG/a88Z2yUE2+r4Clp0FUKffiEDBPm0/H0sQ4Q1oEfQFDQRK
          aIkhpsm0nOnLYTy3/xJc5uqDNkLiawIDAQABo1wwWjAPBgNVHRMBAf8EBTADAQH/
          MB0GA1UdDgQWBBSejWrVnw7QaBjNFCHMNFi+doSOcTAoBgNVHSMEITAfgBSejWrV
          nw7QaBjNFCHMNFi+doSOcaEEpAIwAIIBATANBgkqhkiG9w0BAQUFAAOCAQEAAe85
          BQ1ydAHFqo0ib38VRPOwf5xPHGbYGhvQi4/sU6aTuR7pxaOJPYz05jLhS+utEmy1
          sknBq60G67yhQE7IHcfwrl1arirG2WmKGvAbjeYL2K1UiU0pVD3D+Klkv/pK6jIQ
          eOJRGb3qNUn0Sq9EoYIOXiGXQ641F0bZZ0+5H92kT1lmnF5oLfCb84ImD9T3snH6
          pIr5RKRx/0YmJIcv3WdpoPT903rOJiRIEgIj/hDk9QZTBpm222Ul5yQQ5pBywpSp
          xh0bmJKAQWhQm7QlybKfyaQmg5ot1jEzWAvD2I5FjHQxmAlchjb6RreaRhExj+JE
          5O117dMBdzDBjcNMOA==
          -----END CERTIFICATE-----
          PKCS7
      end

      let(:keys_dir) do
        keys = tmpdir('keys')
        dir_contained_in(keys, {
          private_key_name => private_key,
          public_key_name => public_key
        })
        keys
      end

      let(:private_key_path) { File.join(keys_dir, private_key_name) }
      let(:public_key_path) { File.join(keys_dir, public_key_name) }

      let(:env_hiera_yaml) do
        <<-YAML.unindent
          version: 5
          hierarchy:
            - name: EYaml
              path: common.eyaml
              lookup_key: eyaml_lookup_key
              options:
                pkcs7_private_key: #{private_key_path}
                pkcs7_public_key: #{public_key_path}
          YAML
      end

      let(:data_files) do
        {
          'common.eyaml' => <<-YAML.unindent
            a: >
              ENC[PKCS7,MIIBmQYJKoZIhvcNAQcDoIIBijCCAYYCAQAxggEhMIIBHQIBADAFMAACAQEw
              DQYJKoZIhvcNAQEBBQAEggEAUwwNRA5ZKM87SLnjnJfzDFRQbeheSYMTOhcr
              sgTPCGtzEAzvRBrkdIRAvDZVRfadV9OB+bJsYrhWIkU1bYiOn1m78ginh96M
              44RuspnIZYnL9Dhs+JyC8VvB5nlvlEph2RGt+KYg9iU4JYhwZ2+8+yxB6/UK
              H5HGKDCjBbEc8o9MbCckLsciIh11hKKgT6K0yhKB/nBxxM78nrX0BxmAHX2u
              bejKDRa9S/0uS7Y91nvnbIkaQpZ4KteSQ+J4/lQBMlMAeE+2F9ncM8jFKnQC
              rzzdbn1O/zwsEt5J5CRP1Sc+8hM644+IqkLs+17segxArHVGOsEqyDcHbXEK
              9jspfzBcBgkqhkiG9w0BBwEwHQYJYIZIAWUDBAEqBBCIq/L5HeJgA9XQm67j
              JHUngDDS5s52FsuSIMin7Z/pV+XuaJGFkL80ia4bXnCWilmtM8oUa/DZuBje
              dCILO7I8QqU=]
            hash_a:
              hash_aa:
                aaa: >
                  ENC[PKCS7,MIIBqQYJKoZIhvcNAQcDoIIBmjCCAZYCAQAxggEhMIIBHQIBADAFMAACAQEw
                  DQYJKoZIhvcNAQEBBQAEggEAhvGXL5RxVUs9wdqJvpCyXtfCHrm2HbG/u30L
                  n8EuRD9ravlsgIISAnd27JPtrxA+0rZq4EQRGz6OcovnH9vTg86/lVBhhPnz
                  b83ArptGJhRvTYUJ19GZI3AYjJbhWj/Jo5NL56oQJaPBccqHxMApm/U0wlus
                  QtASL94cLuh4toVIBQCQzD5/Bx51p2wQobm9p4WKSl1zJhDceurmoLZXqhuN
                  JwwEBwXopJvgid3ZDPbdX8nI6vHhb/8wDq9yb5DOsrkgqDqQgwPU9sUUioQj
                  Hr1pGyeOWnbEe99iEb2+m7TWsC0NN7OBo06mAgFNbBLjvn2k4PiCxrOOgJ8S
                  LI5eXjBsBgkqhkiG9w0BBwEwHQYJYIZIAWUDBAEqBBCWNS6j3m/Xvrp5RFaN
                  ovm/gEB4oPlYJswoXuWqcEBfwZzbpy96x3b2Le/yoa72ylbPAUc5GfLENvFQ
                  zXpTtSmQE0fixY4JMaBTke65ZRvoiOQO]
            array_a:
              - >
                ENC[PKCS7,MIIBeQYJKoZIhvcNAQcDoIIBajCCAWYCAQAxggEhMIIBHQIBADAFMAACAQEw
                DQYJKoZIhvcNAQEBBQAEggEAmXZfyfU77vVCZqHpR10qhD0Jy9DpMGBgal97
                vUO2VHX7KlCgagK0kz8/uLRIthkYzcpn8ISmw/+CIAny3jOjxOsylJiujqyu
                hx/JEFl8bOKOg40Bd0UuBaw/qZ+CoAtOorhiIW7x6t7DpknItC6gkH/cSJ4/
                p3MdhoARRuwj2fvuaChVsD39l2rXjgJj0OJOaDXdbuisG75VRZf5l8IH6+44
                Q7m6W7BU69LX+ozn+W3filQoiJ5MPf8w/KXAObMSbKYIDsrZUyIWyyNUbpW0
                MieIkHj93bX3gIEcenECLdWaEzcPa7MHgl6zevQKg4H0JVmcvKYyfHYqcrVE
                PqizKDA8BgkqhkiG9w0BBwEwHQYJYIZIAWUDBAEqBBDf259KZEay1widVSFy
                I9zGgBAICjm0x2GeqoCnHdiAA+jt]
              - >
                ENC[PKCS7,MIIBeQYJKoZIhvcNAQcDoIIBajCCAWYCAQAxggEhMIIBHQIBADAFMAACAQEw
                DQYJKoZIhvcNAQEBBQAEggEATVy4hHG356INFKOswAhoravh66iJljp+Vn3o
                UVD1kyRiqY5tz3UVSptzUmzD+YssX/f73AKCjUI3HrPNL7kAxsk6fWS7nDEj
                AuxtCqGYeBha6oYJYziSGIHfAdY3MiJUI1C9g/OQB4TTvKdrlDArPiY8THJi
                bzLLMbVQYJ6ixSldwkdKD75vtikyamx+1LSyVBSg8maVyPvLHtLZJuT71rln
                WON3Ious9PIbd+izbcCzaoqh5UnTfDCjOuAYliXalBxamIIwNzSV1sdR8/qf
                t22zpYK4J8lgCBV2gKfrOWSi9MAs6JhCeOb8wNLMmAUTbc0WrFJxoCwAPX0z
                MAjsNjA8BgkqhkiG9w0BBwEwHQYJYIZIAWUDBAEqBBC4v4bNE4gFlbLmVY+9
                BtSLgBBm7U0wu6d6s9wF9Ek9IHPe]
            YAML
        }
      end

      let(:env_data) { data_files }

      it 'finds data in the environment' do
        expect(lookup('a')).to eql("Encrypted value 'a' (from environment)")
      end

      it 'can read encrypted values inside a hash' do
        expect(lookup('hash_a.hash_aa.aaa')).to eql('Encrypted value hash_a.hash_aa.aaa (from environment)')
      end

      it 'can read encrypted values inside an array' do
        expect(lookup('array_a')).to eql(['array_a[0]', 'array_a[1]'])
      end

      context 'declared in global scope as a Hiera v3 backend' do
        let(:environment_files) { {} }
        let(:hiera_yaml) do
          <<-YAML.unindent
          :backends: eyaml
          :eyaml:
            :datadir: #{code_dir}/hieradata
            :pkcs7_private_key: #{private_key_path}
            :pkcs7_public_key: #{public_key_path}
          :hierarchy:
            - common
          YAML
        end

        let(:data_files) do
          {
            'common.eyaml' => <<-YAML.unindent
              a: >
                ENC[PKCS7,MIIBmQYJKoZIhvcNAQcDoIIBijCCAYYCAQAxggEhMIIBHQIBADAFMAACAQEw
                DQYJKoZIhvcNAQEBBQAEggEAH457bsfL8kYw9O50roE3dcE21nCnmPnQ2XSX
                LYRJ2C78LarbfFonKz0gvDW7tyhsLWASFCFaiU8T1QPBd2b3hoQK8E4B2Ual
                xga/K7r9y3OSgRomTm9tpTltC6re0Ubh3Dy71H61obwxEdNVTqjPe95+m2b8
                6zWZVnzZzXXsTG1S17yJn1zaB/LXHbWNy4KyLLKCGAml+Gfl6ZMjmaplTmUA
                QIC5rI8abzbPP3TDMmbLOGNkrmLqI+3uS8tSueTMoJmWaMF6c+H/cA7oRxmV
                QCeEUVXjyFvCHcmbA+keS/RK9XF+vc07/XS4XkYSPs/I5hLQji1y9bkkGAs0
                tehxQjBcBgkqhkiG9w0BBwEwHQYJYIZIAWUDBAEqBBDHpA6Fcl/R16aIYcow
                oiO4gDAvfFH6jLUwXkcYtagnwdmhkd9TQJtxNWcIwMpvmk036MqIoGwwhQdg
                gV4beiCFtLU=]
              YAML
          }
        end

        let(:code_dir_files) do
          {
            'hiera.yaml' => hiera_yaml,
            'hieradata' => data_files
          }
        end

        before(:each) do
          Puppet.settings[:hiera_config] = File.join(code_dir, 'hiera.yaml')
        end

        it 'finds data in the global layer' do
          expect(lookup('a')).to eql("Encrypted value 'a' (from global)")
        end

        it 'delegates configured eyaml backend to eyaml_lookup_key function' do
          expect(explain('a')).to match(/Hierarchy entry "eyaml"\n.*\n.*\n.*"common"\n\s*Found key: "a"/m)
        end
      end
    end
  end
end
