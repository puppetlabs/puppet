require 'spec_helper'

describe 'Puppet::Type::Service::Provider::Freebsd',
         unless: Puppet::Util::Platform.windows? || Puppet::Util::Platform.jruby? do
  let(:provider_class) { Puppet::Type.type(:service).provider(:freebsd) }

  before :each do
    @provider = provider_class.new
    allow(@provider).to receive(:initscript)
    allow(Facter).to receive(:value).with('os.family').and_return('FreeBSD')
  end

  it "should correctly parse rcvar for FreeBSD < 7" do
    allow(@provider).to receive(:execute).and_return(<<OUTPUT)
# ntpd
$ntpd_enable=YES
OUTPUT
    expect(@provider.rcvar).to eq(['# ntpd', 'ntpd_enable=YES'])
  end

  it "should correctly parse rcvar for FreeBSD 7 to 8" do
    allow(@provider).to receive(:execute).and_return(<<OUTPUT)
# ntpd
ntpd_enable=YES
OUTPUT
    expect(@provider.rcvar).to eq(['# ntpd', 'ntpd_enable=YES'])
  end

  it "should correctly parse rcvar for FreeBSD >= 8.1" do
    allow(@provider).to receive(:execute).and_return(<<OUTPUT)
# ntpd
#
ntpd_enable="YES"
#   (default: "")
OUTPUT
    expect(@provider.rcvar).to eq(['# ntpd', 'ntpd_enable="YES"', '#   (default: "")'])
  end

  it "should correctly parse rcvar for DragonFly BSD" do
    allow(@provider).to receive(:execute).and_return(<<OUTPUT)
# ntpd
$ntpd=YES
OUTPUT
    expect(@provider.rcvar).to eq(['# ntpd', 'ntpd=YES'])
  end

  it 'should parse service names with a description' do
    allow(@provider).to receive(:execute).and_return(<<OUTPUT)
# local_unbound : local caching forwarding resolver
local_unbound_enable="YES"
OUTPUT
    expect(@provider.service_name).to eq('local_unbound')
  end

  it 'should parse service names without a description' do
    allow(@provider).to receive(:execute).and_return(<<OUTPUT)
# local_unbound
local_unbound="YES"
OUTPUT
    expect(@provider.service_name).to eq('local_unbound')
  end

  it "should find the right rcvar_value for FreeBSD < 7" do
    allow(@provider).to receive(:rcvar).and_return(['# ntpd', 'ntpd_enable=YES'])

    expect(@provider.rcvar_value).to eq("YES")
  end

  it "should find the right rcvar_value for FreeBSD >= 7" do
    allow(@provider).to receive(:rcvar).and_return(['# ntpd', 'ntpd_enable="YES"', '#   (default: "")'])

    expect(@provider.rcvar_value).to eq("YES")
  end

  it "should find the right rcvar_name" do
    allow(@provider).to receive(:rcvar).and_return(['# ntpd', 'ntpd_enable="YES"'])

    expect(@provider.rcvar_name).to eq("ntpd")
  end

  it "should enable only the selected service" do
    allow(Puppet::FileSystem).to receive(:exist?).with('/etc/rc.conf').and_return(true)
    allow(File).to receive(:read).with('/etc/rc.conf').and_return("openntpd_enable=\"NO\"\nntpd_enable=\"NO\"\n")
    fh = double('fh')
    allow(Puppet::FileSystem).to receive(:replace_file).with('/etc/rc.conf').and_yield(fh)
    expect(fh).to receive(:<<).with("openntpd_enable=\"NO\"\nntpd_enable=\"YES\"\n")
    allow(Puppet::FileSystem).to receive(:exist?).with('/etc/rc.conf.local').and_return(false)
    allow(Puppet::FileSystem).to receive(:exist?).with('/etc/rc.conf.d/ntpd').and_return(false)

    @provider.rc_replace('ntpd', 'ntpd', 'YES')
  end
end
