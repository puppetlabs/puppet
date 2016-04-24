require 'spec_helper'
require 'puppet/module_tool'
require 'puppet_spec/files'

describe Puppet::ModuleTool::Tar::Mini, :if => (Puppet.features.minitar? && Puppet.features.zlib?) do
  let(:minitar)    { described_class.new }

  describe "Extracts tars with long and short pathnames" do
    let (:sourcetar) { File.expand_path('../../../../fixtures/module.tar.gz', __FILE__) }

    let (:longfilepath)  { "puppetlabs-dsc-1.0.0/lib/puppet_x/dsc_resources/xWebAdministration/DSCResources/MSFT_xWebAppPoolDefaults/MSFT_xWebAppPoolDefaults.schema.mof" }
    let (:shortfilepath) { "puppetlabs-dsc-1.0.0/README.md" }

    it "unpacks a tar with a short path length" do
      extractdir = PuppetSpec::Files.tmpdir('minitar')

      minitar.unpack(sourcetar,extractdir,'module')
      expect(File).to exist(File.expand_path("#{extractdir}/#{shortfilepath}"))
    end

    it "unpacks a tar with a long path length" do
      extractdir = PuppetSpec::Files.tmpdir('minitar')

      minitar.unpack(sourcetar,extractdir,'module')
      expect(File).to exist(File.expand_path("#{extractdir}/#{longfilepath}"))
    end
  end
end