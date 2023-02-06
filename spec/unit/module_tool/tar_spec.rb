require 'spec_helper'
require 'puppet/module_tool/tar'

describe Puppet::ModuleTool::Tar do
  [
    { :name => 'ObscureLinuxDistro', :win => false }, 
    { :name => 'Windows', :win => true }
  ].each do |os|
    it "always prefers minitar if it and zlib are present, even with tar available" do
      allow(Facter).to receive(:value).with('os.family').and_return(os[:name])
      allow(Puppet::Util).to receive(:which).with('tar').and_return('/usr/bin/tar')
      allow(Puppet::Util::Platform).to receive(:windows?).and_return(os[:win])
      allow(Puppet).to receive(:features).and_return(double(:minitar? => true, :zlib? => true))

      expect(described_class.instance).to be_a_kind_of Puppet::ModuleTool::Tar::Mini
    end
  end

  it "falls back to tar when minitar not present and not on Windows" do
    allow(Facter).to receive(:value).with('os.family').and_return('ObscureLinuxDistro')
    allow(Puppet::Util).to receive(:which).with('tar').and_return('/usr/bin/tar')
    allow(Puppet::Util::Platform).to receive(:windows?).and_return(false)
    allow(Puppet).to receive(:features).and_return(double(:minitar? => false))

    expect(described_class.instance).to be_a_kind_of Puppet::ModuleTool::Tar::Gnu
  end

  it "fails when there is no possible implementation" do
    allow(Facter).to receive(:value).with('os.family').and_return('Windows')
    allow(Puppet::Util).to receive(:which).with('tar')
    allow(Puppet::Util::Platform).to receive(:windows?).and_return(true)
    allow(Puppet).to receive(:features).and_return(double(:minitar? => false, :zlib? => false))

    expect { described_class.instance }.to raise_error RuntimeError, /No suitable tar/
  end
end
