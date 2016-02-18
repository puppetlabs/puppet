require 'spec_helper'
require 'puppet/settings/environment_conf.rb'

describe Puppet::Settings::EnvironmentConf do

  def setup_environment_conf(config, conf_hash)
    conf_hash.each do |setting,value|
      config.expects(:setting).with(setting).returns(
        mock('setting', :value => value)
      )
    end
  end

  context "with config" do
    let(:config) { stub('config') }
    let(:envconf) { Puppet::Settings::EnvironmentConf.new("/some/direnv", config, ["/global/modulepath"]) }

    it "reads a modulepath from config and does not include global_module_path" do
      setup_environment_conf(config, :modulepath => '/some/modulepath')

      expect(envconf.modulepath).to eq(File.expand_path('/some/modulepath'))
    end

    it "reads a manifest from config" do
      setup_environment_conf(config, :manifest => '/some/manifest')

      expect(envconf.manifest).to eq(File.expand_path('/some/manifest'))
    end

    it "reads a config_version from config" do
      setup_environment_conf(config, :config_version => '/some/version.sh')

      expect(envconf.config_version).to eq(File.expand_path('/some/version.sh'))
    end

    it "reads an environment_timeout from config" do
      setup_environment_conf(config, :environment_timeout => '3m')

      expect(envconf.environment_timeout).to eq(180)
    end

    it "reads a static_catalogs from config" do
      setup_environment_conf(config, :static_catalogs => true)

      expect(envconf.static_catalogs).to eq(true)
    end

    it "can retrieve untruthy settings" do
      Puppet[:static_catalogs] = true
      setup_environment_conf(config, :static_catalogs => false)

      expect(envconf.static_catalogs).to eq(false)
    end

    it "can retrieve raw settings" do
      setup_environment_conf(config, :manifest => 'manifest.pp')

      expect(envconf.raw_setting(:manifest)).to eq('manifest.pp')
    end
  end

  context "without config" do
    let(:envconf) { Puppet::Settings::EnvironmentConf.new("/some/direnv", nil, ["/global/modulepath"]) }

    it "returns a default modulepath when config has none, with global_module_path" do
      expect(envconf.modulepath).to eq(
        [File.expand_path('/some/direnv/modules'),
        File.expand_path('/global/modulepath')].join(File::PATH_SEPARATOR)
      )
    end

    it "returns a default manifest when config has none" do
      expect(envconf.manifest).to eq(File.expand_path('/some/direnv/manifests'))
    end

    it "returns nothing for config_version when config has none" do
      expect(envconf.config_version).to be_nil
    end

    it "returns a default of 0 for environment_timeout when config has none" do
      expect(envconf.environment_timeout).to eq(0)
    end

    it "returns default of true for static_catalogs when config has none" do
      expect(envconf.static_catalogs).to eq(true)
    end

    it "can still retrieve raw setting" do
      expect(envconf.raw_setting(:manifest)).to be_nil
    end
  end

  describe "with disable_per_environment_manifest" do

    let(:config) { stub('config') }
    let(:envconf) { Puppet::Settings::EnvironmentConf.new("/some/direnv", config, ["/global/modulepath"]) }

    context "set true" do

      before(:each) do
        Puppet[:default_manifest] = File.expand_path('/default/manifest')
        Puppet[:disable_per_environment_manifest] = true
      end

      it "ignores environment.conf manifest" do
        setup_environment_conf(config, :manifest => '/some/manifest.pp')

        expect(envconf.manifest).to eq(File.expand_path('/default/manifest'))
      end

      it "logs error when environment.conf has manifest set" do
        setup_environment_conf(config, :manifest => '/some/manifest.pp')

        envconf.manifest
        expect(@logs.first.to_s).to match(/disable_per_environment_manifest.*true.*environment.conf.*does not match the default_manifest/)
      end

      it "does not log an error when environment.conf does not have a manifest set" do
        setup_environment_conf(config, :manifest => nil)

        expect(envconf.manifest).to eq(File.expand_path('/default/manifest'))
        expect(@logs).to be_empty
      end
    end

    it "uses environment.conf when false" do
      setup_environment_conf(config, :manifest => '/some/manifest.pp')

      Puppet[:default_manifest] = File.expand_path('/default/manifest')
      Puppet[:disable_per_environment_manifest] = false

      expect(envconf.manifest).to eq(File.expand_path('/some/manifest.pp'))
    end
  end
end
