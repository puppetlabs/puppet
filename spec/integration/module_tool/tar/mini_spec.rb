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

  describe 'Extraction performance' do
    require 'benchmark'

    let(:tempdir_control) { Pathname.new(PuppetSpec::Files.tmpdir('minitar-control-perf')) }
    let(:tempdir_measure) { Pathname.new(PuppetSpec::Files.tmpdir('minitar-measure-perf')) }
    let(:stdlib) { 'stdlib.tgz' }
    let(:sourcetar) { File.expand_path("../../../../fixtures/#{stdlib}", __FILE__) }

    it 'should be at most 2x slower then "tar xzvf" command', :onlyif =>
      Puppet::Util.which('tar') && !Puppet::Util::Platform.windows? do

      # FIXME: PUP-9813 test is not passing, Puppet::ModuleTool::Tar::Mini needs to be faster
      skip 'PUP-9813 test is not passing, Puppet::ModuleTool::Tar::Mini needs to be faster'
      control = Benchmark.measure do
        command = "tar xzvf #{sourcetar} > /dev/null"
        Dir.chdir tempdir_control do
          system(command)
        end
      end
      measure = Benchmark.measure do
        minitar.unpack(sourcetar, tempdir_measure.to_s, 'module')
      end
      expect(measure.real).to be < (control.real * 2)
    end
  end
end
