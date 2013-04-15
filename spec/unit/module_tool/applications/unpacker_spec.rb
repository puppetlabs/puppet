require 'spec_helper'
require 'puppet/module_tool/applications'
require 'puppet_spec/modules'

describe Puppet::ModuleTool::Applications::Unpacker do
  include PuppetSpec::Files

  let(:target)      { tmpdir("unpacker") }
  let(:module_name) { 'myusername-mytarball' }
  let(:filename)    { tmpdir("module") + "/#{module_name}-1.0.0.tar.gz" }
  let(:working_dir) { tmpdir("working_dir") }
  let(:unpacker) do
    Puppet::ModuleTool::Applications::Unpacker.new(filename, :target_dir => target)
  end

  before :each do
    Puppet.settings[:module_working_dir] = working_dir
  end

  it "should raise ArgumentError when filename is invalid" do
    expect { Puppet::ModuleTool::Applications::Unpacker.new("invalid.tar.gz", :target_dir => target) }.to raise_error(ArgumentError)
  end

  it "should attempt to untar file to temporary location" do
    untarrer = mock('untarrer')
    Puppet::ModuleTool::Tar.expects(:instance).with(module_name).returns(untarrer)
    untarrer.expects(:unpack).with(filename, regexp_matches(/^#{Regexp.escape(working_dir)}/)) do |src, dest|
      FileUtils.mkdir(File.join(dest, 'extractedmodule'))
    end

    unpacker.run
    File.should be_directory(File.join(target, 'mytarball'))
  end
end
