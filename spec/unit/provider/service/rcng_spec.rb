require 'spec_helper'

describe 'Puppet::Type::Service::Provider::Rcng',
         unless: Puppet::Util::Platform.windows? || Puppet::Util::Platform.jruby? do
  let(:provider_class) { Puppet::Type.type(:service).provider(:rcng) }

  before :each do
    allow(Puppet::Type.type(:service)).to receive(:defaultprovider).and_return(provider_class)
    allow(Facter).to receive(:value).with(:operatingsystem).and_return(:netbsd)
    allow(Facter).to receive(:value).with(:osfamily).and_return('NetBSD')
    allow(provider_class).to receive(:defpath).and_return('/etc/rc.d')
    @provider = provider_class.new
    allow(@provider).to receive(:initscript)
  end

  context "#enable" do
    it "should have an enable method" do
      expect(@provider).to respond_to(:enable)
    end

    it "should set the proper contents to enable" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      allow(Dir).to receive(:mkdir).with('/etc/rc.conf.d')
      fh = double('fh')
      expect(Puppet::Util).to receive(:replace_file).with('/etc/rc.conf.d/sshd', 0644).and_yield(fh)
      expect(fh).to receive(:puts).with("sshd=${sshd:=YES}\n")
      provider.enable
    end

    it "should set the proper contents to enable when disabled" do
      provider = provider_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      allow(Dir).to receive(:mkdir).with('/etc/rc.conf.d')
      allow(File).to receive(:read).with('/etc/rc.conf.d/sshd').and_return("sshd_enable=\"NO\"\n")
      fh = double('fh')
      expect(Puppet::Util).to receive(:replace_file).with('/etc/rc.conf.d/sshd', 0644).and_yield(fh)
      expect(fh).to receive(:puts).with("sshd=${sshd:=YES}\n")
      provider.enable
    end
  end
end
