require 'spec_helper'

describe "setting hooks" do
  let(:confdir) { Puppet[:confdir] }
  let(:environmentpath) { File.expand_path("envdir", confdir) }

  describe "reproducing PUP-3500" do
    let(:productiondir) { File.join(environmentpath, "production") }

    before(:each) do
      FileUtils.mkdir_p(productiondir)
    end

    it "accesses correct directory environment settings after initializing a setting with an on_write hook" do
      expect(Puppet.settings.setting(:certname).call_hook).to eq(:on_write_only) 

      File.open(File.join(confdir, "puppet.conf"), "w") do |f|
        f.puts("environmentpath=#{environmentpath}")
        f.puts("certname=something")
      end

      Puppet.initialize_settings
      production_env = Puppet.lookup(:environments).get(:production)
      expect(Puppet.settings.value(:manifest, production_env)).to eq("#{productiondir}/manifests")
    end
  end
end
