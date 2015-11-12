require 'spec_helper'
require 'puppet/application/lookup'
require 'puppet/pops/lookup'

describe Puppet::Application::Lookup do

  context "when running with incorrect command line options" do
    let (:lookup) { Puppet::Application[:lookup] }

    it "errors if no keys are given via the command line" do
      lookup.options[:node] = 'dantooine.local'
      expected_error = "No keys were given to lookup."

      expect { lookup.run_command }.to raise_error(RuntimeError, expected_error)
    end

    it "does not allow deep merge options if '--merge' was not set to deep" do
      lookup.options[:node] = 'dantooine.local'
      lookup.options[:merge_hash_arrays] = true
      lookup.options[:merge] = 'hash'
      lookup.command_line.stubs(:args).returns(['atton', 'kreia'])

      expected_error = "The options --knock-out-prefix, --sort-merged-arrays, --unpack-arrays, and --merge-hash-arrays are only available with '--merge deep'\nRun 'puppet lookup --help' for more details"

      expect { lookup.run_command }.to raise_error(RuntimeError, expected_error)
    end
  end

  context "when running with correct command line options" do
    let (:lookup) { Puppet::Application[:lookup] }

    it "calls the lookup method with the correct arguments" do
      lookup.options[:node] = 'dantooine.local'
      lookup.options[:render_as] = :s;
      lookup.options[:merge_hash_arrays] = true
      lookup.options[:merge] = 'deep'
      lookup.command_line.stubs(:args).returns(['atton', 'kreia'])
      lookup.stubs(:generate_scope).yields('scope')

      expected_merge = { "strategy" => "deep", "sort_merge_arrays" => false, "merge_hash_arrays" => true }

      (Puppet::Pops::Lookup).expects(:lookup).with(['atton', 'kreia'], nil, nil, false, expected_merge, anything).returns('rand')

      expect { lookup.run_command }.to output("rand\n").to_stdout
    end

    it "prints the value found by lookup" do
      lookup.options[:node] = 'dantooine.local'
      lookup.command_line.stubs(:args).returns(['atton', 'kreia'])
      lookup.stubs(:generate_scope).yields('scope')

      Puppet::Pops::Lookup.stubs(:lookup).returns('rand')

      expect { lookup.run_command }.to output("--- rand\n...\n").to_stdout
    end
  end


  context 'when asked to explain' do
    let (:lookup) { Puppet::Application[:lookup] }

    # There is a fully configured 'sample' environment in fixtures at this location
    let(:environmentpath) { File.absolute_path(File.join(my_fixture_dir(), '../environments')) }

    let(:facts) { Puppet::Node::Facts.new("facts", {}) }

    let(:node) { Puppet::Node.new("testnode", :facts => facts, :environment => environment) }

    let(:expected_json_hash) { {
      'type' => 'merge',
      'merge' => 'first',
      'event' => 'result',
      'value' => 'This is A',
      'branches' => [
      { 'key' => 'a',
        'event' => 'not_found',
        'type' => 'global',
        'name' => 'hiera'
      },
      {
        'type' => 'data_provider',
        'name' => 'Hiera Data Provider, version 4',
        'configuration_path' => "#{environmentpath}/production/hiera.yaml",
        'branches' => [
        {
          'name' => 'common',
          'type' => 'data_provider',
          'branches' => [
          {
            'key' => 'a',
            'value' => 'This is A',
            'event' => 'found',
            'type' => 'path',
            'original_path' => 'common',
            'path' => "#{environmentpath}/production/data/common.yaml",
          }]
        }]
      }]
    } }

    let(:expected_yaml_hash) { {
      :branches => [
      {
        :type => :meta,
        :branches => [
        {
          :type => :merge,
          :merge => :hash,
          :branches => [
          {
            :type => :global,
            :key => 'lookup_options',
            :name => :hiera,
            :event => :not_found
          },
          {
            :type => :data_provider,
            :name => 'Hiera Data Provider, version 4',
            :configuration_path => "#{environmentpath}/production/hiera.yaml",
            :branches => [
            {
              :type => :data_provider,
              :name => 'common',
              :branches => [
              {
                :type => :path,
                :key => 'lookup_options',
                :original_path => 'common',
                :path => "#{environmentpath}/production/data/common.yaml",
                :event => :not_found
              }]
            }]
          }]
        }]
      },
      {
        :type => :merge,
        :merge => :first,
        :event => :result,
        :value => 'This is A',
        :branches => [
        { :key => 'a',
          :event => :not_found,
          :type => :global,
          :name => :hiera
        },
        {
          :type => :data_provider,
          :name => 'Hiera Data Provider, version 4',
          :configuration_path => "#{environmentpath}/production/hiera.yaml",
          :branches => [
          {
            :type => :data_provider,
            :name => 'common',
            :branches => [
            {
              :key => 'a',
              :value => 'This is A',
              :event => :found,
              :type => :path,
              :original_path => 'common',
              :path => "#{environmentpath}/production/data/common.yaml",
              }]
           }]
         }]
      }]
    } }

    around(:each) do |example|
      # Initialize settings to get a full compile as close as possible to a real
      # environment load
      Puppet.settings.initialize_global_settings
      loader = Puppet::Environments::Directories.new(environmentpath, [])
      Puppet.override(:environments => loader) do
        example.run
      end
    end

    it 'produces human readable text by default' do
      lookup.options[:node] = Puppet::Node.new("testnode", :facts => facts, :environment => 'production')
      lookup.options[:explain] = true
      lookup.command_line.stubs(:args).returns(['a'])
      expect { lookup.run_command }.to output(<<-EXPLANATION).to_stdout
