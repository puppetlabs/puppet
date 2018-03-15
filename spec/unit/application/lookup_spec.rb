require 'spec_helper'
require 'puppet/application/lookup'
require 'puppet/pops/lookup'

describe Puppet::Application::Lookup do

  def run_lookup(lookup)
    capture = StringIO.new
    saved_stdout = $stdout
    begin
      $stdout = capture
      expect { lookup.run_command }.to exit_with(0)
    ensure
      $stdout = saved_stdout
    end
    capture.string.strip
  end

  context "when running with incorrect command line options" do
    let (:lookup) { Puppet::Application[:lookup] }

    it "errors if no keys are given via the command line" do
      lookup.options[:node] = 'dantooine.local'
      expected_error = "No keys were given to lookup."

      expect { lookup.run_command }.to raise_error(RuntimeError, expected_error)
    end

    it "does not allow invalid arguments for '--merge'" do
      lookup.options[:node] = 'dantooine.local'
      lookup.options[:merge] = 'something_bad'
      lookup.command_line.stubs(:args).returns(['atton', 'kreia'])

      expected_error = "The --merge option only accepts 'first', 'hash', 'unique', or 'deep'\nRun 'puppet lookup --help' for more details"

      expect { lookup.run_command }.to raise_error(RuntimeError, expected_error)
    end

    it "does not allow deep merge options if '--merge' was not set to deep" do
      lookup.options[:node] = 'dantooine.local'
      lookup.options[:merge_hash_arrays] = true
      lookup.options[:merge] = 'hash'
      lookup.command_line.stubs(:args).returns(['atton', 'kreia'])

      expected_error = "The options --knock-out-prefix, --sort-merged-arrays, and --merge-hash-arrays are only available with '--merge deep'\nRun 'puppet lookup --help' for more details"

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

      expected_merge = { "strategy" => "deep", "sort_merged_arrays" => false, "merge_hash_arrays" => true }

      (Puppet::Pops::Lookup).expects(:lookup).with(['atton', 'kreia'], nil, nil, false, expected_merge, anything).returns('rand')

      expect(run_lookup(lookup)).to eql("rand")
    end

    %w(first unique hash deep).each do |opt|

      it "accepts --merge #{opt}" do
        lookup.options[:node] = 'dantooine.local'
        lookup.options[:merge] = opt
        lookup.command_line.stubs(:args).returns(['atton', 'kreia'])
        lookup.stubs(:generate_scope).yields('scope')
        Puppet::Pops::Lookup.stubs(:lookup).returns('rand')
        expect(run_lookup(lookup)).to eql("--- rand\n...")
      end
    end

    it "prints the value found by lookup" do
      lookup.options[:node] = 'dantooine.local'
      lookup.command_line.stubs(:args).returns(['atton', 'kreia'])
      lookup.stubs(:generate_scope).yields('scope')

      Puppet::Pops::Lookup.stubs(:lookup).returns('rand')

      expect(run_lookup(lookup)).to eql("--- rand\n...")
    end
  end

  context 'when given a valid configuration' do
    let (:lookup) { Puppet::Application[:lookup] }

    # There is a fully configured 'sample' environment in fixtures at this location
    let(:environmentpath) { File.absolute_path(File.join(my_fixture_dir(), '../environments')) }

    let(:facts) { Puppet::Node::Facts.new("facts", {}) }

    let(:node) { Puppet::Node.new("testnode", :facts => facts, :environment => 'production') }

    let(:expected_json_hash) {
      {
        'branches' =>
          [
            {
              'branches'=>
                [
                  {
                    'key'=>'lookup_options',
                    'event'=>'not_found',
                    'type'=>'data_provider',
                    'name'=>'Global Data Provider (hiera configuration version 5)'
                  },
                  {
                    'branches'=>
                      [
                        {
                          'branches'=>
                            [
                              {
                                'key' => 'lookup_options',
                                'value' => {'a'=>'first'},
                                'event'=>'found',
                                'type'=>'path',
                                'original_path'=>'common.yaml',
                                'path'=>"#{environmentpath}/production/data/common.yaml"
                              }
                            ],
                          'type'=>'data_provider',
                          'name'=>'Hierarchy entry "Common"'
                        }
                      ],
                    'type'=>'data_provider',
                    'name'=>'Environment Data Provider (hiera configuration version 5)'
                  }
                ],
              'key'=>'lookup_options',
              'type'=>'root'
            },
            {
              'branches'=>
                [
                  {
                    'key'=>'a',
                    'event'=>'not_found',
                    'type'=>'data_provider',
                    'name'=>'Global Data Provider (hiera configuration version 5)'
                  },
                  {
                    'branches'=>
                      [
                        {
                          'branches'=>
                            [
                              {
                                'key'=>'a',
                                'value'=>'This is A',
                                'event'=>'found',
                                'type'=>'path',
                                'original_path'=>'common.yaml',
                                'path'=>"#{environmentpath}/production/data/common.yaml"
                              }
                            ],
                          'type'=>'data_provider',
                          'name'=>'Hierarchy entry "Common"'
                        }
                      ],
                    'type'=>'data_provider',
                    'name'=>'Environment Data Provider (hiera configuration version 5)'
                  }
                ],
              'key'=>'a',
              'type'=>'root'
            }
          ]
      }
    }

    let(:expected_yaml_hash) {
      {
      :branches =>
        [
          {
            :branches=>
              [
                {
                  :key=>'lookup_options',
                  :event=>:not_found,
                  :type=>:data_provider,
                  :name=>'Global Data Provider (hiera configuration version 5)'
                },
                {
                  :branches=>
                    [
                      {
                        :branches=>
                          [
                            {
                              :key => 'lookup_options',
                              :value => {'a'=>'first'},
                              :event=>:found,
                              :type=>:path,
                              :original_path=>'common.yaml',
                              :path=>"#{environmentpath}/production/data/common.yaml"
                            }
                          ],
                        :type=>:data_provider,
                        :name=>'Hierarchy entry "Common"'
                      }
                  ],
                  :type=>:data_provider,
                  :name=>'Environment Data Provider (hiera configuration version 5)'
                }
              ],
            :key=>'lookup_options',
            :type=>:root
          },
          {
            :branches=>
              [
                {
                  :key=>'a',
                  :event=>:not_found,
                  :type=>:data_provider,
                  :name=>'Global Data Provider (hiera configuration version 5)'
                },
                {
                  :branches=>
                    [
                      {
                        :branches=>
                        [
                          {
                            :key=>'a',
                            :value=>'This is A',
                            :event=>:found,
                            :type=>:path,
                            :original_path=>'common.yaml',
                            :path=>"#{environmentpath}/production/data/common.yaml"
                          }
                        ],
                        :type=>:data_provider,
                        :name=>'Hierarchy entry "Common"'
                      }
                    ],
                  :type=>:data_provider,
                  :name=>'Environment Data Provider (hiera configuration version 5)'
                }
              ],
            :key=>'a',
            :type=>:root
          }
        ]
      }
    }

    around(:each) do |example|
      # Initialize settings to get a full compile as close as possible to a real
      # environment load
      Puppet.settings.initialize_global_settings
      loader = Puppet::Environments::Directories.new(environmentpath, [])
      Puppet.override(:environments => loader) do
        example.run
      end
    end

    it '--explain produces human readable text by default and does not produce output to debug logger' do
      lookup.options[:node] = node
      lookup.options[:explain] = true
      lookup.command_line.stubs(:args).returns(['a'])
      logs = []
      Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
        expect(run_lookup(lookup)).to eql(<<-EXPLANATION.chomp)
