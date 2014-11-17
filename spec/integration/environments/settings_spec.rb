require 'spec_helper'
require 'puppet_spec/settings'

describe "accessing environment.conf settings" do
  include PuppetSpec::Settings

  let(:confdir) { Puppet[:confdir] }
  let(:cmdline_args) { ['--confdir', confdir, '--vardir', Puppet[:vardir], '--hiera_config', Puppet[:hiera_config]] }
  let(:environmentpath) { File.expand_path("envdir", confdir) }
  let(:testingdir) { File.join(environmentpath, "testing") }

  before(:each) do
    FileUtils.mkdir_p(testingdir)
    set_puppet_conf(confdir, <<-EOF)
      environmentpath=#{environmentpath}
    EOF
    Puppet.initialize_settings
  end

  context "when given environment name" do
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

  context "when environment name collides with a puppet.conf section" do
    let(:testingdir) { File.join(environmentpath, "main") }

    it "reads manifest from environment.conf defaults" do
      expect(Puppet.settings.value(:environmentpath)).to eq(environmentpath)
      expect(Puppet.settings.value(:manifest, :main)).to eq(File.join(testingdir, "manifests"))
    end
  end
end
