require 'spec_helper'
require 'puppet_spec/files'

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
