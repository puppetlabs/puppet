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
      # Mock redhat for most test cases
      Facter.stubs(:value).with("osfamily").returns("Redhat")
      build_dir.stubs(:mkpath => nil, :rmtree => nil, :children => [])
      unpacker.stubs(:build_dir).at_least_once.returns(build_dir)
      FileUtils.stubs(:mv)
    end

    context "on linux" do
      it "should attempt to untar file to temporary location using system tar" do
        pending("porting to Windows", :if => Puppet.features.microsoft_windows?) do
          Puppet::Util::Execution.expects(:execute).with("tar xzf #{filename} -C #{build_dir}").returns(true)
          unpacker.run
        end
      end
    end

    context "on solaris" do
      before :each do
        Facter.expects(:value).with("osfamily").returns("Solaris")
      end

      it "should attempt to untar file to temporary location using gnu tar" do
        Puppet::Util.stubs(:which).with('gtar').returns('/usr/sfw/bin/gtar')
        Puppet::Util::Execution.expects(:execute).with("gtar xzf #{filename} -C #{build_dir}").returns(true)
        unpacker.run
      end

      it "should throw exception if gtar is not in the path exists" do
        Puppet::Util.stubs(:which).with('gtar').returns(nil)
        expect { unpacker.run }.to raise_error RuntimeError, "Cannot find the command 'gtar'. Make sure GNU tar is installed, and is in your PATH."
      end
    end
  end

end
