require 'spec_helper'
require 'puppet/module_tool/tar'

describe Puppet::ModuleTool::Tar do

  it "uses gtar when present on Solaris" do
    Facter.stubs(:value).with('osfamily').returns 'Solaris'
    Puppet::Util.stubs(:which).with('gtar').returns '/usr/bin/gtar'

    described_class.instance(nil).should be_a_kind_of Puppet::ModuleTool::Tar::Solaris
  end

  it "uses gtar when present on OpenBSD" do
    Facter.stubs(:value).with('osfamily').returns 'OpenBSD'
    Puppet::Util.stubs(:which).with('gtar').returns '/usr/bin/gtar'

    described_class.instance(nil).should be_a_kind_of Puppet::ModuleTool::Tar::Solaris
  end

  it "uses tar when present and not on Windows" do
    Facter.stubs(:value).with('osfamily').returns 'ObscureLinuxDistro'
    Puppet::Util.stubs(:which).with('tar').returns '/usr/bin/tar'
    Puppet::Util::Platform.stubs(:windows?).returns false

    described_class.instance(nil).should be_a_kind_of Puppet::ModuleTool::Tar::Gnu
  end

  it "falls back to minitar when it and zlib are present" do
    Facter.stubs(:value).with('osfamily').returns 'Windows'
    Puppet::Util.stubs(:which).with('tar')
    Puppet::Util::Platform.stubs(:windows?).returns true
    Puppet.stubs(:features).returns(stub(:minitar? => true, :zlib? => true))

    described_class.instance(nil).should be_a_kind_of Puppet::ModuleTool::Tar::Mini
  end

  it "fails when there is no possible implementation" do
    Facter.stubs(:value).with('osfamily').returns 'Windows'
    Puppet::Util.stubs(:which).with('tar')
    Puppet::Util::Platform.stubs(:windows?).returns true
    Puppet.stubs(:features).returns(stub(:minitar? => false, :zlib? => false))

    expect { described_class.instance(nil) }.to raise_error RuntimeError, /No suitable tar/
  end
end
