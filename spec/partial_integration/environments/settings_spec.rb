require 'spec_helper'
require 'puppet_spec/settings'

describe "environment settings" do
  include PuppetSpec::Settings

  let(:confdir) { Puppet[:confdir] }
  let(:cmdline_args) { ['--confdir', confdir, '--vardir', Puppet[:vardir], '--hiera_config', Puppet[:hiera_config]] }
  let(:environmentpath) { File.expand_path("envdir", confdir) }
  let(:testingdir) { File.join(environmentpath, "testing") }

  before(:each) do
    FileUtils.mkdir_p(testingdir)
  end

  def init_puppet_conf(settings = {})
    set_puppet_conf(confdir, <<-EOF)
      environmentpath=#{environmentpath}
      #{settings.map { |k,v| "#{k}=#{v}" }.join("\n")}
    EOF
    Puppet.initialize_settings
  end

  it "raises an error if you set manifest in puppet.conf" do
    expect { init_puppet_conf("manifest" => "/something") }.to raise_error(Puppet::Settings::SettingsError, /Cannot set manifest.*in puppet.conf/)
  end

  it "raises an error if you set modulepath in puppet.conf" do
    expect { init_puppet_conf("modulepath" => "/something") }.to raise_error(Puppet::Settings::SettingsError, /Cannot set modulepath.*in puppet.conf/)
  end

  it "raises an error if you set config_version in puppet.conf" do
    expect { init_puppet_conf("config_version" => "/something") }.to raise_error(Puppet::Settings::SettingsError, /Cannot set config_version.*in puppet.conf/)
  end

  context "when given an environment" do
    before(:each) do
      init_puppet_conf
    end

    context "without an environment.conf" do
      it "reads manifest from environment.conf defaults" do
        expect(Puppet.settings.value(:manifest, :testing)).to eq(File.join(testingdir, "manifests"))
      end

      it "reads modulepath from environment.conf defaults" do
        expect(Puppet.settings.value(:modulepath, :testing)).to match(/#{File.join(testingdir, "modules")}/)
      end

      it "reads config_version from environment.conf defaults" do
        expect(Puppet.settings.value(:config_version, :testing)).to eq('')
      end
    end

    context "with an environment.conf" do
      before(:each) do
        set_environment_conf(environmentpath, 'testing', <<-EOF)
          manifest=/special/manifest
          modulepath=/special/modulepath
          config_version=/special/config_version
        EOF
      end

      it "reads the configured manifest" do
        expect(Puppet.settings.value(:manifest, :testing)).to eq(Puppet::FileSystem.expand_path('/special/manifest'))
      end

      it "reads the configured modulepath" do
        expect(Puppet.settings.value(:modulepath, :testing)).to eq(Puppet::FileSystem.expand_path('/special/modulepath'))
      end

      it "reads the configured config_version" do
        expect(Puppet.settings.value(:config_version, :testing)).to eq(Puppet::FileSystem.expand_path('/special/config_version'))
      end
    end

    context "with an environment.conf containing 8.3 style Windows paths",
      :if => Puppet::Util::Platform.windows? do

      before(:each) do
        # set 8.3 style Windows paths
        @modulepath = Puppet::Util::Windows::File.get_short_pathname(PuppetSpec::Files.tmpdir('fakemodulepath'))

        # for expansion to work, the file must actually exist
        @manifest = PuppetSpec::Files.tmpfile('foo.pp', @modulepath)
        # but tmpfile won't create an empty file
        Puppet::FileSystem.touch(@manifest)
        @manifest = Puppet::Util::Windows::File.get_short_pathname(@manifest)

        set_environment_conf(environmentpath, 'testing', <<-EOF)
          manifest=#{@manifest}
          modulepath=#{@modulepath}
        EOF
      end

      it "reads the configured manifest as a fully expanded path" do
        expect(Puppet.settings.value(:manifest, :testing)).to eq(Puppet::FileSystem.expand_path(@manifest))
      end

      it "reads the configured modulepath as a fully expanded path" do
        expect(Puppet.settings.value(:modulepath, :testing)).to eq(Puppet::FileSystem.expand_path(@modulepath))
      end
    end

    context "when environment name collides with a puppet.conf section" do
      let(:testingdir) { File.join(environmentpath, "main") }

      it "reads manifest from environment.conf defaults" do
        expect(Puppet.settings.value(:environmentpath)).to eq(environmentpath)
        expect(Puppet.settings.value(:manifest, :main)).to eq(File.join(testingdir, "manifests"))
      end

      context "and an environment.conf" do
        before(:each) do
          set_environment_conf(environmentpath, 'main', <<-EOF)
            manifest=/special/manifest
          EOF
        end

        it "reads manifest from environment.conf settings" do
          expect(Puppet.settings.value(:environmentpath)).to eq(environmentpath)
          expect(Puppet.settings.value(:manifest, :main)).to eq(Puppet::FileSystem.expand_path("/special/manifest"))
        end
      end
    end
  end

end
