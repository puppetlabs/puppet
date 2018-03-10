require 'spec_helper'
require 'puppet_spec/files'
require 'puppet_spec/compiler'

describe "apply" do
  include PuppetSpec::Files

  before :each do
    Puppet[:reports] = "none"
  end

  describe "when applying provided catalogs" do
    it "can apply catalogs provided in a file in json" do
      file_to_create = tmpfile("json_catalog")
      catalog = Puppet::Resource::Catalog.new('mine', Puppet.lookup(:environments).get(Puppet[:environment]))
      resource = Puppet::Resource.new(:file, file_to_create, :parameters => {:content => "my stuff"})
      catalog.add_resource resource

      manifest = file_containing("manifest", catalog.to_json)

      puppet = Puppet::Application[:apply]
      puppet.options[:catalog] = manifest

      puppet.apply

      expect(Puppet::FileSystem.exist?(file_to_create)).to be_truthy
      expect(File.read(file_to_create)).to eq("my stuff")
    end

    context 'from environment with a pcore defined resource type' do
      include PuppetSpec::Compiler

      let!(:envdir) { tmpdir('environments') }
      let(:env_name) { 'spec' }
      let(:dir_structure) {
        {
          '.resource_types' => {
            'applytest.pp' => <<-CODE
            Puppet::Resource::ResourceType3.new(
              'applytest',
              [Puppet::Resource::Param.new(String, 'message')],
              [Puppet::Resource::Param.new(String, 'name', true)])
          CODE
          },
          'modules' => {
            'amod' => {
              'lib' => {
                'puppet' => {
                  'type' => { 'applytest.rb' => <<-CODE
Puppet::Type.newtype(:applytest) do
newproperty(:message) do
  def sync
    Puppet.send(@resource[:loglevel], self.should)
  end

  def retrieve
    :absent
  end

  def insync?(is)
    false
  end

  defaultto { @resource[:name] }
end

newparam(:name) do
  desc "An arbitrary tag for your own reference; the name of the message."
  Puppet.notice('the Puppet::Type says hello')
  isnamevar
end
end
                  CODE
                  }
                }
              }
            }
          }
        }
      }

      let(:environments) { Puppet::Environments::Directories.new(envdir, []) }
      let(:env) { Puppet::Node::Environment.create(:'spec', [File.join(envdir, 'spec', 'modules')]) }
      let(:node) { Puppet::Node.new('test', :environment => env) }
      around(:each) do |example|
        Puppet::Type.rmtype(:applytest)
        Puppet[:environment] = env_name
        dir_contained_in(envdir, env_name => dir_structure)
        Puppet.override(:environments => environments, :current_environment => env) do
          example.run
        end
      end

      it 'does not load the pcore type' do
        catalog = compile_to_catalog('applytest { "applytest was here":}', node)
        apply = Puppet::Application[:apply]
        apply.options[:catalog] = file_containing('manifest', catalog.to_json)

        Puppet[:environmentpath] = envdir
        Puppet::Pops::Loader::Runtime3TypeLoader.any_instance.expects(:find).never
        expect { apply.run }.to have_printed(/the Puppet::Type says hello.*applytest was here/m)
      end

      # Test just to verify that the Pcore Resource Type and not the Ruby one is produced when the catalog is produced
      it 'loads pcore resource type instead of ruby resource type during compile' do
        Puppet[:code] = 'applytest { "applytest was here": }'
        compiler = Puppet::Parser::Compiler.new(node)
        tn = Puppet::Pops::Loader::TypedName.new(:resource_type_pp, 'applytest')
        rt = Puppet::Pops::Resource::ResourceTypeImpl.new('applytest', [Puppet::Pops::Resource::Param.new(String, 'message')], [Puppet::Pops::Resource::Param.new(String, 'name', true)])

        compiler.loaders.runtime3_type_loader.instance_variable_get(:@resource_3x_loader).expects(:set_entry).once.with(tn, rt, is_a(String))
          .returns(Puppet::Pops::Loader::Loader::NamedEntry.new(tn, rt, nil))
        expect { compiler.compile }.not_to have_printed(/the Puppet::Type says hello/)
      end

      it "does not fail when pcore type is loaded twice" do
        Puppet[:code] = 'applytest { xyz: alias => aptest }; Resource[applytest]'
        compiler = Puppet::Parser::Compiler.new(node)
        expect { compiler.compile }.not_to raise_error
      end

      it "does not load the ruby type when using function 'defined()' on a loaded resource that is missing from the catalog" do
        # Ensure that the Resource[applytest,foo] is loaded'
        eval_and_collect_notices('applytest { xyz: }', node)

        # Ensure that:
        # a) The catalog contains aliases (using a name for the abc resource ensures this)
        # b) That Resource[applytest,xyz] is not defined in the catalog (although it's loaded)
        # c) That this doesn't trigger a load of the Puppet::Type
        notices = eval_and_collect_notices('applytest { abc: name => some_alias }; notice(defined(Resource[applytest,xyz]))', node)
        expect(notices).to include('false')
        expect(notices).not_to include('the Puppet::Type says hello')
      end

      it 'does not load the ruby type when when referenced from collector during compile' do
        notices = eval_and_collect_notices("@applytest { 'applytest was here': }\nApplytest<| title == 'applytest was here' |>", node)
        expect(notices).not_to include('the Puppet::Type says hello')
      end

      it 'does not load the ruby type when when referenced from exported collector during compile' do
        notices = eval_and_collect_notices("@@applytest { 'applytest was here': }\nApplytest<<| |>>", node)
        expect(notices).not_to include('the Puppet::Type says hello')
      end
    end
  end

  context 'from environment with pcore object types' do
    include PuppetSpec::Compiler

    let!(:envdir) { Puppet[:environmentpath] }
    let(:env_name) { 'spec' }
    let(:dir_structure) {
      {
        'environment.conf' => <<-CONF,
          rich_data = true
        CONF
        'modules' => {
          'mod' => {
            'types' => {
              'streetaddress.pp' => <<-PUPPET,
                type Mod::StreetAddress = Object[{
                  attributes => {
                    'street' => String,
                    'zipcode' => String,
                    'city' => String,
                  } 
                }]
              PUPPET
              'address.pp' => <<-PUPPET,
                type Mod::Address = Object[{
                  parent => Mod::StreetAddress,
                  attributes => {
                    'state' => String
                  } 
                }]
              PUPPET
              'contact.pp' => <<-PUPPET,
                type Mod::Contact = Object[{
                  attributes => {
                    'address' => Mod::Address,
                    'email' => String
                  }
                }]
              PUPPET
            },
            'manifests' => {
              'init.pp' => <<-PUPPET,
                define mod::person(Mod::Contact $contact) {
                  notify { $title: }
                  notify { $contact.address.street: }
                  notify { $contact.address.zipcode: }
                  notify { $contact.address.city: }
                  notify { $contact.address.state: }
                }

                class mod {
                  mod::person { 'Test Person':
                    contact => Mod::Contact(
                      Mod::Address('The Street 23', '12345', 'Some City', 'A State'),
                      'test@example.com')
                  }
                }
              PUPPET
            }
          }
        }
      }
    }

    let(:env) { Puppet::Node::Environment.create(env_name.to_sym, [File.join(envdir, env_name, 'modules')]) }
    let(:node) { Puppet::Node.new('test', :environment => env) }

    before(:each) do
      dir_contained_in(envdir, env_name => dir_structure)
      PuppetSpec::Files.record_tmp(File.join(envdir, env_name))
    end

    it 'can compile the catalog' do
      compile_to_catalog('include mod', node)
    end

    it 'can apply the catalog' do
      catalog = compile_to_catalog('include mod', node)

      Puppet[:environment] = env_name
      apply = Puppet::Application[:apply]
      apply.options[:catalog] = file_containing('manifest', catalog.to_json)
      expect { apply.run_command; exit(0) }.to exit_with(0)
      expect(@logs.map(&:to_s)).to include('The Street 23')
    end
  end

  it "applies a given file even when a directory environment is specified" do
    manifest = file_containing("manifest.pp", "notice('it was applied')")

    special = Puppet::Node::Environment.create(:special, [])
    Puppet.override(:current_environment => special) do
      Puppet[:environment] = 'special'
      puppet = Puppet::Application[:apply]
      puppet.stubs(:command_line).returns(stub('command_line', :args => [manifest]))
      expect { puppet.run_command }.to exit_with(0)
    end

    expect(@logs.map(&:to_s)).to include('it was applied')
  end

  it "adds environment to the $server_facts variable" do
    manifest = file_containing("manifest.pp", "notice(\"$server_facts\")")

    puppet = Puppet::Application[:apply]
    puppet.stubs(:command_line).returns(stub('command_line', :args => [manifest]))

    expect { puppet.run_command }.to exit_with(0)

    expect(@logs.map(&:to_s)).to include(/{environment =>.*/)
  end

  it "applies a given file even when an ENC is configured", :if => !Puppet.features.microsoft_windows? do
    manifest = file_containing("manifest.pp", "notice('specific manifest applied')")
    enc = script_containing('enc_script',
      :windows => '@echo classes: []' + "\n" + '@echo environment: special',
      :posix   => '#!/bin/sh' + "\n" + 'echo "classes: []"' + "\n" + 'echo "environment: special"')

    Dir.mkdir(File.join(Puppet[:environmentpath], "special"), 0755)

    special = Puppet::Node::Environment.create(:special, [])
    Puppet.override(:current_environment => special) do
      Puppet[:environment] = 'special'
      Puppet[:node_terminus] = 'exec'
      Puppet[:external_nodes] = enc
      puppet = Puppet::Application[:apply]
      puppet.stubs(:command_line).returns(stub('command_line', :args => [manifest]))
      expect { puppet.run_command }.to exit_with(0)
    end

    expect(@logs.map(&:to_s)).to include('specific manifest applied')
  end

  context "handles errors" do
    it "logs compile errors once" do
      Puppet.initialize_settings([])
      apply = Puppet::Application.find(:apply).new(stub('command_line', :subcommand_name => :apply, :args => []))
      apply.options[:code] = '08'

      msg = 'valid octal'
      callback = Proc.new do |actual|
        expect(actual.scan(Regexp.new(msg))).to eq([msg])
      end

      expect do
        apply.run
      end.to have_printed(callback).and_exit_with(1)
    end

    it "logs compile post processing errors once" do
      Puppet.initialize_settings([])
      apply = Puppet::Application.find(:apply).new(stub('command_line', :subcommand_name => :apply, :args => []))
      path = File.expand_path('/tmp/content_file_test.Q634Dlmtime')
      apply.options[:code] = "file { '#{path}':
        content => 'This is the test file content',
        ensure => present,
        checksum => mtime
      }"

      msg = 'You cannot specify content when using checksum'
      callback = Proc.new do |actual|
        expect(actual.scan(Regexp.new(msg))).to eq([msg])
      end

      expect do
        apply.run
      end.to have_printed(callback).and_exit_with(1)
    end
  end

  context "with a module in an environment" do
    let(:envdir) { tmpdir('environments') }
    let(:modulepath) { File.join(envdir, 'spec', 'modules') }
    let(:execute) { 'include amod' }

    before(:each) do
      dir_contained_in(envdir, {
        "spec" => {
          "modules" => {
            "amod" => {
              "manifests" => {
                "init.pp" => "class amod{ notice('amod class included') }"
              }
            }
          }
        }
      })

      Puppet[:environmentpath] = envdir
    end

    def init_cli_args_and_apply_app(args, execute)
      Puppet.initialize_settings(args)
      puppet = Puppet::Application.find(:apply).new(stub('command_line', :subcommand_name => :apply, :args => args))
      puppet.options[:code] = execute
      return puppet
    end

    context "given the --modulepath option" do
      let(:args) { ['-e', execute, '--modulepath', modulepath] }

      it "looks in --modulepath even when the default directory environment exists" do
        apply = init_cli_args_and_apply_app(args, execute)

        expect do
          expect { apply.run }.to exit_with(0)
        end.to have_printed('amod class included')
      end

      it "looks in --modulepath even when given a specific directory --environment" do
        args << '--environment' << 'production'
        apply = init_cli_args_and_apply_app(args, execute)

        expect do
          expect { apply.run }.to exit_with(0)
        end.to have_printed('amod class included')
      end

      it "looks in --modulepath when given multiple paths in --modulepath" do
        args = ['-e', execute, '--modulepath', [tmpdir('notmodulepath'), modulepath].join(File::PATH_SEPARATOR)]
        apply = init_cli_args_and_apply_app(args, execute)

        expect do
          expect { apply.run }.to exit_with(0)
        end.to have_printed('amod class included')
      end
    end

    # When executing an ENC script, output cannot be captured using
    # expect { }.to have_printed(...)
    # External node script execution will fail, likely due to the tampering
    # with the basic file descriptors.
    # Workaround: Define a log destination and merely inspect logs.
    context "with an ENC" do
      let(:logdest) { tmpfile('logdest') }
      let(:args) { ['-e', execute, '--logdest', logdest ] }
      let(:enc) do
        script_containing('enc_script',
          :windows => '@echo environment: spec',
          :posix   => '#!/bin/sh' + "\n" + 'echo "environment: spec"')
      end

      before :each do
        Puppet[:node_terminus] = 'exec'
        Puppet[:external_nodes] = enc
      end

      it "should use the environment that the ENC mandates" do
        apply = init_cli_args_and_apply_app(args, execute)
        expect { apply.run }.to exit_with(0)
        expect(@logs.map(&:to_s)).to include('amod class included')
      end

      it "should prefer the ENC environment over the configured one and emit a warning" do
        apply = init_cli_args_and_apply_app(args + [ '--environment', 'production' ], execute)
        expect { apply.run }.to exit_with(0)
        logs = @logs.map(&:to_s)
        expect(logs).to include('amod class included')
        expect(logs).to include(match(/doesn't match server specified environment/))
      end
    end
  end

  context 'when compiling a provided catalog with rich data and then applying from file' do
    include PuppetSpec::Compiler

    let(:env_dir) { tmpdir('environments') }
    let(:execute) { 'include amod' }
    let(:rich_data) { false }
    let(:env_name) { 'spec' }
    let(:populated_env_dir) do
      dir_contained_in(env_dir, {
        env_name => {
          'modules' => {
            'amod' => {
              'manifests' => {
                'init.pp' => <<-EOF
class amod {
  notify { rx: message => /[Rr]eg[Ee]xp/ }
  notify { bin: message => Binary('w5ZzdGVuIG1lZCByw7ZzdGVuCg==') }
  notify { ver: message  => SemVer('2.3.1') }
  notify { vrange: message => SemVerRange('>=2.3.0') }
  notify { tspan: message => Timespan(3600) }
  notify { tstamp: message => Timestamp('2012-03-04T18:15:11.001') }
}

class amod::bad_type {
  notify { bogus: message => amod::bogus() }
}
              EOF
              },
              'lib' => {
                'puppet' => {
                  'functions' => {
                    'amod' => {
                      'bogus.rb' => <<-RUBY
                        # Function that leaks an object that is not recognized in the catalog
                        Puppet::Functions.create_function(:'amod::bogus') do
                          def bogus()
                            Time.new(2016, 10, 6, 23, 51, 14, '+02:00')
                          end
                        end
                      RUBY
                    }
                  }
                }
              }
            }
          }
        }
      })
      env_dir
    end

    let(:env) { Puppet::Node::Environment.create(env_name.to_sym, [File.join(populated_env_dir, 'spec', 'modules')]) }
    let(:node) { Puppet::Node.new('test', :environment => env) }

    around(:each) do |example|
      Puppet[:rich_data] = rich_data
      Puppet.override(:loaders => Puppet::Pops::Loaders.new(env)) { example.run }
    end

    context 'and rich_data is set to false during compile' do
      it 'will notify a string that is the result of Regexp#inspect (from Runtime3xConverter)' do
        catalog = compile_to_catalog(execute, node)
        apply = Puppet::Application[:apply]
        apply.options[:catalog] = file_containing('manifest', catalog.to_json)
        apply.expects(:apply_catalog).with do |cat|
          cat.resource(:notify, 'rx')['message'].is_a?(String)
          cat.resource(:notify, 'bin')['message'].is_a?(String)
          cat.resource(:notify, 'ver')['message'].is_a?(String)
          cat.resource(:notify, 'vrange')['message'].is_a?(String)
          cat.resource(:notify, 'tspan')['message'].is_a?(String)
          cat.resource(:notify, 'tstamp')['message'].is_a?(String)
        end
        apply.run
      end

      it 'will notify a string that is the result of to_s on uknown data types' do
        json = compile_to_catalog('include amod::bad_type', node).to_json
        apply = Puppet::Application[:apply]
        apply.options[:catalog] = file_containing('manifest', json)
        apply.expects(:apply_catalog).with do |catalog|
          catalog.resource(:notify, 'bogus')['message'].is_a?(String)
        end
        apply.run
      end

      it 'will log a warning that a value of unknown type is converted into a string' do
        logs = []
        Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
          compile_to_catalog('include amod::bad_type', node).to_json
        end
        logs = logs.select { |log| log.level == :warning }.map { |log| log.message }
        expect(logs.empty?).to be_falsey
        expect(logs[0]).to eql("Notify[bogus]['message'] contains a Time value. It will be converted to the String '2016-10-06 23:51:14 +0200'")
      end
    end

    context 'and rich_data is set to true during compile' do
      let(:rich_data) { true }

      it 'will notify a regexp using Regexp#to_s' do
        catalog = compile_to_catalog(execute, node)
        apply = Puppet::Application[:apply]
        apply.options[:catalog] = file_containing('manifest', catalog.to_json)
        apply.expects(:apply_catalog).with do |cat|
          cat.resource(:notify, 'rx')['message'].is_a?(Regexp)
          cat.resource(:notify, 'bin')['message'].is_a?(Puppet::Pops::Types::PBinaryType::Binary)
          cat.resource(:notify, 'ver')['message'].is_a?(SemanticPuppet::Version)
          cat.resource(:notify, 'vrange')['message'].is_a?(SemanticPuppet::VersionRange)
          cat.resource(:notify, 'tspan')['message'].is_a?(Puppet::Pops::Time::Timespan)
          cat.resource(:notify, 'tstamp')['message'].is_a?(Puppet::Pops::Time::Timestamp)
        end
        apply.run
      end
    end

  end
end