Searching for "lookup_options"
  Global Data Provider (hiera configuration version 5)
    No such key: "lookup_options"
  Environment Data Provider (hiera configuration version 5)
    Hierarchy entry "Common"
      Path "#{environmentpath}/production/data/common.yaml"
        Original path: "common.yaml"
        Found key: "lookup_options" value: {
          "a" => "first"
        }
Searching for "a"
  Global Data Provider (hiera configuration version 5)
    No such key: "a"
  Environment Data Provider (hiera configuration version 5)
    Hierarchy entry "Common"
      Path "#{environmentpath}/production/data/common.yaml"
        Original path: "common.yaml"
        Found key: "a" value: "This is A"
        EXPLANATION
      end
      expect(logs.any? { |log| log.level == :debug }).to be_falsey
    end

    it '--debug using multiple interpolation functions produces output to the logger' do
      lookup.options[:node] = node
      lookup.command_line.stubs(:args).returns(['ab'])
      Puppet.debug = true
      logs = []
      begin
        Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
          expect { lookup.run_command }.to output(<<-VALUE.unindent).to_stdout
            --- This is A and This is B
            ...
          VALUE
        end
      rescue SystemExit => e
        expect(e.status).to eq(0)
      end
      logs = logs.select { |log| log.level == :debug }.map { |log| log.message }
      expect(logs).to include(/Found key: "ab" value: "This is A and This is B"/)
    end

    it '--explain produces human readable text by default and --debug produces the same output to debug logger' do
      lookup.options[:node] = node
      lookup.options[:explain] = true
      lookup.command_line.stubs(:args).returns(['a'])
      Puppet.debug = true
      logs = []
      Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
        expect(run_lookup(lookup)).to eql(<<-EXPLANATION.chomp)
