require 'spec_helper'
require 'puppet/module_tool/tar'

describe Puppet::ModuleTool::Tar do

  it "uses tar when present and not on Windows" do
    Facter.stubs(:value).with('osfamily').returns 'ObscureLinuxDistro'
    Puppet::Util.stubs(:which).with('tar').returns '/usr/bin/tar'
    Puppet::Util::Platform.stubs(:windows?).returns false

    expect(described_class.instance).to be_a_kind_of Puppet::ModuleTool::Tar::Gnu
  end

  it "falls back to minitar when it and zlib are present" do
    Facter.stubs(:value).with('osfamily').returns 'Windows'
    Puppet::Util.stubs(:which).with('tar')
    Puppet::Util::Platform.stubs(:windows?).returns true
    Puppet.stubs(:features).returns(stub(:minitar? => true, :zlib? => true))

    expect(described_class.instance).to be_a_kind_of Puppet::ModuleTool::Tar::Mini
  end

  it "fails when there is no possible implementation" do
    Facter.stubs(:value).with('osfamily').returns 'Windows'
    Puppet::Util.stubs(:which).with('tar')
    Puppet::Util::Platform.stubs(:windows?).returns true
    Puppet.stubs(:features).returns(stub(:minitar? => false, :zlib? => false))

    expect { described_class.instance }.to raise_error RuntimeError, /No suitable tar/
  end
end