Searching for 'lookup_options'
  Merge strategy hash
    Data Binding "hiera"
      No such key: "lookup_options"
    Data Provider "Hiera Data Provider, version 4"
      ConfigurationPath "#{environmentpath}/production/hiera.yaml"
      Data Provider "common"
        Path "#{environmentpath}/production/data/common.yaml"
          Original path: common
          No such key: "lookup_options"
Merge strategy first
  Data Binding "hiera"
    No such key: "a"
  Data Provider "Hiera Data Provider, version 4"
    ConfigurationPath "#{environmentpath}/production/hiera.yaml"
    Data Provider "common"
      Path "#{environmentpath}/production/data/common.yaml"
        Original path: common
        Found key: "a" value: "This is A"
  Merged result: "This is A"
      EXPLANATION
    end

    it 'produces human readable text without meta data when --explain-data is used' do
      lookup.options[:node] = Puppet::Node.new("testnode", :facts => facts, :environment => 'production')
      lookup.options[:explain_data] = true
      lookup.command_line.stubs(:args).returns(['a'])
      expect { lookup.run_command }.to output(<<-EXPLANATION).to_stdout
Merge strategy first
  Data Binding "hiera"
    No such key: "a"
  Data Provider "Hiera Data Provider, version 4"
    ConfigurationPath "#{environmentpath}/production/hiera.yaml"
    Data Provider "common"
      Path "#{environmentpath}/production/data/common.yaml"
        Original path: common
        Found key: "a" value: "This is A"
  Merged result: "This is A"
      EXPLANATION
    end

    it 'can produce a yaml explanation' do
      lookup.options[:node] = Puppet::Node.new("testnode", :facts => facts, :environment => 'production')
      lookup.options[:explain] = true
      lookup.options[:render_as] = :yaml
      lookup.command_line.stubs(:args).returns(['a'])
      save_stdout = $stdout
      output = nil
      begin
        $stdout = StringIO.new
        lookup.run_command
        output = $stdout.string
      ensure
        $stdout = save_stdout
      end
      expect(YAML.load(output)).to eq(expected_yaml_hash)
    end

    it 'can produce a json explanation' do
      lookup.options[:node] = Puppet::Node.new("testnode", :facts => facts, :environment => 'production')
      lookup.options[:explain_data] = true
      lookup.options[:render_as] = :json
      lookup.command_line.stubs(:args).returns(['a'])
      save_stdout = $stdout
      output = nil
      begin
        $stdout = StringIO.new
        lookup.run_command
        output = $stdout.string
      ensure
        $stdout = save_stdout
      end
      expect(JSON.parse(output)).to eq(expected_json_hash)
    end
  end
end
