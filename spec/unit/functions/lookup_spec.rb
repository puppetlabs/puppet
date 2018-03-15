#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/compiler'
require 'puppet_spec/files'
require 'puppet/pops'
require 'deep_merge/core'

describe "The lookup function" do
  include PuppetSpec::Compiler
  include PuppetSpec::Files

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

  let(:env_data) { {} }

  let(:environment_files) do
    {
      env_name => {
        'modules' => env_modules,
        'hiera.yaml' => env_hiera_yaml,
        'data' => env_data
      }
    }
  end

  let(:ruby_dir_files) { {} }

  let(:logs) { [] }
  let(:scope_additions ) { {} }
  let(:notices) { logs.select { |log| log.level == :notice }.map { |log| log.message } }
  let(:warnings) { logs.select { |log| log.level == :warning }.map { |log| log.message } }
  let(:debugs) { logs.select { |log| log.level == :debug }.map { |log| log.message } }
  let(:env) { Puppet::Node::Environment.create(env_name.to_sym, [File.join(populated_env_dir, env_name, 'modules')]) }
  let(:environments) { Puppet::Environments::Directories.new(populated_env_dir, []) }
  let(:node) { Puppet::Node.new('test_lookup', :environment => env) }
  let(:compiler) { Puppet::Parser::Compiler.new(node) }
  let(:lookup_func) { Puppet.lookup(:loaders).puppet_system_loader.load(:function, 'lookup') }
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
      if Hiera.const_defined?(:Backend) && Hiera::Backend.respond_to?(:clear!)
        Hiera::Backend.clear!
      end
    end
  end

  def collect_notices(code, explain = false, &block)
    Puppet[:code] = code
    Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
      scope = compiler.topscope
      scope['domain'] = 'example.com'
      scope_additions.each_pair { |k, v| scope[k] = v }
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

  context 'with faulty hiera.yaml configuration' do
    context 'in global layer' do
      let(:global_data) do
        {
          'common.yaml' => <<-YAML.unindent
            a: value a (from global)
            YAML
        }
      end

      let(:code_dir_files) do
        {
          'hiera.yaml' => hiera_yaml,
          'data' => global_data
        }
      end

      before(:each) do
        # Need to set here since spec_helper defines these settings in its "before each"
        Puppet.settings[:codedir] = populated_code_dir
        Puppet.settings[:hiera_config] = File.join(code_dir, 'hiera.yaml')
      end

      context 'using a not yet supported hiera version' do
        let(:hiera_yaml) { <<-YAML.unindent }
          version: 6
          YAML

        it 'fails and reports error' do
          expect { lookup('a') }.to raise_error("This runtime does not support hiera.yaml version 6 (file: #{code_dir}/hiera.yaml)")
        end
      end

      context 'with multiply defined backend using hiera version 3' do
        let(:hiera_yaml) { <<-YAML.unindent }
          :version: 3
          :backends:
            - yaml
            - json
            - yaml
          YAML

        it 'fails and reports error' do
          expect { lookup('a') }.to raise_error(
            "Backend 'yaml' is defined more than once. First defined at (line: 3) (file: #{code_dir}/hiera.yaml, line: 5)")
        end
      end

      context 'using hiera version 4' do
        let(:hiera_yaml) { <<-YAML.unindent }
          version: 4
          YAML

        it 'fails and reports error' do
          expect { lookup('a') }.to raise_error(
            "hiera.yaml version 4 cannot be used in the global layer (file: #{code_dir}/hiera.yaml)")
        end
      end

      context 'using hiera version 5' do
        context 'with multiply defined hierarchy' do
          let(:hiera_yaml) { <<-YAML.unindent }
            version: 5
            hierarchy:
              - name: Common
                path: common.yaml
              - name: Other
                path: other.yaml
              - name: Common
                path: common.yaml
            YAML

          it 'fails and reports error' do
            expect { lookup('a') }.to raise_error(
              "Hierarchy name 'Common' defined more than once. First defined at (line: 3) (file: #{code_dir}/hiera.yaml, line: 7)")
          end
        end

        context 'with hiera3_backend that is provided as data_hash function' do
          let(:hiera_yaml) { <<-YAML.unindent }
            version: 5
            hierarchy:
              - name: Common
                hiera3_backend: hocon
                path: common.conf
            YAML

          it 'fails and reports error' do
            expect { lookup('a') }.to raise_error(
              "Use \"data_hash: hocon_data\" instead of \"hiera3_backend: hocon\" (file: #{code_dir}/hiera.yaml, line: 4)")
          end
        end

        context 'with no data provider function defined' do
          let(:hiera_yaml) { <<-YAML.unindent }
            version: 5
            defaults:
              datadir: data
            hierarchy:
              - name: Common
                path: common.txt
            YAML

          it 'fails and reports error' do
            expect { lookup('a') }.to raise_error(
              "One of data_hash, lookup_key, data_dig, or hiera3_backend must be defined in hierarchy 'Common' (file: #{code_dir}/hiera.yaml)")
          end
        end

        context 'with multiple data providers in defaults' do
          let(:hiera_yaml) { <<-YAML.unindent }
            version: 5
            defaults:
              data_hash: yaml_data
              lookup_key: eyaml_lookup_key
              datadir: data
            hierarchy:
              - name: Common
                path: common.txt
            YAML

          it 'fails and reports error' do
            expect { lookup('a') }.to raise_error(
              "Only one of data_hash, lookup_key, data_dig, or hiera3_backend can be defined in defaults (file: #{code_dir}/hiera.yaml)")
          end
        end

        context 'with non existing data provider function' do
          let(:hiera_yaml) { <<-YAML.unindent }
            version: 5
            hierarchy:
              - name: Common
                data_hash: nonesuch_txt_data
                path: common.yaml
            YAML

          it 'fails and reports error' do
            Puppet[:strict] = :error
            expect { lookup('a') }.to raise_error(
              "Unable to find 'data_hash' function named 'nonesuch_txt_data' (file: #{code_dir}/hiera.yaml)")
          end
        end

        context 'with a declared default_hierarchy' do
          let(:hiera_yaml) { <<-YAML.unindent }
            version: 5
            hierarchy:
              - name: Common
                path: common.yaml
            default_hierarchy:
              - name: Defaults
                path: defaults.yaml
            YAML

          it 'fails and reports error' do
            Puppet[:strict] = :error
            expect { lookup('a') }.to raise_error(
              "'default_hierarchy' is only allowed in the module layer (file: #{code_dir}/hiera.yaml, line: 5)")
          end
        end

        context 'with missing variables' do
          let(:scope_additions) { { 'fqdn' => 'test.example.com' } }
          let(:hiera_yaml) { <<-YAML.unindent }
            version: 5
            hierarchy:
              - name: Common # don't report this line %{::nonesuch}
                path: "%{::fqdn}/%{::nonesuch}/data.yaml"
            YAML

          it 'fails and reports errors when strict == error' do
            Puppet[:strict] = :error
            expect { lookup('a') }.to raise_error("Undefined variable '::nonesuch' (file: #{code_dir}/hiera.yaml, line: 4)")
          end
        end

        context 'using interpolation functions' do
          let(:hiera_yaml) { <<-YAML.unindent }
            version: 5
            hierarchy:
              - name: Common # don't report this line %{::nonesuch}
                path: "%{lookup('fqdn')}/data.yaml"
            YAML

          it 'fails and reports errors when strict == error' do
            Puppet[:strict] = :error
            expect { lookup('a') }.to raise_error("Interpolation using method syntax is not allowed in this context (file: #{code_dir}/hiera.yaml)")
          end
        end
      end
    end

    context 'in environment layer' do
      context 'using hiera version 4' do
        context 'with an unknown backend' do
          let(:env_hiera_yaml) { <<-YAML.unindent }
            version: 4
            hierarchy:
              - name: Common
                backend: nonesuch
                path: common.yaml
            YAML

          it 'fails and reports error' do
            expect { lookup('a') }.to raise_error(
              "No data provider is registered for backend 'nonesuch' (file: #{env_dir}/spec/hiera.yaml, line: 4)")
          end
        end

        context 'with multiply defined hierarchy' do
          let(:env_hiera_yaml) { <<-YAML.unindent }
            version: 4
            hierarchy:
              - name: Common
                backend: yaml
                path: common.yaml
              - name: Other
                backend: yaml
                path: other.yaml
              - name: Common
                backend: yaml
                path: common.yaml
            YAML

          it 'fails and reports error' do
            expect { lookup('a') }.to raise_error(
              "Hierarchy name 'Common' defined more than once. First defined at (line: 3) (file: #{env_dir}/spec/hiera.yaml, line: 9)")
          end
        end
      end

      context 'using hiera version 5' do
        context 'with a hiera3_backend declaration' do
          let(:env_hiera_yaml) { <<-YAML.unindent }
            version: 5
            hierarchy:
              - name: Common
                hiera3_backend: something
            YAML

          it 'fails and reports error' do
            expect { lookup('a') }.to raise_error(
              "'hiera3_backend' is only allowed in the global layer (file: #{env_dir}/spec/hiera.yaml, line: 4)")
          end
        end

        context 'with a declared default_hierarchy' do
          let(:env_hiera_yaml) { <<-YAML.unindent }
            version: 5
            hierarchy:
              - name: Common
                path: common.yaml
            default_hierarchy:
              - name: Defaults
                path: defaults.yaml
            YAML

          it 'fails and reports error' do
            Puppet[:strict] = :error
            expect { lookup('a') }.to raise_error(
              "'default_hierarchy' is only allowed in the module layer (file: #{env_dir}/spec/hiera.yaml, line: 5)")
          end
        end
      end
    end
  end

  context 'with an environment' do
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

    it 'finds data in the environment' do
      expect(lookup('a')).to eql('value a (from environment)')
    end

    context 'with log-level debug' do
      before(:each) { Puppet[:log_level] = 'debug' }

      it 'does not report a regular lookup as APL' do
        expect(lookup('a')).to eql('value a (from environment)')
        expect(debugs.count { |dbg| dbg =~ /\A\s*Automatic Parameter Lookup of/ }).to eql(0)
      end

      it 'reports regular lookup as lookup' do
        expect(lookup('a')).to eql('value a (from environment)')
        expect(debugs.count { |dbg| dbg =~ /\A\s*Lookup of/ }).to eql(1)
      end

      it 'does not report APL as lookup' do
        collect_notices("class mod_a($a) { notice($a) }; include mod_a")
        expect(debugs.count { |dbg| dbg =~ /\A\s*Lookup of/ }).to eql(0)
      end

      it 'reports APL as APL' do
        collect_notices("class mod_a($a) { notice($a) }; include mod_a")
        expect(debugs.count { |dbg| dbg =~ /\A\s*Automatic Parameter Lookup of/ }).to eql(1)
      end
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
              path: "#{data_path}"
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
              'x_e.yaml' => <<-YAML.unindent,
                y: value y from x_e
                YAML
            }
          }
        }
      end

      context 'using local variable reference' do
        let(:data_path) { 'x%{var.sub}.yaml' }

        it 'reloads the configuration if interpolated values change' do
          Puppet[:log_level] = 'debug'
          collect_notices("notice('success')") do |scope|
            expect(lookup_func.call(scope, 'y')).to eql('value y from x')
            scope['var'] = { 'sub' => '_d' }
            expect(lookup_func.call(scope, 'y')).to eql('value y from x_d')
            nested_scope = scope.compiler.newscope(scope)
            nested_scope['var'] = { 'sub' => '_e' }
            expect(lookup_func.call(nested_scope, 'y')).to eql('value y from x_e')
          end
          expect(notices).to eql(['success'])
          expect(debugs.any? { |m| m =~ /Hiera configuration recreated due to change of scope variables used in interpolation expressions/ }).to be_truthy
        end

        it 'does not include the lookups performed during stability check in explain output' do
          Puppet[:log_level] = 'debug'
          collect_notices("notice('success')") do |scope|
            var = { 'sub' => '_d' }
            scope['var'] = var
            expect(lookup_func.call(scope, 'y')).to eql('value y from x_d')

            # Second call triggers the check
            expect(lookup_func.call(scope, 'y')).to eql('value y from x_d')
          end
          expect(notices).to eql(['success'])
          expect(debugs.any? { |m| m =~ /Sub key: "sub"/ }).to be_falsey
        end
      end

      context 'using global variable reference' do
        let(:data_path) { 'x%{::var.sub}.yaml' }

        it 'reloads the configuration if interpolated that was previously undefined, gets defined' do
          Puppet[:log_level] = 'debug'
          collect_notices("notice('success')") do |scope|
            expect(lookup_func.call(scope, 'y')).to eql('value y from x')
            scope['var'] = { 'sub' => '_d' }
            expect(lookup_func.call(scope, 'y')).to eql('value y from x_d')
          end
          expect(notices).to eql(['success'])
          expect(debugs.any? { |m| m =~ /Hiera configuration recreated due to change of scope variables used in interpolation expressions/ }).to be_truthy
        end

        it 'does not reload the configuration if value changes locally' do
          Puppet[:log_level] = 'debug'
          collect_notices("notice('success')") do |scope|
            scope['var'] = { 'sub' => '_d' }
            expect(lookup_func.call(scope, 'y')).to eql('value y from x_d')
            nested_scope = scope.compiler.newscope(scope)
            nested_scope['var'] = { 'sub' => '_e' }
            expect(lookup_func.call(nested_scope, 'y')).to eql('value y from x_d')
          end
          expect(notices).to eql(['success'])
          expect(debugs.any? { |m| m =~ /Hiera configuration recreated due to change of scope variables used in interpolation expressions/ }).to be_falsey
        end
      end
    end

    context 'that uses reserved' do
       let(:environment_files) do
        { env_name => { 'hiera.yaml' => hiera_yaml } }
      end

      context 'option' do
       let(:hiera_yaml) { <<-YAML.unindent }
          version: 5
          hierarchy:
            - name: "Illegal"
              options:
                #{opt_spec}
              data_hash: yaml_data
          YAML

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

      context 'default option' do
        let(:hiera_yaml) { <<-YAML.unindent }
          ---
          version: 5
          defaults:
              options:
                #{opt_spec}
          hierarchy:
            - name: "Illegal"
              data_hash: yaml_data
          YAML

        context 'path' do
          let(:opt_spec) { 'path: data/foo.yaml' }

          it 'fails and reports the reserved option key' do
            expect { lookup('a') }.to raise_error do |e|
              expect(e.message).to match(/Option key 'path' used in defaults is reserved by Puppet/)
            end
          end
        end

        context 'uri' do
          let(:opt_spec) { 'uri: file:///data/foo.yaml' }

          it 'fails and reports the reserved option key' do
            expect { lookup('a') }.to raise_error do |e|
              expect(e.message).to match(/Option key 'uri' used in defaults is reserved by Puppet/)
            end
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
            expect(e.message).to match(/key 'a'.*data_hash function 'yaml_data'.*using location.*wrong type, expects Puppet::LookupValue, got Runtime/)
          end
        end
      end

      context 'that contains illegal interpolations' do
        context 'in the form of an alias that is not the entire string' do
          let(:common_yaml) { <<-YAML.unindent }
            a: "%{alias('x')} and then some"
            x: value x
            YAML

          it 'fails lookup and reports a type mismatch' do
            expect { lookup('a') }.to raise_error("'alias' interpolation is only permitted if the expression is equal to the entire string")
          end
        end

        context 'in the form of an unknown function name' do
          let(:common_yaml) { <<-YAML.unindent }
            a: "%{what('x')}"
            x: value x
            YAML

          it 'fails lookup and reports a type mismatch' do
            expect { lookup('a') }.to raise_error("Unknown interpolation method 'what'")
          end
        end
      end

      context 'that contains an array with duplicates' do
        let(:common_yaml) { <<-YAML.unindent }
          a:
           - alpha
           - bravo
           - charlie
           - bravo
          YAML

        it 'retains the duplicates when using default merge strategy' do
          expect(lookup('a')).to eql(%w(alpha bravo charlie bravo))
        end

        it 'does deduplification when using merge strategy "unique"' do
          expect(lookup('a', :merge => 'unique')).to eql(%w(alpha bravo charlie))
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

      let(:env_lookup_options) { <<-YAML.unindent }
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

      let(:env_data) do
        {
          'first.yaml' => <<-YAML.unindent + env_lookup_options,
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
            sa:
              sa1: ['e', 'd', '--f']
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
            sa:
              sa1: ['b', 'a', 'f', 'c']
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

      context 'and there are no lookup options that do not use patterns' do

        let(:env_lookup_options) { <<-YAML.unindent }
          lookup_options:
            '^[^b]$':
              merge: deep
            '^c':
              merge: first
            '^b':
              merge: first
            '^mod::ha.*_b':
              merge: hash
          YAML

        it 'finds lookup_options that matches a pattern' do
          expect(lookup('a')).to eql({'aa' => { 'aaa' => 'a.aa.aaa', 'aab' => 'a.aa.aab' }})
        end
      end

      context 'and lookup options use a hash' do

        let(:env_lookup_options) { <<-YAML.unindent }
          lookup_options:
            'sa':
              merge:
                strategy: deep
                knockout_prefix: --
                sort_merged_arrays: true
        YAML

        it 'applies knockout_prefix and sort_merged_arrays' do
          expect(lookup('sa')).to eql({ 'sa1' => %w(a b c d e) })
        end

        it 'overrides knockout_prefix and sort_merged_arrays with explicitly given values' do
          expect(
            lookup('sa', 'merge' => { 'strategy' => 'deep', 'knockout_prefix' => '##', 'sort_merged_arrays' => false })).to(
              eql({ 'sa1' => %w(b a f c e d --f) }))
        end
      end
    end

    context 'and an environment Hiera v5 configuration using globs' do
      let(:env_hiera_yaml) do
        <<-YAML.unindent
        ---
        version: 5
        hierarchy:
          - name: Globs
            globs:
              - "globs/*.yaml"
              - "globs_%{domain}/*.yaml"
        YAML
      end

      let(:env_data) do
        {
          'globs' => {
            'a.yaml' => <<-YAML.unindent,
              glob_a: value glob_a
              YAML
            'b.yaml' => <<-YAML.unindent
              glob_b:
                a: value glob_b.a
                b: value glob_b.b
            YAML
          },
          'globs_example.com' => {
            'a.yaml' => <<-YAML.unindent,
              glob_c: value glob_a
              YAML
            'b.yaml' => <<-YAML.unindent
              glob_d:
                a: value glob_d.a
                b: value glob_d.b
            YAML

          }
        }
      end

      it 'finds environment data using globs' do
        expect(lookup('glob_a')).to eql('value glob_a')
        expect(warnings).to be_empty
      end

      it 'finds environment data using interpolated globs' do
        expect(lookup('glob_d.a')).to eql('value glob_d.a')
        expect(warnings).to be_empty
      end
    end

    context 'and an environment Hiera v5 configuration using uris' do
      let(:env_hiera_yaml) do
        <<-YAML.unindent
        ---
        version: 5
        hierarchy:
          - name: Uris
            uris:
              - "http://test.example.com"
              - "/some/arbitrary/path"
              - "urn:with:opaque:path"
              - "dothis%20-f%20bar"
            data_hash: mod::uri_test_func
        YAML
      end

      let(:env_modules) do
        {
          'mod' => { 'lib' => { 'puppet' => { 'functions' => { 'mod' => { 'uri_test_func.rb' => <<-RUBY } } } } }
            Puppet::Functions.create_function(:'mod::uri_test_func') do
              dispatch :uri_test_func do
                param 'Hash', :options
                param 'Puppet::LookupContext', :context
              end

              def uri_test_func(options, context)
                { 'uri' => [ options['uri'] ] }
              end
            end
            RUBY
        }
      end

      it 'The uris are propagated in the options hash' do
        expect(lookup('uri', 'merge' => 'unique')).to eql(
          %w(http://test.example.com /some/arbitrary/path urn:with:opaque:path dothis%20-f%20bar))
        expect(warnings).to be_empty
      end

      context 'and a uri uses bad syntax' do
        let(:env_hiera_yaml) do
          <<-YAML.unindent
        ---
        version: 5
        hierarchy:
          - name: Uris
            uri: "dothis -f bar"
            data_hash: mod::uri_test_func
          YAML
        end

        it 'an attempt to lookup raises InvalidURIError' do
          expect{ lookup('uri', 'merge' => 'unique') }.to raise_error(/bad URI/)
        end
      end
    end

    context 'and an environment Hiera v5 configuration using mapped_paths' do
      let(:scope_additions) do
        {
          'mapped' =>  {
            'array_var' => ['a', 'b', 'c'],
            'hash_var' => { 'x' => 'a', 'y' => 'b', 'z' => 'c' },
            'string_var' => 's' },
          'var' => 'global_var' # overridden by mapped path variable
        }
      end

      let(:env_hiera_yaml) do
        <<-YAML.unindent
        ---
        version: 5
        hierarchy:
          - name: Mapped Paths
            mapped_paths: #{mapped_paths}
          - name: Global Path
            path: "%{var}.yaml"
        YAML
      end

      let(:environment_files) do
        {
          env_name => {
            'hiera.yaml' => env_hiera_yaml,
            'data' => env_data
          }
        }
      end

      context 'that originates from an array' do
        let (:mapped_paths) { '[mapped.array_var, var, "paths/%{var}.yaml"]' }

        let(:env_data) do
          {
            'paths' => {
              'a.yaml' => <<-YAML.unindent,
                path_a: value path_a
                path_h:
                  a: value path_h.a
                  c: value path_h.c
                YAML
              'b.yaml' => <<-YAML.unindent,
                path_h:
                  b: value path_h.b
                  d: value path_h.d
                YAML
              'd.yaml' => <<-YAML.unindent
                path_h:
                  b: value path_h.b (from d.yaml)
                  d: value path_h.d (from d.yaml)
                YAML
            },
            'global_var.yaml' => <<-YAML.unindent,
              path_h:
                e: value path_h.e
              YAML
            'other_var.yaml' => <<-YAML.unindent
              path_h:
                e: value path_h.e (from other_var.yaml)
              YAML
          }
        end

        it 'finds environment data using mapped_paths' do
          expect(lookup('path_a')).to eql('value path_a')
          expect(warnings).to be_empty
        end

        it 'includes mapped path in explain output' do
          explanation = explain('path_h', 'merge' => 'deep')
          ['a', 'b', 'c'].each do |var|
            expect(explanation).to match(/^\s+Path "#{env_dir}\/spec\/data\/paths\/#{var}\.yaml"\n\s+Original path: "paths\/%\{var\}\.yaml"/)
          end
          expect(warnings).to be_empty
        end

        it 'performs merges between mapped paths and global path interpolated using same key' do
          expect(lookup('path_h', 'merge' => 'hash')).to eql(
            {
              'a' => 'value path_h.a',
              'b' => 'value path_h.b',
              'c' => 'value path_h.c',
              'd' => 'value path_h.d',
              'e' => 'value path_h.e'
            })
          expect(warnings).to be_empty
        end

        it 'keeps track of changes in key overridden by interpolated key' do
          Puppet[:log_level] = 'debug'
          collect_notices("notice('success')") do |scope|
            expect(lookup_func.call(scope, 'path_h', 'merge' => 'hash')).to eql(
              {
                'a' => 'value path_h.a',
                'b' => 'value path_h.b',
                'c' => 'value path_h.c',
                'd' => 'value path_h.d',
                'e' => 'value path_h.e'
              })
            scope.with_local_scope('var' => 'other_var') do
              expect(lookup_func.call(scope, 'path_h', 'merge' => 'hash')).to eql(
                {
                  'a' => 'value path_h.a',
                  'b' => 'value path_h.b',
                  'c' => 'value path_h.c',
                  'd' => 'value path_h.d',
                  'e' => 'value path_h.e (from other_var.yaml)'
                })
            end
          end
          expect(notices).to eql(['success'])
          expect(debugs.any? { |m| m =~ /Hiera configuration recreated due to change of scope variables used in interpolation expressions/ }).to be_truthy
        end

        it 'keeps track of changes in elements of mapped key' do
          Puppet[:log_level] = 'debug'
          collect_notices("notice('success')") do |scope|
            expect(lookup_func.call(scope, 'path_h', 'merge' => 'hash')).to eql(
              {
                'a' => 'value path_h.a',
                'b' => 'value path_h.b',
                'c' => 'value path_h.c',
                'd' => 'value path_h.d',
                'e' => 'value path_h.e'
              })
            scope['mapped']['array_var'] = ['a', 'c', 'd']
            expect(lookup_func.call(scope, 'path_h', 'merge' => 'hash')).to eql(
              {
                'a' => 'value path_h.a',
                'b' => 'value path_h.b (from d.yaml)',
                'c' => 'value path_h.c',
                'd' => 'value path_h.d (from d.yaml)',
                'e' => 'value path_h.e'
              })
          end
          expect(notices).to eql(['success'])
          expect(debugs.any? { |m| m =~ /Hiera configuration recreated due to change of scope variables used in interpolation expressions/ }).to be_truthy
        end
      end

      context 'that originates from a hash' do
        let (:mapped_paths) { '[mapped.hash_var, var, "paths/%{var.0}.%{var.1}.yaml"]' }

        let(:env_data) do
          {
            'paths' => {
              'x.a.yaml' => <<-YAML.unindent,
                path_xa: value path_xa
                path_m:
                  a: value path_m.a
                  c: value path_m.c
                YAML
              'y.b.yaml' => <<-YAML.unindent
                path_m:
                  b: value path_m.b
                  d: value path_m.d
                YAML
            },
            'global_var.yaml' => <<-YAML.unindent
              path_m:
                e: value path_m.e
              YAML
          }
        end

        it 'finds environment data using mapped_paths' do
          expect(lookup('path_xa')).to eql('value path_xa')
          expect(warnings).to be_empty
        end

        it 'includes mapped path in explain output' do
          explanation = explain('path_h', 'merge' => 'deep')
          ['x\.a', 'y\.b', 'z\.c'].each do |var|
            expect(explanation).to match(/^\s+Path "#{env_dir}\/spec\/data\/paths\/#{var}\.yaml"\n\s+Original path: "paths\/%\{var\.0\}\.%\{var\.1\}\.yaml"/)
          end
          expect(warnings).to be_empty
        end

        it 'performs merges between mapped paths' do
          expect(lookup('path_m', 'merge' => 'hash')).to eql(
            {
              'a' => 'value path_m.a',
              'b' => 'value path_m.b',
              'c' => 'value path_m.c',
              'd' => 'value path_m.d',
              'e' => 'value path_m.e'
            })
          expect(warnings).to be_empty
        end
      end

      context 'that originates from a string' do
        let (:mapped_paths) { '[mapped.string_var, var, "paths/%{var}.yaml"]' }

        let(:env_data) do
          {
            'paths' => {
              's.yaml' => <<-YAML.unindent,
                path_s: value path_s
                YAML
            }
          }
        end

        it 'includes mapped path in explain output' do
          expect(explain('path_s')).to match(/^\s+Path "#{env_dir}\/spec\/data\/paths\/s\.yaml"\n\s+Original path: "paths\/%\{var\}\.yaml"/)
          expect(warnings).to be_empty
        end

        it 'finds environment data using mapped_paths' do
          expect(lookup('path_s')).to eql('value path_s')
          expect(warnings).to be_empty
        end
      end

      context 'where the enty does not exist' do
        let (:mapped_paths) { '[mapped.nosuch_var, var, "paths/%{var}.yaml"]' }

        it 'finds environment data using mapped_paths' do
          expect(explain('hello')).to match(/No such key: "hello"/)
          expect(warnings).to be_empty
        end
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
        expect { lookup('g') }.to raise_error(Puppet::Error, /hiera.yaml version 3 cannot be used in an environment/)
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
              ipl_hiera_env: "environment value '%{hiera('mod_a::hash_a.a')}'"
              ipl_hiera_mod: "module value '%{hiera('mod_a::abc')}'"
              ipl_hiera_modc: "module value '%{hiera('mod_a::caller')}'"
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
                when 'hash'
                  { 'array' => [ 'x5,x6' ] }
                when 'array'
                  [ 'x5,x6' ]
                when 'datasources'
                  Hiera::Backend.datasources(scope, order_override) { |source| source }
                when 'dotted.key'
                  'custom backend received request for dotted.key value'
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
        it 'finds data in in global layer and reports deprecation warnings for hiera.yaml' do
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

        it 'ignores merge behavior specified in global hiera.yaml' do
          expect(lookup('hash_b')).to eql(
            { 'hash_ba' => { 'bab' => 'value hash_b.hash_ba.bab (from global)'} })
        end

        it 'uses the merge from lookup options to merge all layers' do
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

        context 'with a module data provider' do
          let(:module_files) do
            {
              'mod_a' => {
                'hiera.yaml' => <<-YAML.unindent,
                  version: 5
                  hierarchy:
                    - name: Common
                      path: common.yaml
                  YAML
                'data' => {
                  'common.yaml' =>  <<-YAML.unindent
                    mod_a::abc: value mod_a::abc (from module)
                    mod_a::caller: "calling module is %{calling_module}"
                  YAML
                }
              }
            }
          end

          let(:environment_files) do
            {
              env_name => {
                'hiera.yaml' => env_hiera_yaml,
                'data' => env_data,
                'modules' => module_files
              }
            }
          end

          it "interpolation function 'hiera' finds values in environment" do
            expect(lookup('ipl_hiera_env')).to eql("environment value 'value mod_a::hash_a.a (from environment)'")
          end

          it "interpolation function 'hiera' finds values in module" do
            expect(lookup('ipl_hiera_mod')).to eql("module value 'value mod_a::abc (from module)'")
          end

          it "interpolation function 'hiera' finds values in module and that module does not find %{calling_module}" do
            expect(lookup('ipl_hiera_modc')).to eql("module value 'calling module is '")
          end

          context 'but no environment data provider' do
            let(:environment_files) do
              {
                env_name => {
                  'modules' => module_files
                }
              }
            end

            it "interpolation function 'hiera' does not find values in a module" do
              expect(lookup('ipl_hiera_mod')).to eql("module value ''")
            end
          end
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

        context 'using deep_merge_options' do
          let(:hiera_yaml) do
            <<-YAML.unindent
              ---
              :backends:
                - yaml
              :yaml:
                :datadir: #{code_dir}/hieradata
              :hierarchy:
                - common
                - other
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
                  hash:
                    array:
                      - x1,x2
                  array:
                    - x1,x2
                  str: a string
                  mixed:
                    x: hx
                    y: hy
                  YAML
                'other.yaml' => <<-YAML.unindent,
                  hash:
                    array:
                      - x3
                      - x4
                  array:
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

          it 'ignores configured merge_behavior when looking up arrays' do
            expect(lookup('array')).to eql(['x1,x2'])
          end

          it 'ignores configured merge_behavior when merging arrays' do
            expect(lookup('array', 'merge' => 'unique')).to eql(['x1,x2', 'x3', 'x4'])
          end

          it 'ignores configured merge_behavior when looking up hashes' do
            expect(lookup('hash')).to eql({'array' => ['x1,x2']})
          end

          it 'ignores configured merge_behavior when merging hashes' do
            expect(lookup('hash', 'merge' => 'hash')).to eql({'array' => ['x1,x2']})
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
        let(:scope_additions) { { 'ipl_datadir' => 'hieradata' } }
        let(:hiera_yaml) do
          <<-YAML.unindent
          ---
          version: 5
          defaults:
            datadir: "%{ipl_datadir}"

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

        it 'dotted keys are passed down to custom backend' do
          expect(lookup('dotted.key')).to eql('custom backend received request for dotted.key value')
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

        context 'with missing path declaraion' do
          context 'and yaml_data function' do
            let(:hiera_yaml) { <<-YAML.unindent }
              version: 5
              hierarchy:
                - name: Yaml
                  data_hash: yaml_data
              YAML

            it 'fails and reports the missing path' do
              expect { lookup('a') }.to raise_error(/one of 'path', 'paths' 'glob', 'globs' or 'mapped_paths' must be declared in hiera.yaml when using this data_hash function/)
            end
          end

          context 'and json_data function' do
            let(:hiera_yaml) { <<-YAML.unindent }
              version: 5
              hierarchy:
                - name: Json
                  data_hash: json_data
              YAML

            it 'fails and reports the missing path' do
              expect { lookup('a') }.to raise_error(/one of 'path', 'paths' 'glob', 'globs' or 'mapped_paths' must be declared in hiera.yaml when using this data_hash function/)
            end
          end

          context 'and hocon_data function' do
            let(:hiera_yaml) { <<-YAML.unindent }
              version: 5
              hierarchy:
                - name: Hocon
                  data_hash: hocon_data
              YAML

            it 'fails and reports the missing path' do
              expect { lookup('a') }.to raise_error(/one of 'path', 'paths' 'glob', 'globs' or 'mapped_paths' must be declared in hiera.yaml when using this data_hash function/)
            end
          end

          context 'and eyaml_lookup_key function' do
            let(:hiera_yaml) { <<-YAML.unindent }
              version: 5
              hierarchy:
                - name: Yaml
                  lookup_key: eyaml_lookup_key
              YAML

            it 'fails and reports the missing path' do
              expect { lookup('a') }.to raise_error(/one of 'path', 'paths' 'glob', 'globs' or 'mapped_paths' must be declared in hiera.yaml when using this lookup_key function/)
            end
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

          it 'raises a warning' do
            expect(lookup('mod_a::a')).to eql('value mod_a::a (from environment)')
            expect(warnings).to include(/hiera.yaml version 3 found at module root was ignored/)
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

      context 'using deep merge and module values that aliases environment values' do
        let(:mod_a_files) do
          {
            'mod_a' => {
              'data' => {
                'common.yaml' => <<-YAML.unindent,
                  ---
                  mod_a::hash:
                    b: value b (from module)
                  lookup_options:
                    mod_a::hash:
                      merge: deep
                  YAML
              },
              'hiera.yaml' => <<-YAML.unindent,
                ---
                version: 5
                hierarchy:
                  - name: "Common"
                    path: "common.yaml"
                  - name: "Other"
                    path: "other.yaml"
                YAML
            }
          }
        end
        let(:env_data) do
          {
            'common.yaml' => <<-YAML.unindent
              a: value a (from environment)
              mod_a::hash:
                a: value mod_a::hash.a (from environment)
                c: '%{alias("a")}'
              YAML
          }
        end

        it 'continues with module lookup after alias is resolved in environment' do
          expect(lookup('mod_a::hash')).to eql(
            {
              'a' => 'value mod_a::hash.a (from environment)',
              'b' => 'value b (from module)',
              'c' => 'value a (from environment)'
            })
        end
      end

      context 'using a data_hash that reads a yaml file' do
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

        let(:scope_additions) do
          {
            'scope_scalar' => 'scope scalar value',
            'scope_hash' => { 'a' => 'scope hash a', 'b' => 'scope hash b' }
          }
        end
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
        let(:puppet_function) { <<-PUPPET.unindent }
          function mod_a::pp_lookup_key(Puppet::LookupKey $key, Hash[String,String] $options, Puppet::LookupContext $context) >> Puppet::LookupValue {
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

        let(:mod_a_files) do
          {
            'mod_a' => {
              'functions' => {
                'pp_lookup_key.pp' => puppet_function
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

        context 'with declared but incompatible return_type' do
          let(:puppet_function) { <<-PUPPET.unindent }
            function mod_a::pp_lookup_key(Puppet::LookupKey $key, Hash[String,String] $options, Puppet::LookupContext $context) >> Runtime['ruby','Symbol'] {
              undef
            }
            PUPPET

          it 'fails and reports error' do
            expect{lookup('mod_a::a')}.to raise_error(
              "Return type of 'lookup_key' function named 'mod_a::pp_lookup_key' is incorrect, expects a RichData value, got Runtime")
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
                          return_type 'Puppet::LookupValue'
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
              defaults:
                options:
                  option_b:
                    z: Default option value b.z

              hierarchy:
                - name: "Common"
                  data_dig: mod_a::ruby_dig
                  uri: "http://www.example.com/passed/as/option"
                  options:
                    option_a: Option value a
                    option_b:
                      x: Option value b.x
                      y: Option value b.y
                - name: "Extra"
                  data_dig: mod_a::ruby_dig
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
          # Message is produced by the called function, not by the lookup framework
          expect(explain('mod_a::bad_type')).to include("value returned from function 'ruby_dig' has wrong type")
        end

        it 'does not accept return of runtime type embedded in hash from function' do
          # Message is produced by the called function, not by the lookup framework
          expect(explain('mod_a::bad_type_in_hash')).to include("value returned from function 'ruby_dig' has wrong type")
        end

        it 'will not merge hashes from environment and module unless strategy hash is used' do
          expect(lookup('mod_a::hash_a')).to eql({'a' => 'value mod_a::hash_a.a (from environment)'})
        end

        it 'hierarchy entry options are passed to the function' do
          expect(lookup('mod_a::options.option_b.x')).to eql('Option value b.x')
        end

        it 'default options are passed to the function' do
          expect(lookup('mod_a::options.option_b.z')).to eql('Default option value b.z')
        end

        it 'default options are not merged with hierarchy options' do
          expect(lookup('mod_a::options')).to eql(
            {
              'option_a' => 'Option value a',
              'option_b' => {
                'y' => 'Option value b.y',
                'x' => 'Option value b.x'
              },
              'uri' => 'http://www.example.com/passed/as/option'
            })
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

      context 'that has a default_hierarchy' do
        let(:mod_a_hiera_yaml) { <<-YAML.unindent }
          version: 5
          hierarchy:
            - name: "Common"
              path: common.yaml
            - name: "Common 2"
              path: common2.yaml

          default_hierarchy:
            - name: "Default"
              path: defaults.yaml
            - name: "Default 2"
              path: defaults2.yaml
          YAML

        let(:mod_a_common) { <<-YAML.unindent }
          mod_a::a: value mod_a::a (from module)
          mod_a::d:
            a: value mod_a::d.a (from module)
          mod_a::f:
            a:
              a: value mod_a::f.a.a (from module)
          mod_a::to_array1: 'hello'
          mod_a::to_array2: 'hello'
          mod_a::to_int: 'bananas'
          mod_a::to_bad_type: 'pyjamas'
          mod_a::undef_value: null
          lookup_options:
            mod_a::e:
              merge: deep
            mod_a::to_array1:
              merge: deep
              convert_to: "Array"
            mod_a::to_array2:
              convert_to:
                - "Array"
                - true
            mod_a::to_int:
              convert_to: "Integer"
            mod_a::to_bad_type:
              convert_to: "ComicSans"
            mod_a::undef_value:
              convert_to:
                - "Array"
                - true
          YAML


        let(:mod_a_common2) { <<-YAML.unindent }
          mod_a::b: value mod_a::b (from module)
          mod_a::d:
            c: value mod_a::d.c (from module)
          mod_a::f:
            a:
              b: value mod_a::f.a.b (from module)
          YAML

        let(:mod_a_defaults) { <<-YAML.unindent }
          mod_a::a: value mod_a::a (from module defaults)
          mod_a::b: value mod_a::b (from module defaults)
          mod_a::c: value mod_a::c (from module defaults)
          mod_a::d:
            b: value mod_a::d.b (from module defaults)
          mod_a::e:
            a:
              a: value mod_a::e.a.a (from module defaults)
          mod_a::g:
            a:
              a: value mod_a::g.a.a (from module defaults)
          lookup_options:
            mod_a::d:
              merge: hash
            mod_a::g:
              merge: deep
          YAML

        let(:mod_a_defaults2) { <<-YAML.unindent }
          mod_a::e:
            a:
              b: value mod_a::e.a.b (from module defaults)
          mod_a::g:
            a:
              b: value mod_a::g.a.b (from module defaults)
          YAML

        let(:mod_a_files) do
          {
            'mod_a' => {
              'data' => {
                'common.yaml' => mod_a_common,
                'common2.yaml' => mod_a_common2,
                'defaults.yaml' => mod_a_defaults,
                'defaults2.yaml' => mod_a_defaults2
              },
              'hiera.yaml' => mod_a_hiera_yaml
            }
          }
        end

        it 'the default hierarchy does not interfere with environment hierarchy' do
          expect(lookup('mod_a::a')).to eql('value mod_a::a (from environment)')
        end

        it 'the default hierarchy does not interfere with regular hierarchy in module' do
          expect(lookup('mod_a::b')).to eql('value mod_a::b (from module)')
        end

        it 'the default hierarchy is consulted when no value is found elsewhere' do
          expect(lookup('mod_a::c')).to eql('value mod_a::c (from module defaults)')
        end

        it 'the default hierarchy does not participate in a merge' do
          expect(lookup('mod_a::d', 'merge' => 'hash')).to eql('a' => 'value mod_a::d.a (from module)', 'c' => 'value mod_a::d.c (from module)')
        end

        it 'lookup_options from regular hierarchy does not effect values found in the default hierarchy' do
          expect(lookup('mod_a::e')).to eql('a' => { 'a' => 'value mod_a::e.a.a (from module defaults)' })
        end

        it 'lookup_options from default hierarchy affects values found in the default hierarchy' do
          expect(lookup('mod_a::g')).to eql('a' => { 'a' => 'value mod_a::g.a.a (from module defaults)', 'b' => 'value mod_a::g.a.b (from module defaults)'})
        end

        it 'merge parameter does not override lookup_options defined in the default hierarchy' do
          expect(lookup('mod_a::g', 'merge' => 'hash')).to eql(
            'a' => { 'a' => 'value mod_a::g.a.a (from module defaults)', 'b' => 'value mod_a::g.a.b (from module defaults)'})
        end

        it 'lookup_options from default hierarchy does not effect values found in the regular hierarchy' do
          expect(lookup('mod_a::d')).to eql('a' => 'value mod_a::d.a (from module)')
        end

        context "and conversion via convert_to" do
          it 'converts with a single data type value' do
            expect(lookup('mod_a::to_array1')).to eql(['h', 'e', 'l', 'l', 'o'])
          end

          it 'converts with an array of arguments to the convert_to call' do
            expect(lookup('mod_a::to_array2')).to eql(['hello'])
          end

          it 'converts an undef/nil value that has convert_to option' do
            expect(lookup('mod_a::undef_value')).to eql([nil])
          end

          it 'errors if a convert_to lookup_option cannot be performed because value does not match type' do
            expect{lookup('mod_a::to_int')}.to raise_error(/The convert_to lookup_option for key 'mod_a::to_int' raised error.*The string 'bananas' cannot be converted to Integer/)
          end

          it 'errors if a convert_to lookup_option cannot be performed because type does not exist' do
            expect{lookup('mod_a::to_bad_type')}.to raise_error(/The convert_to lookup_option for key 'mod_a::to_bad_type' raised error.*Creation of new instance of type 'TypeReference\['ComicSans'\]' is not supported/)
          end

          it 'adds explanation that conversion took place with a type' do
            explanation = explain('mod_a::to_array1')
            expect(explanation).to include('Applying convert_to lookup_option with arguments [Array]')
          end

          it 'adds explanation that conversion took place with a type and arguments' do
            explanation = explain('mod_a::to_array2')
            expect(explanation).to include('Applying convert_to lookup_option with arguments [Array, true]')
          end
        end

        it 'the default hierarchy lookup is included in the explain output' do
          explanation = explain('mod_a::c')
          expect(explanation).to match(/Searching default_hierarchy of module "mod_a".+Original path: "defaults.yaml"/m)
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

      let(:scope_additions) { { 'ipl_suffix' => 'aa' } }
      let(:data_files) do
        {
          'common.eyaml' => <<-YAML.unindent
            # a: Encrypted value 'a' (from environment)
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
              "hash_%{ipl_suffix}":
                # aaa: Encrypted value hash_a.hash_aa.aaa (from environment)
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
              # - "array_a[0]"
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
              # - "array_a[1]"
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
            # ref_a: "A resolved = '%{hiera('a')}'"
            ref_a: >
                ENC[PKCS7,MIIBiQYJKoZIhvcNAQcDoIIBejCCAXYCAQAxggEhMIIBHQIBADAFMAACAQEw
                DQYJKoZIhvcNAQEBBQAEggEAFSuUp+yk+oaA7b5ekT0u360CQ9Q2sIQ/bTcM
                jT3XLjm8HIGYPcysOEnuo8WcAxJFY5iya4yQ7Y/UhMWXaTi7Vzv/6BmyPDwz
                +7Z2Mf0r0PvS5+ylue6aem/3bXPOmXTKTf68OCehTRXlDUs8/av9gnsDzojp
                yiUTBZvKxhIP2n//GyoHgyATveHT0lxPVpdMycB347DtWS7IduCxx0+KiOOw
                DXYFlYbIVxVInwgERxtsfYSr+Fu0/mkjtRsQm+dPzMQOATE9Val2gGKsV6bi
                kdm1OM9HrwVsFj6Lma6FYmr89Bcm/1uEc8fiOMtNK3z2+nwunWBMNCGneMYD
                C5IJejBMBgkqhkiG9w0BBwEwHQYJYIZIAWUDBAEqBBAeiZDGQyXHkZlV5ceT
                iCxpgCDDatuVvbPEEi8rKOC7xhPHZ22zLEEV//l7C9jxq+DZcA==]
            YAML
        }
      end

      let(:env_data) { data_files }

      context 'and a module using eyaml with different options' do

        let(:private_module_key) do
          <<-PKCS7.unindent
          -----BEGIN RSA PRIVATE KEY-----
          MIIEogIBAAKCAQEAuqVpctipK4OMWM+RwKcd/mR4pg6qE3+ItPVC9TlvBrmDaN/y
          YZRjQR+XovXSGuy/CneSQ9Qss0Ff3FKAmEeH0qN0V47a81hgLpjhLCX1n+Ov7r1Q
          DC1ciTpVzHE4krN3rJ/RmDohitIqT1IYYhdcEdaMG9E26HIzn1QIwaDiYU3mfqWM
          8CZExa0CeIsEzHRLSxuMi/xX0ENImCRUzY9GH88Cu2gUhpKlbVzJmVqGPgp94pJY
          YM+SUb0XP1yRySpJMnVg98oCUrQO2OoE/Gax/djAi6hrJUzejPsEKdZ1yxM6OyJW
          NjWZYs8izAxBqm7pv1hx5+X7AIPqwZTMVrB7TQIDAQABAoIBAHIex13QOYeAlGSM
          7bpUtBMiTV6DItxvIyA5wen8ZvU+oqmSHDorp5BfB7E9Cm0qChkVSRot9fLYawtk
          anoxakuRY4ZRs3AMvipfkXYT854CckTP/cykQ6soPuOU6plQIEEtKtMf3/hoTjRX
          ps77J3FEtEAh6Kexg/zMPdpeS2xgULhk0P9ZQEg+JhLA5dq0p0nz3SBkuzcxei79
          +Za/Tg1osD0AINOajdvPnKxvlmWJN0+LpGwVjFNhkoUXPeDyvq0z2V/Uqwz4HP2I
          UGv4tz3SbzFc3Ie4lzgUZzCQgUK3u60pq1uyA6BRtxwdEmpn5v++jGXBGJZpWwcW
          UNblESUCgYEA4aTH9+LHsNjLPs2FmSc7hNjwHG1rAHcDXTX2ccySjRcQvH4Z7xBL
          di+SzZ2Tf8gSLycPRgRVCbrgCODpjoV2D5wWnyUHfWm4+GQxHURYa4UDx69tsSKE
          OTRASJo7/Mz0M1a6YzgCzVRM/TO676ucmawzKUY5OUm1oehtODAiZOcCgYEA08GM
          AMBOznys02xREJI5nLR6AveuTbIjF2efEidoxoW+1RrMOkcqaDTrJQ5PLM+oDDwD
          iPzVjnroSbwJzFB71atIg7b7TwltgkXy7wNTedO2cm5u/I0q8tY2Jaa4Mz8JUnbe
          yafvtS0/mY6A5k+8/2UIMFin2rqU9NC9EUPIo6sCgYBhOvAwELibq89osIbxB8bN
          5+0PUtbYzG/WqnoXb193DIlZr7zdFththPJtR4lXdo7fYqViNluuZahEKyZ5E2lc
          MJZO3VXs5LGf1wyS3/B55EdMtHs/6O+w9qL8pflTZb2UobqPJoOOltTWBoR24iwI
          y/r/vhLKbMini9AEdjlb4QKBgGdYsax4Lr4GCQ8ScSnmQ6ngRyAFo5MV2pyEnRTu
          GOuywKUe9AeJTgAXu5+VMT0Mh9aYv5zu0Ic+IvpBhIKr0RRCCR0Hg/VaA5Et9FeE
          RwxRMFz+2rn1Z72moDyV9pZEMJeHnknK5WmGEOEvtGczCWmX9Hwr+Jf+sc4dxfiU
          HWsLAoGAXWSX73p/6R4eRfF5zU2UFJPvDzhmwObAuvU4zKs9x7PMxZfvyt/eBCO1
          fj2+hIR72RxVuHbLApF1BT6gPVLtNdvaNuCs8YlHcnx/Oi088F0ni7fL/xYBUvaB
          7wTf188UJxP1ofVMZW00P4I9mR6BrOulv455gCwsmg2X7WtJU48=
          -----END RSA PRIVATE KEY-----
          PKCS7
        end

        let(:public_module_key) do
          <<-PKCS7.unindent
          -----BEGIN CERTIFICATE-----
          MIIC2TCCAcGgAwIBAgIBATANBgkqhkiG9w0BAQUFADAAMCAXDTE3MDUzMTE2Mjc0
          M1oYDzIwNjcwNTE5MTYyNzQzWjAAMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIB
          CgKCAQEAuqVpctipK4OMWM+RwKcd/mR4pg6qE3+ItPVC9TlvBrmDaN/yYZRjQR+X
          ovXSGuy/CneSQ9Qss0Ff3FKAmEeH0qN0V47a81hgLpjhLCX1n+Ov7r1QDC1ciTpV
          zHE4krN3rJ/RmDohitIqT1IYYhdcEdaMG9E26HIzn1QIwaDiYU3mfqWM8CZExa0C
          eIsEzHRLSxuMi/xX0ENImCRUzY9GH88Cu2gUhpKlbVzJmVqGPgp94pJYYM+SUb0X
          P1yRySpJMnVg98oCUrQO2OoE/Gax/djAi6hrJUzejPsEKdZ1yxM6OyJWNjWZYs8i
          zAxBqm7pv1hx5+X7AIPqwZTMVrB7TQIDAQABo1wwWjAPBgNVHRMBAf8EBTADAQH/
          MB0GA1UdDgQWBBQkhoMgOyPzEe7tOOimNH2//PYF2TAoBgNVHSMEITAfgBQkhoMg
          OyPzEe7tOOimNH2//PYF2aEEpAIwAIIBATANBgkqhkiG9w0BAQUFAAOCAQEAhRWc
          Nz3PcUJllao5G/v4AyvjLgwB2JgjJgh6D3ILoOe9TrDSXD7ZV3F30vFae+Eztk86
          pmM8x57E0HsuuY+Owf6/hvELtwbzf9N/lc9ySZSogGFoQeJ8rnCJAQ0FaPjqb7AN
          xTaY9HTzr4dZG1f+sw32RUu2fDe7Deqgf85uMSZ1mtRTt9zvo8lMQxVA2nVOfwz2
          Nxf+qSNYSCtf0/6iwfzHy0qPjaJnywgBCi3Lg2IMSqGUatxzH+9HWrBgD+ZYxmDz
          2gW+EIU1Y/We/tbjIWaR1PD+IzeRJi5fHq60RKHPSdp7TGtV48bQRvyZXC7sVCRa
          yxfX1IGYhCDzbFRQNg==
          -----END CERTIFICATE-----
          PKCS7
        end

        let(:module_keys_dir) do
          keys = tmpdir('keys')
          dir_contained_in(keys, {
            private_key_name => private_module_key,
            public_key_name => public_module_key
          })
          keys
        end

        let(:private_module_key_path) { File.join(module_keys_dir, private_key_name) }
        let(:public_module_key_path) { File.join(module_keys_dir, public_key_name) }

        let(:mod_a_files) do
          {
            'mod_a' => {
              'hiera.yaml' => <<-YAML.unindent,
                version: 5
                hierarchy:
                  - name: EYaml
                    path: common.eyaml
                    lookup_key: eyaml_lookup_key
                    options:
                      pkcs7_private_key: #{private_module_key_path}
                      pkcs7_public_key: #{public_module_key_path}
                YAML
              'data' => {
                'common.eyaml' => <<-YAML.unindent
                ---
                # "%{lookup('a')} (from module)"
                mod_a::a: >
                  ENC[PKCS7,MIIBiQYJKoZIhvcNAQcDoIIBejCCAXYCAQAxggEhMIIBHQIBADAFMAACAQEw
                  DQYJKoZIhvcNAQEBBQAEggEAC+lvda8mX6XkgCBstNw4IQUDyFcS6M0mS9gZ
                  ev4VBDeUK4AUNVnzzdbW0Mnj9LbqlpzFx96VGqSxsRBpe7BVD0kVo5jQsEMn
                  nbrWOD1lvXYrXZMXBeD9xJbMbH5EiiFhbaXcEKRAVGaLVQKjXDENDQ/On+it
                  1+wmmVwJynDJR0lsCz6dcSKvw6wnxBcv32qFyePvJuIf04CHMhaS4ykedYHK
                  vagUn5uVXOv/8G0JPlZnQLyxjE0v0heb0Zj0mvcP2+Y5BSW50AQVrMWJNtdW
                  aFEg6H5hpjduQfQh3iWVuDLnWhbP0sY2Grn5dTOxQP8aTDSsiTUcSeIAmjr/
                  K8YRCjBMBgkqhkiG9w0BBwEwHQYJYIZIAWUDBAEqBBAjL7InlBjRuohLLcBx
                  686ogCDkhCan8bCE7aX2nr75QtLF3q89pFIR4/NGl5+oGEO+qQ==]
                YAML
              }
            }
          }
        end

        let(:populated_env_dir) do
          dir_contained_in(env_dir, DeepMerge.deep_merge!(environment_files, env_name => { 'modules' => mod_a_files }))
          env_dir
        end

        it 'repeatedly finds data in environment and module' do
          expect(lookup(['array_a', 'mod_a::a', 'hash_a'])).to eql([
            ['array_a[0]', 'array_a[1]'],
            "Encrypted value 'a' (from environment) (from module)",
            {'hash_aa'=>{'aaa'=>'Encrypted value hash_a.hash_aa.aaa (from environment)'}}])
        end
      end

      it 'finds data in the environment' do
        expect(lookup('a')).to eql("Encrypted value 'a' (from environment)")
      end

      it 'evaluates interpolated keys' do
        expect(lookup('hash_a')).to include('hash_aa')
      end

      it 'evaluates interpolations in encrypted values' do
        expect(lookup('ref_a')).to eql("A resolved = 'Encrypted value 'a' (from environment)'")
      end

      it 'can read encrypted values inside a hash' do
        expect(lookup('hash_a.hash_aa.aaa')).to eql('Encrypted value hash_a.hash_aa.aaa (from environment)')
      end

      it 'can read encrypted values inside an array' do
        expect(lookup('array_a')).to eql(['array_a[0]', 'array_a[1]'])
      end

      context 'declared in global scope as a Hiera v3 backend' do
        let(:environment_files) { {} }
        let(:data_file_content) { <<-YAML.unindent }
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
            'common.eyaml' => data_file_content
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

        context 'using intepolated paths to the key pair' do
          let(:scope_additions) { { 'priv_path' => private_key_path, 'pub_path' => public_key_path } }

          let(:hiera_yaml) do
            <<-YAML.unindent
          :backends: eyaml
          :eyaml:
            :datadir: #{code_dir}/hieradata
            :pkcs7_private_key: "%{priv_path}"
            :pkcs7_public_key: "%{pub_path}"
          :hierarchy:
            - common
            YAML
          end

          it 'finds data in the global layer' do
            expect(lookup('a')).to eql("Encrypted value 'a' (from global)")
          end
        end

        context 'with special extension declared in options' do
          let(:environment_files) { {} }
          let(:hiera_yaml) do
            <<-YAML.unindent
            :backends: eyaml
            :eyaml:
              :extension: xyaml
              :datadir: #{code_dir}/hieradata
              :pkcs7_private_key: #{private_key_path}
              :pkcs7_public_key: #{public_key_path}
            :hierarchy:
              - common
            YAML
          end

          let(:data_files) do
            {
              'common.xyaml' => data_file_content
            }
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
end
