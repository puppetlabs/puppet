require 'spec_helper'
require 'puppet_spec/files'
require 'puppet_spec/compiler'

describe "apply" do
  include PuppetSpec::Files

  before :each do
    Puppet[:reports] = "none"
  end

  describe "when applying provided catalogs" do
    it "can apply catalogs provided in a file in pson" do
      file_to_create = tmpfile("pson_catalog")
      catalog = Puppet::Resource::Catalog.new('mine', Puppet.lookup(:environments).get(Puppet[:environment]))
      resource = Puppet::Resource.new(:file, file_to_create, :parameters => {:content => "my stuff"})
      catalog.add_resource resource

      manifest = file_containing("manifest", catalog.to_pson)

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
            Puppet::Resource::ResourceType3.new('applytest', [Puppet::Resource::Param.new(String, 'message')], [Puppet::Resource::Param.new(String, 'name', true)])
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
        Puppet[:environment] = env_name
        dir_contained_in(envdir, env_name => dir_structure)
        Puppet.override(:environments => environments, :current_environment => env) do
          example.run
        end
      end

      it 'does not load the pcore type' do
        catalog = compile_to_catalog('applytest { "applytest was here": }', node)
        apply = Puppet::Application[:apply]
        apply.options[:catalog] = file_containing('manifest', catalog.to_pson)

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

  it "adds environment to the $server_facts variable if trusted_server_facts is true" do
    manifest = file_containing("manifest.pp", "notice(\"$server_facts\")")
    Puppet[:trusted_server_facts] = true

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
end
