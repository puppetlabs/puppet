require 'spec_helper'
require 'puppet/module_tool/applications'
require 'puppet_spec/modules'

describe Puppet::ModuleTool::Applications::Unpacker do
  include PuppetSpec::Files

  let(:target) { tmpdir("unpacker") }

  context "initialization" do
    it "should support filename and basic options" do
      pending("porting to Windows", :if => Puppet.features.microsoft_windows?) do
        Puppet::ModuleTool::Applications::Unpacker.new("myusername-mytarball-1.0.0.tar.gz", :target_dir => target)
      end
    end

    it "should raise ArgumentError when filename is invalid" do
      expect { Puppet::ModuleTool::Applications::Unpacker.new("invalid.tar.gz", :target_dir => target) }.to raise_error(ArgumentError)
    end
  end

  context "#run" do
    let(:cache_base_path) { Pathname.new(tmpdir("unpacker")) }
    let(:filename) { tmpdir("module") + "/myusername-mytarball-1.0.0.tar.gz" }
    let(:build_dir) { Pathname.new(tmpdir("build_dir")) }
    let(:unpacker) do
      pending("porting to Windows", :if => Puppet.features.microsoft_windows?) do
        Puppet::ModuleTool::Applications::Unpacker.new(filename, :target_dir => target)
      end
    end

    before :each do
      build_dir.stubs(:mkpath => nil, :rmtree => nil, :children => [])
      unpacker.stubs(:build_dir).at_least_once.returns(build_dir)
      FileUtils.stubs(:mv)
    end

    it "should attempt to open the file with Zlib::GzipReader and process the yielded stream with Puppet::Util::Archive::Tar::Minitar::Reader" do
      pending("porting to Windows", :if => Puppet.features.microsoft_windows?) do
        tar = mock('Puppet::Util::Archive::Tar::Minitar::Reader')
        tar.expects(:each)
        gzip = mock('Zlib::GzipReader')
        Puppet::Util::Archive::Tar::Minitar::Reader.expects(:open).with(gzip).yields(tar)
        Zlib::GzipReader.expects(:open).with(Pathname.new(filename)).yields(gzip)
        unpacker.run
      end
    end
  end

end
