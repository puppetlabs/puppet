require 'spec_helper'
require 'puppet_spec/files'
require 'puppet_spec/compiler'
require 'deep_merge/core'

describe 'lookup' do
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
              lookup_options:
                mod_a::hash_b:
                  merge: hash
              YAML
          }
        },
        'someother' => {
        }
      }
    end

    let(:app) { Puppet::Application[:lookup] }
    let(:env) { Puppet::Node::Environment.create(env_name.to_sym, [File.join(populated_env_dir, env_name, 'modules')]) }
    let(:environments) { Puppet::Environments::Directories.new(populated_env_dir, []) }

    let(:populated_env_dir) do
      dir_contained_in(env_dir, environment_files)
      env_dir
    end

    def lookup(key, options = {}, explain = false)
      key = [key] unless key.is_a?(Array)
      app.command_line.stubs(:args).returns(key)
      if explain
        app.options[:explain] = true
        app.options[:render_as] = :s
      else
        app.options[:render_as] = :json
      end
      options.each_pair { |k, v| app.options[k] = v }
      capture = StringIO.new
      saved_stdout = $stdout
      begin
        $stdout = capture
        expect { app.run_command }.to exit_with(0)
      ensure
        $stdout = saved_stdout
      end
      out = capture.string.strip
      if explain
        out
      else
        out.empty? ? nil : JSON.parse("[#{out}]")[0]
      end
    end

    def explain(key, options = {})
      lookup(key, options, true)
    end

    around(:each) do |example|
      Puppet.override(:environments => environments, :current_environment => env) do
        example.run
      end
    end

    it 'finds data in the environment' do
      expect(lookup('a')).to eql('value a')
    end

    context 'uses node_terminus' do
      require 'puppet/indirector/node/exec'
      require 'puppet/indirector/node/plain'

      let(:node) { Puppet::Node.new('testnode', :environment => env) }

      it ':plain without --compile' do
        Puppet.settings[:node_terminus] = 'exec'
        Puppet::Node::Plain.any_instance.expects(:find).returns(node)
        Puppet::Node::Exec.any_instance.expects(:find).never
        expect(lookup('a')).to eql('value a')
      end

      it 'configured in Puppet settings with --compile' do
        Puppet.settings[:node_terminus] = 'exec'
        Puppet::Node::Plain.any_instance.expects(:find).never
        Puppet::Node::Exec.any_instance.expects(:find).returns(node)
        expect(lookup('a', :compile => true)).to eql('value a')
      end
    end

    context 'configured with the wrong environment' do
      let(:env) { Puppet::Node::Environment.create(env_name.to_sym, [File.join(populated_env_dir, env_name, 'modules')]) }
      it 'does not find data in non-existing environment' do
        Puppet.override(:environments => environments, :current_environment => 'someother') do
          expect(lookup('a', {}, true)).to match(/did not find a value for the name 'a'/)
        end
      end
    end

    context 'and a module' do
      let(:mod_a_files) do
        {
          'mod_a' => {
            'data' => {
              'common.yaml' => <<-YAML.unindent
                ---
                mod_a::a: value mod_a::a (from mod_a)
                mod_a::b: value mod_a::b (from mod_a)
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
                'mod_a::a.quoted.key': 'value mod_a::a.quoted.key (from mod_a)'
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

      let(:populated_env_dir) do
        dir_contained_in(env_dir, DeepMerge.deep_merge!(environment_files, env_name => { 'modules' => mod_a_files }))
        env_dir
      end

      it 'finds data in the module' do
        expect(lookup('mod_a::b')).to eql('value mod_a::b (from mod_a)')
      end

      it 'finds quoted keys in the module' do
        expect(lookup('"mod_a::a.quoted.key"')).to eql('value mod_a::a.quoted.key (from mod_a)')
      end

      it 'merges hashes from environment and module when merge strategy hash is used' do
        expect(lookup('mod_a::hash_a', :merge => 'hash')).to eql({'a' => 'value mod_a::hash_a.a (from environment)', 'b' => 'value mod_a::hash_a.b (from mod_a)'})
      end
    end
  end
end
