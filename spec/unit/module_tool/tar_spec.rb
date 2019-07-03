require 'spec_helper'
require 'puppet/module_tool/tar'

describe Puppet::ModuleTool::Tar do
  # FIXME: PUP-9813 restore minitar as a prefered impl

  it "always prefers OS's tar when it's available and not on Windows" do
    allow(Facter).to receive(:value).with('osfamily').and_return('ObscureLinuxDistro')
    allow(Puppet::Util).to receive(:which).with('tar').and_return('/usr/bin/tar')
    allow(Puppet::Util::Platform).to receive(:windows?).and_return(false)

    expect(described_class.instance).to be_a_kind_of Puppet::ModuleTool::Tar::Gnu
  end

  [
    { :name => 'ObscureLinuxDistro', :win => false, :title => 'it and zlib are present' },
    { :name => 'Windows', :win => true, :title => 'on Windows' }
  ].each do |os|
    it "falls back to minitar if #{os[:title]}" do
      allow(Facter).to receive(:value).with('osfamily').and_return(os[:name])
      allow(Puppet::Util).to receive(:which).with('tar').and_return(nil)
      allow(Puppet::Util::Platform).to receive(:windows?).and_return(os[:win])
      allow(Puppet).to receive(:features).and_return(double(:minitar? => true, :zlib? => true))

      expect(described_class.instance).to be_a_kind_of Puppet::ModuleTool::Tar::Mini
    end
  end

  it "fails when there is no possible implementation" do
    allow(Facter).to receive(:value).with('osfamily').and_return('Windows')
    allow(Puppet::Util).to receive(:which).with('tar')
    allow(Puppet::Util::Platform).to receive(:windows?).and_return(true)
    allow(Puppet).to receive(:features).and_return(double(:minitar? => false, :zlib? => false))

    expect { described_class.instance }.to raise_error RuntimeError, /No suitable tar/
  end
end