Searching for "lookup_options"
  Global Data Provider (hiera configuration version 5)
    No such key: "lookup_options"
  Environment Data Provider (hiera configuration version 5)
    Hierarchy entry "Common"
      Path "#{environmentpath}/production/data/common.yaml"
        Original path: "common.yaml"
        Found key: "lookup_options" value: {
          "a" => "first"
        }
Searching for "a"
  Global Data Provider (hiera configuration version 5)
    No such key: "a"
  Environment Data Provider (hiera configuration version 5)
    Hierarchy entry "Common"
      Path "#{environmentpath}/production/data/common.yaml"
        Original path: "common.yaml"
        Found key: "a" value: "This is A"
        EXPLANATION
      end
      logs = logs.select { |log| log.level == :debug }.map { |log| log.message }
      expect(logs).to include(<<-EXPLANATION.chomp)
Lookup of 'a'
  Searching for "lookup_options"
    Global Data Provider (hiera configuration version 5)
      No such key: "lookup_options"
    Environment Data Provider (hiera configuration version 5)
      Hierarchy entry "Common"
        Path "#{environmentpath}/production/data/common.yaml"
          Original path: "common.yaml"
          Found key: "lookup_options" value: {
            "a" => "first"
          }
  Searching for "a"
    Global Data Provider (hiera configuration version 5)
      No such key: "a"
    Environment Data Provider (hiera configuration version 5)
      Hierarchy entry "Common"
        Path "#{environmentpath}/production/data/common.yaml"
          Original path: "common.yaml"
          Found key: "a" value: "This is A"
      EXPLANATION
    end

    it '--explain-options produces human readable text of a hash merge' do
      lookup.options[:node] = node
      lookup.options[:explain_options] = true
      expect(run_lookup(lookup)).to eql(<<-EXPLANATION.chomp)
Merge strategy hash
  Global Data Provider (hiera configuration version 5)
    No such key: "lookup_options"
  Environment Data Provider (hiera configuration version 5)
    Hierarchy entry "Common"
      Path "#{environmentpath}/production/data/common.yaml"
        Original path: "common.yaml"
        Found key: "lookup_options" value: {
          "a" => "first"
        }
  Merged result: {
    "a" => "first"
  }
      EXPLANATION
    end

    it '--explain-options produces human readable text of a hash merge and --debug produces the same output to debug logger' do
      lookup.options[:node] = node
      lookup.options[:explain_options] = true
      Puppet.debug = true
      logs = []
      Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
        expect(run_lookup(lookup)).to eql(<<-EXPLANATION.chomp)
Merge strategy hash
  Global Data Provider (hiera configuration version 5)
    No such key: "lookup_options"
  Environment Data Provider (hiera configuration version 5)
    Hierarchy entry "Common"
      Path "#{environmentpath}/production/data/common.yaml"
        Original path: "common.yaml"
        Found key: "lookup_options" value: {
          "a" => "first"
        }
  Merged result: {
    "a" => "first"
  }
          EXPLANATION
      logs = logs.select { |log| log.level == :debug }.map { |log| log.message }
      expect(logs).to include(<<-EXPLANATION.chomp)
Lookup of '__global__'
  Merge strategy hash
    Global Data Provider (hiera configuration version 5)
      No such key: "lookup_options"
    Environment Data Provider (hiera configuration version 5)
      Hierarchy entry "Common"
        Path "#{environmentpath}/production/data/common.yaml"
          Original path: "common.yaml"
          Found key: "lookup_options" value: {
            "a" => "first"
          }
    Merged result: {
      "a" => "first"
    }
        EXPLANATION
      end
    end

    it '--explain produces human readable text of a hash merge when using both --explain and --explain-options' do
      lookup.options[:node] = node
      lookup.options[:explain] = true
      lookup.options[:explain_options] = true
      lookup.command_line.stubs(:args).returns(['a'])
      expect(run_lookup(lookup)).to eql(<<-EXPLANATION.chomp)
