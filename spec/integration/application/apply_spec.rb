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

      expect(Puppet::FileSystem.exist?(file_to_create)).to be_true
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

  it "applies a given file even when an ENC is configured", :if => !Puppet.features.microsoft_windows? do
    manifest = file_containing("manifest.pp", "notice('specific manifest applied')")
    site_manifest = file_containing("site_manifest.pp", "notice('the site manifest was applied instead')")
    enc = file_containing("enc_script", "#!/bin/sh\necho 'classes: []'")
    File.chmod(0755, enc)

    special = Puppet::Node::Environment.create(:special, [])
    Puppet.override(:current_environment => special) do
      Puppet[:environment] = 'special'
      Puppet[:node_terminus] = 'exec'
      Puppet[:external_nodes] = enc
      Puppet[:manifest] = site_manifest
      puppet = Puppet::Application[:apply]
      puppet.stubs(:command_line).returns(stub('command_line', :args => [manifest]))
      expect { puppet.run_command }.to exit_with(0)
    end

    expect(@logs.map(&:to_s)).to include('specific manifest applied')
  end

  context "with a module" do
    let(:modulepath) { tmpdir('modulepath') }
    let(:execute) { 'include amod' }
    let(:args) { ['-e', execute, '--modulepath', modulepath] }

    before(:each) do
      dir_contained_in(modulepath, {
        "amod" => {
          "manifests" => {
            "init.pp" => "class amod{ notice('amod class included') }"
          }
        }
      })

      Puppet[:environmentpath] = dir_containing("environments", { Puppet[:environment] => {} })
    end

    def init_cli_args_and_apply_app(args, execute)
      Puppet.initialize_settings(args)
      puppet = Puppet::Application.find(:apply).new(stub('command_line', :subcommand_name => :apply, :args => args))
      puppet.options[:code] = execute
      return puppet
    end

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

end
