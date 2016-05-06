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

  it "applies a given file even when an ENC is configured and specifies an environment",
     :if => !Puppet.features.microsoft_windows? do
    manifest = file_containing("manifest.pp", "notice('specific manifest applied')")
    enc = file_containing("enc_script", <<-ENC)
                                        #!/bin/sh
                                        echo 'classes: []'
                                        echo 'environment: special'
                                        ENC
    File.chmod(0755, enc)

    #Dir.mkdir(File.join(Puppet[:environmentpath], "special"), 0755)

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
    # External node script execution will fail, likely due to the tempering
    # with the basic file descriptors.
    # Workaround: Define a log destination and merely inspect logs.
    context "with an ENC",
        :if => !Puppet.features.microsoft_windows? do
      let(:logdest) { tmpfile('logdest') }
      let(:args) { ['-e', execute, '--logdest', logdest ] }
      let(:enc) do
        result = file_containing("enc_script", <<-ENC)
          #!/bin/sh
          echo 'environment: spec'
          ENC
        File.chmod(0755, result)
        result
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
        expect(logs * "\n").to match /doesn't match server specified environment/
      end

    end

  end

end