Searching for "lookup_options"
  Global Data Provider (hiera configuration version 5)
    No such key: "lookup_options"
  Environment Data Provider (hiera configuration version 5)
    Hierarchy entry "Common"
      Path "#{environmentpath}/production/data/common.yaml"
        Original path: "common.yaml"
        Found key: "lookup_options" value: {
          "a" => "first"
        }
Searching for "a"
  Global Data Provider (hiera configuration version 5)
    No such key: "a"
  Environment Data Provider (hiera configuration version 5)
    Hierarchy entry "Common"
      Path "#{environmentpath}/production/data/common.yaml"
        Original path: "common.yaml"
        Found key: "a" value: "This is A"
      EXPLANATION
    end

    it 'can produce a yaml explanation' do
      lookup.options[:node] = node
      lookup.options[:explain] = true
      lookup.options[:render_as] = :yaml
      lookup.command_line.stubs(:args).returns(['a'])
      output = run_lookup(lookup)
      expect(YAML.load(output)).to eq(expected_yaml_hash)
    end

    it 'can produce a json explanation' do
      lookup.options[:node] = node
      lookup.options[:explain] = true
      lookup.options[:render_as] = :json
      lookup.command_line.stubs(:args).returns(['a'])
      output = run_lookup(lookup)
      expect(JSON.parse(output)).to eq(expected_json_hash)
    end

    it 'can access values using dotted keys' do
      lookup.options[:node] = node
      lookup.options[:render_as] = :json
      lookup.command_line.stubs(:args).returns(['d.one.two.three'])
      output = run_lookup(lookup)
      expect(JSON.parse("[#{output}]")).to eq(['the value'])
    end

    it 'can access values using quoted dotted keys' do
      lookup.options[:node] = node
      lookup.options[:render_as] = :json
      lookup.command_line.stubs(:args).returns(['"e.one.two.three"'])
      output = run_lookup(lookup)
      expect(JSON.parse("[#{output}]")).to eq(['the value'])
    end

    it 'can access values using mix of dotted keys and quoted dotted keys' do
      lookup.options[:node] = node
      lookup.options[:render_as] = :json
      lookup.command_line.stubs(:args).returns(['"f.one"."two.three".1'])
      output = run_lookup(lookup)
      expect(JSON.parse("[#{output}]")).to eq(['second value'])
    end

    context 'the global scope' do
      include PuppetSpec::Files

      it "is unaffected by global variables unless '--compile' is used" do
        lookup.options[:node] = node
        lookup.command_line.stubs(:args).returns(['c'])
        expect(run_lookup(lookup)).to eql("--- This is\n...")
      end

      it "is affected by global variables when '--compile' is used" do
        lookup.options[:node] = node
        lookup.options[:compile] = true
        lookup.command_line.stubs(:args).returns(['c'])
        expect(run_lookup(lookup)).to eql("--- This is C from site.pp\n...")
      end

      it 'receives extra facts in top scope' do
        file_path = tmpdir('lookup_spec')
        filename = File.join(file_path, "facts.yaml")
        File.open(filename, "w+") { |f| f.write(<<-YAML.unindent) }
          ---
          cx: ' C from facts'
          YAML

        lookup.options[:node] = node
        lookup.options[:fact_file] = filename
        lookup.command_line.stubs(:args).returns(['c'])
        expect(run_lookup(lookup)).to eql("--- This is C from facts\n...")
      end

      it 'receives extra facts in the facts hash' do
        file_path = tmpdir('lookup_spec')
        filename = File.join(file_path, "facts.yaml")
        File.open(filename, "w+") { |f| f.write(<<-YAML.unindent) }
          ---
          cx: ' G from facts'
        YAML

        lookup.options[:node] = node
        lookup.options[:fact_file] = filename
        lookup.command_line.stubs(:args).returns(['g'])
        expect(run_lookup(lookup)).to eql("--- This is G from facts in facts hash\n...")
      end
    end

    context 'using a puppet function as data provider' do
      let(:node) { Puppet::Node.new("testnode", :facts => facts, :environment => 'puppet_func_provider') }

      it "works OK in the absense of '--compile'" do
        lookup.options[:node] = node
        lookup.command_line.stubs(:args).returns(['c'])
        expect(run_lookup(lookup)).to eql("--- This is C from data.pp\n...")
      end

      it "global scope is affected by global variables when '--compile' is used" do
        lookup.options[:node] = node
        lookup.options[:compile] = true
        lookup.command_line.stubs(:args).returns(['c'])
        expect(run_lookup(lookup)).to eql("--- This is C from site.pp\n...")
      end
    end
  end
end
