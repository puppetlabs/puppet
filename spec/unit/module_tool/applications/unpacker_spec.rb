require 'spec_helper'
require 'puppet/module_tool/applications'
require 'puppet_spec/modules'

describe Puppet::ModuleTool::Applications::Unpacker, :fails_on_windows => true do
  include PuppetSpec::Files

  let(:target) { tmpdir("unpacker") }

  context "initialization" do
    it "should support filename and basic options" do
      Puppet::ModuleTool::Applications::Unpacker.new("myusername-mytarball-1.0.0.tar.gz", :target_dir => target)
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
      Puppet::ModuleTool::Applications::Unpacker.new(filename, :target_dir => target)
    end

    before :each do
      # Mock redhat for most test cases
      Facter.stubs(:value).with("operatingsystem").returns("Redhat")

      build_dir.stubs(:mkpath => nil, :rmtree => nil, :children => [])

      unpacker.stubs(:build_dir).at_least_once.returns(build_dir)
      unpacker.stubs(:system).returns(true)

      FileUtils.stubs(:mv)
    end

    it "run should execute when fully mocked" do
      unpacker.run
    end

    context "on linux" do
      it "should attempt to untar file to temporary location using system tar" do
        unpacker.expects(:system).with("tar xzf #{filename} -C #{build_dir}").returns(true)
        unpacker.run
      end
    end

    context "on solaris" do
      before :each do
        Facter.expects(:value).with("operatingsystem").returns("Solaris")
        File.stubs(:exists?).with("/usr/sfw/bin/gtar").returns(true)
      end

      it "should attempt to untar file to temporary location using gnu tar" do
        unpacker.expects(:system).with("/usr/sfw/bin/gtar xzf #{filename} -C #{build_dir}").returns(true)
        unpacker.run
      end

      it "should raise an exception if gtar is missing" do
        File.expects(:exists?).with("/usr/sfw/bin/gtar").returns(false)
        expect { unpacker.run }.to raise_error RuntimeError, 'Missing executable /usr/sfw/bin/gtar (provided by package SUNWgtar). Unable to extract file.'
      end
    end
  end

end
