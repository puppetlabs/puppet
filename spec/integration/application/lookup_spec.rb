require 'spec_helper'
require 'puppet_spec/files'
require 'puppet_spec/compiler'
require 'deep_merge/core'

describe 'lookup' do
  include PuppetSpec::Files

  context 'with an environment' do
    let(:fqdn) { Puppet[:certname] }
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
    let(:facts) { Puppet::Node::Facts.new("facts", {'my_fact' => 'my_fact_value'}) }
    let(:cert) { pem_content('oid.pem') }

    let(:node) { Puppet::Node.new('testnode', :facts => facts) }
    let(:populated_env_dir) do
      dir_contained_in(env_dir, environment_files)
      env_dir
    end

    before do
      stub_request(:get, "https://puppet:8140/puppet-ca/v1/certificate/#{fqdn}").to_return(body: cert)
      allow(Puppet::Node::Facts.indirection).to receive(:find).and_return(facts)

      Puppet[:environment] = env_name
      Puppet[:environmentpath] = populated_env_dir

      http = Puppet::HTTP::Client.new(ssl_context: Puppet::SSL::SSLProvider.new.create_insecure_context)
      Puppet.runtime[:http] = http
    end

    def expect_lookup_with_output(exitcode, out)
      expect { app.run }.to exit_with(exitcode).and output(out).to_stdout
    end

    it 'finds data in the environment' do
      app.command_line.args << 'a'
      expect_lookup_with_output(0, /value a/)
    end

    it 'loads trusted information from the node certificate' do
      Puppet.settings[:node_terminus] = 'exec'
      expect_any_instance_of(Puppet::Node::Exec).to receive(:find) do |args|
        info = Puppet.lookup(:trusted_information)
        expect(info.certname).to eq(fqdn)
        expect(info.extensions).to eq({ "1.3.6.1.4.1.34380.1.2.1.1" => "somevalue" })
      end.and_return(node)

      app.command_line.args << 'a' << '--compile'
      expect_lookup_with_output(0, /--- value a/)
    end

    it 'loads external facts when running without --node' do
      expect(Puppet::Util).not_to receive(:skip_external_facts)
      expect(Facter).not_to receive(:load_external)

      app.command_line.args << 'a'
      expect_lookup_with_output(0, /--- value a/)
    end

    describe 'when using --node' do
      let(:fqdn) { 'random_node' }

      it 'skips loading of external facts' do
        app.command_line.args << 'a' << '--node' << fqdn

        expect(Puppet::Node::Facts.indirection).to receive(:find).and_return(facts)
        expect(Facter).to receive(:load_external).twice.with(false)
        expect(Facter).to receive(:load_external).twice.with(true)
        expect_lookup_with_output(0, /--- value a/)
      end
    end

    context 'uses node_terminus' do
      require 'puppet/indirector/node/exec'
      require 'puppet/indirector/node/plain'

      let(:node) { Puppet::Node.new('testnode', :facts => facts) }

      it ':plain without --compile' do
        Puppet.settings[:node_terminus] = 'exec'
        expect_any_instance_of(Puppet::Node::Plain).to receive(:find).and_return(node)
        expect_any_instance_of(Puppet::Node::Exec).not_to receive(:find)

        app.command_line.args << 'a'
        expect_lookup_with_output(0, /--- value a/)
      end

      it 'configured in Puppet settings with --compile' do
        Puppet.settings[:node_terminus] = 'exec'
        expect_any_instance_of(Puppet::Node::Plain).not_to receive(:find)
        expect_any_instance_of(Puppet::Node::Exec).to receive(:find).and_return(node)

        app.command_line.args << 'a' << '--compile'
        expect_lookup_with_output(0, /--- value a/)
      end
    end

    context 'configured with the wrong environment' do
      it 'does not find data in non-existing environment' do
        Puppet[:environment] = 'doesntexist'
        app.command_line.args << 'a'
        expect { app.run }.to raise_error(Puppet::Environments::EnvironmentNotFound, /Could not find a directory environment named 'doesntexist'/)
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
        app.command_line.args << 'mod_a::b'
        expect_lookup_with_output(0, /value mod_a::b \(from mod_a\)/)
      end

      it 'finds quoted keys in the module' do
        app.command_line.args << "'mod_a::a.quoted.key'"
        expect_lookup_with_output(0, /value mod_a::a.quoted.key \(from mod_a\)/)
      end

      it 'merges hashes from environment and module when merge strategy hash is used' do
        app.command_line.args << 'mod_a::hash_a' << '--merge' << 'hash'
        expect_lookup_with_output(0, <<~END)
          ---
          a: value mod_a::hash_a.a (from environment)
          b: value mod_a::hash_a.b (from mod_a)
        END
      end
    end
  end
end
