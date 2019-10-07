require 'spec_helper'

describe Puppet::Type.type(:package).provider(:aptrpm) do
  let :type do Puppet::Type.type(:package) end
  let :pkg do
    type.new(:name => 'faff', :provider => :aptrpm, :source => '/tmp/faff.rpm')
  end

  it { is_expected.to be_versionable }

  context "when retrieving ensure" do
    before(:each) do
      allow(Puppet::Util).to receive(:which).with("rpm").and_return("/bin/rpm")
      allow(pkg.provider).to receive(:which).with("rpm").and_return("/bin/rpm")
      expect(Puppet::Util::Execution).to receive(:execute).with(["/bin/rpm", "--version"], {:combine => true, :custom_environment => {}, :failonfail => true}).and_return(Puppet::Util::Execution::ProcessOutput.new("4.10.1\n", 0)).at_most(:once)
    end

    def rpm_args
      ['-q', 'faff', '--nosignature', '--nodigest', '--qf', "%{NAME} %|EPOCH?{%{EPOCH}}:{0}| %{VERSION} %{RELEASE} %{ARCH}\\n"]
    end

    it "should report purged packages" do
      expect(pkg.provider).to receive(:rpm).and_raise(Puppet::ExecutionFailure, "couldn't find rpm")
      expect(pkg.property(:ensure).retrieve).to eq(:purged)
    end

    it "should report present packages correctly" do
      expect(pkg.provider).to receive(:rpm).and_return("faff-1.2.3-1 0 1.2.3-1 5 i686\n")
      expect(pkg.property(:ensure).retrieve).to eq("1.2.3-1-5")
    end
  end

  it "should try and install when asked" do
    expect(pkg.provider).to receive(:aptget).with('-q', '-y', 'install', 'faff').and_return(0)
    pkg.provider.install
  end

  it "should try and purge when asked" do
    expect(pkg.provider).to receive(:aptget).with('-y', '-q', 'remove', '--purge', 'faff').and_return(0)
    pkg.provider.purge
  end
end
