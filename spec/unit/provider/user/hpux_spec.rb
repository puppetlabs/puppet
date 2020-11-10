require 'spec_helper'
require 'etc'

describe Puppet::Type.type(:user).provider(:hpuxuseradd),
         unless: Puppet::Util::Platform.windows? do
  let :resource do
    Puppet::Type.type(:user).new(
      :title => 'testuser',
      :comment => 'Test J. User',
      :provider => :hpuxuseradd
    )
  end
  let(:provider) { resource.provider }

  it "should add -F when modifying a user" do
    allow(resource).to receive(:allowdupe?).and_return(true)
    allow(provider).to receive(:trusted).and_return(true)
    expect(provider).to receive(:execute).with(include("-F"), anything)
    provider.uid = 1000
  end

  it "should add -F when deleting a user" do
    allow(provider).to receive(:exists?).and_return(true)
    expect(provider).to receive(:execute).with(include("-F"), anything)
    provider.delete
  end

  context "managing passwords" do
    let :pwent do
      Struct::Passwd.new("testuser", "foopassword")
    end

    before :each do
      allow(Etc).to receive(:getpwent).and_return(pwent)
      allow(Etc).to receive(:getpwnam).and_return(pwent)
      allow(provider).to receive(:command).with(:modify).and_return('/usr/sam/lbin/usermod.sam')
    end

    it "should have feature manages_passwords" do
      expect(described_class).to be_manages_passwords
    end

    it "should return nil if user does not exist" do
      allow(Etc).to receive(:getpwent).and_return(nil)
      expect(provider.password).to be_nil
    end

    it "should return password entry if exists" do
      expect(provider.password).to eq("foopassword")
    end
  end

  context "check for trusted computing" do
    before :each do
      allow(provider).to receive(:command).with(:modify).and_return('/usr/sam/lbin/usermod.sam')
    end

    it "should add modprpw to modifycmd if Trusted System" do
      allow(resource).to receive(:allowdupe?).and_return(true)
      expect(provider).to receive(:exec_getprpw).with('root','-m uid').and_return('uid=0')
      expect(provider).to receive(:execute).with(['/usr/sam/lbin/usermod.sam', '-F', '-u', 1000, '-o', 'testuser', ';', '/usr/lbin/modprpw', '-v', '-l', 'testuser'], hash_including(custom_environment: {}))
      provider.uid = 1000
    end

    it "should not add modprpw if not Trusted System" do
      allow(resource).to receive(:allowdupe?).and_return(true)
      expect(provider).to receive(:exec_getprpw).with('root','-m uid').and_return('System is not trusted')
      expect(provider).to receive(:execute).with(['/usr/sam/lbin/usermod.sam', '-F', '-u', 1000, '-o', 'testuser'], hash_including(custom_environment: {}))
      provider.uid = 1000
    end
  end
end
