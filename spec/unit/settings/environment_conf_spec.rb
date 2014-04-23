require 'spec_helper'
require 'puppet/settings/environment_conf.rb'

describe Puppet::Settings::EnvironmentConf do

  context "with config" do
    let(:config) { stub(:config) }
    let(:envconf) { Puppet::Settings::EnvironmentConf.new("/some/direnv", config, ["/global/modulepath"]) }

    it "reads a modulepath from config and does not include global_module_path" do
      config.expects(:setting).with(:modulepath).returns(
        mock('setting', :value => '/some/modulepath')
      )
      expect(envconf.modulepath).to eq(File.expand_path('/some/modulepath'))
    end

    it "reads a manifest from config" do
      config.expects(:setting).with(:manifest).returns(
        mock('setting', :value => '/some/manifest')
      )
      expect(envconf.manifest).to eq(File.expand_path('/some/manifest'))
    end

    it "reads a config_version from config" do
      config.expects(:setting).with(:config_version).returns(
        mock('setting', :value => '/some/version.sh')
      )
      expect(envconf.config_version).to eq(File.expand_path('/some/version.sh'))
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
  end
end
