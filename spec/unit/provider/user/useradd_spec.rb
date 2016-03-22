#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Type.type(:user).provider(:useradd) do

  before :each do
    described_class.stubs(:command).with(:password).returns '/usr/bin/chage'
    described_class.stubs(:command).with(:add).returns '/usr/sbin/useradd'
    described_class.stubs(:command).with(:localadd).returns '/usr/sbin/luseradd'
    described_class.stubs(:command).with(:modify).returns '/usr/sbin/usermod'
    described_class.stubs(:command).with(:delete).returns '/usr/sbin/userdel'
  end

  let(:resource) do
    Puppet::Type.type(:user).new(
      :name       => 'myuser',
      :managehome => :false,
      :system     => :false,
      :provider   => provider
    )
  end

  let(:provider) { described_class.new(:name => 'myuser') }


  let(:shadow_entry) {
    return unless Puppet.features.libshadow?
    entry = Struct::PasswdEntry.new
    entry[:sp_namp]   = 'myuser' # login name
    entry[:sp_pwdp]   = '$6$FvW8Ib8h$qQMI/CR9m.QzIicZKutLpBgCBBdrch1IX0rTnxuI32K1pD9.RXZrmeKQlaC.RzODNuoUtPPIyQDufunvLOQWF0' # encrypted password
    entry[:sp_lstchg] = 15573    # date of last password change
    entry[:sp_min]    = 10       # minimum password age
    entry[:sp_max]    = 20       # maximum password age
    entry[:sp_warn]   = 7        # password warning period
    entry[:sp_inact]  = -1       # password inactivity period
    entry[:sp_expire] = 15706    # account expiration date
    entry
  }

  describe "#create" do

    before do
      provider.stubs(:exists?).returns(false)
    end

    it "should add -g when no gid is specified and group already exists" do
      Puppet::Util.stubs(:gid).returns(true)
      resource[:ensure] = :present
      provider.expects(:execute).with(includes('-g'), kind_of(Hash))
      provider.create
    end

    it "should use -G to set groups" do
      Facter.stubs(:value).with(:osfamily).returns('Not RedHat')
      resource[:ensure] = :present
      resource[:groups] = ['group1', 'group2']
      provider.expects(:execute).with(['/usr/sbin/useradd', '-G', 'group1,group2', 'myuser'], kind_of(Hash))
      provider.create
    end

    it "should use -G to set groups without -M on RedHat" do
      Facter.stubs(:value).with(:osfamily).returns('RedHat')
      resource[:ensure] = :present
      resource[:groups] = ['group1', 'group2']
      provider.expects(:execute).with(['/usr/sbin/useradd', '-G', 'group1,group2', '-M', 'myuser'], kind_of(Hash))
      provider.create
    end

    it "should add -o when allowdupe is enabled and the user is being created" do
      resource[:allowdupe] = true
      provider.expects(:execute).with(includes('-o'), kind_of(Hash))
      provider.create
    end

    describe "on systems that support has_system", :if => described_class.system_users? do
      it "should add -r when system is enabled" do
        resource[:system] = :true
        expect(provider).to be_system_users
        provider.expects(:execute).with(includes('-r'), kind_of(Hash))
        provider.create
      end
    end

    describe "on systems that do not support has_system", :unless => described_class.system_users? do
      it "should not add -r when system is enabled" do
        resource[:system] = :true
        expect(provider).not_to be_system_users
        provider.expects(:execute).with(['/usr/sbin/useradd', 'myuser'], kind_of(Hash))
        provider.create
      end
    end

    it "should set password age rules" do
      described_class.has_feature :manages_password_age
      resource[:password_min_age] = 5
      resource[:password_max_age] = 10
      provider.expects(:execute).with(includes('/usr/sbin/useradd'), kind_of(Hash))
      provider.expects(:execute).with(['/usr/bin/chage', '-m', 5, '-M', 10, 'myuser'])
      provider.create
    end

    describe "on systems with the libuser and forcelocal=true" do
      before do
         described_class.has_feature :libuser
         resource[:forcelocal] = true
      end
      it "should use luseradd instead of useradd" do
        provider.expects(:execute).with(includes('/usr/sbin/luseradd'), has_entry(:custom_environment, has_key('LIBUSER_CONF')))
        provider.create
      end

      it "should NOT use -o when allowdupe=true" do
        resource[:allowdupe] = :true
        provider.expects(:execute).with(Not(includes('-o')), has_entry(:custom_environment, has_key('LIBUSER_CONF')))
        provider.create
      end

      it "should raise an exception for duplicate UIDs" do
        resource[:uid] = 505
        provider.stubs(:finduser).returns(true)
        expect { provider.create }.to raise_error(Puppet::Error, "UID 505 already exists, use allowdupe to force user creation")
      end

      it "should not use -G for luseradd and should call usermod with -G after luseradd when groups property is set" do
        resource[:groups] = ['group1', 'group2']
        provider.expects(:execute).with(Not(includes("-G")), has_entry(:custom_environment, has_key('LIBUSER_CONF')))
        provider.expects(:execute).with(includes('/usr/sbin/usermod'))
        provider.create
      end

      it "should not use -m when managehome set" do
        resource[:managehome] = :true
        provider.expects(:execute).with(Not(includes('-m')), has_entry(:custom_environment, has_key('LIBUSER_CONF')))
        provider.create
      end

      it "should not use -e with luseradd, should call usermod with -e after luseradd when expiry is set" do
        resource[:expiry] = '2038-01-24'
        provider.expects(:execute).with(all_of(includes('/usr/sbin/luseradd'), Not(includes('-e'))), has_entry(:custom_environment, has_key('LIBUSER_CONF')))
        provider.expects(:execute).with(all_of(includes('/usr/sbin/usermod'), includes('-e')))
        provider.create
      end

      it "should use userdel to delete users" do
        resource[:ensure] = :absent
        provider.stubs(:exists?).returns(true)
        provider.expects(:execute).with(includes('/usr/sbin/userdel'))
        provider.delete
      end
    end

    describe "on systems that allow to set shell" do
      it "should trigger shell validation" do
        resource[:shell] = '/bin/bash'
        provider.expects(:check_valid_shell)
        provider.expects(:execute).with(includes('-s'), kind_of(Hash))
        provider.create
      end
    end

  end

  describe "#uid=" do
    it "should add -o when allowdupe is enabled and the uid is being modified" do
      resource[:allowdupe] = :true
      provider.expects(:execute).with(['/usr/sbin/usermod', '-u', 150, '-o', 'myuser'])
      provider.uid = 150
    end
  end

  describe "#expiry=" do
    it "should pass expiry to usermod as MM/DD/YY when on Solaris" do
      Facter.expects(:value).with(:operatingsystem).returns 'Solaris'
      resource[:expiry] = '2012-10-31'
      provider.expects(:execute).with(['/usr/sbin/usermod', '-e', '10/31/2012', 'myuser'])
      provider.expiry = '2012-10-31'
    end

    it "should pass expiry to usermod as YYYY-MM-DD when not on Solaris" do
      Facter.expects(:value).with(:operatingsystem).returns 'not_solaris'
      resource[:expiry] = '2012-10-31'
      provider.expects(:execute).with(['/usr/sbin/usermod', '-e', '2012-10-31', 'myuser'])
      provider.expiry = '2012-10-31'
    end

    it "should use -e with an empty string when the expiry property is removed" do
      resource[:expiry] = :absent
      provider.expects(:execute).with(['/usr/sbin/usermod', '-e', '', 'myuser'])
      provider.expiry = :absent
    end
  end

  describe "#check_allow_dup" do

    it "should return an array with a flag if dup is allowed" do
      resource[:allowdupe] = :true
      expect(provider.check_allow_dup).to eq(["-o"])
    end

    it "should return an empty array if no dup is allowed" do
      resource[:allowdupe] = :false
      expect(provider.check_allow_dup).to eq([])
    end
  end

  describe "#check_system_users" do
    it "should check system users" do
      described_class.expects(:system_users?).returns true
      resource.expects(:system?)
      provider.check_system_users
    end

    it "should return an array with a flag if it's a system user" do
      described_class.expects(:system_users?).returns true
      resource[:system] = :true
      expect(provider.check_system_users).to eq(["-r"])
    end

    it "should return an empty array if it's not a system user" do
      described_class.expects(:system_users?).returns true
      resource[:system] = :false
      expect(provider.check_system_users).to eq([])
    end

    it "should return an empty array if system user is not featured" do
      described_class.expects(:system_users?).returns false
      resource[:system] = :true
      expect(provider.check_system_users).to eq([])
    end
  end

  describe "#check_manage_home" do
    it "should return an array with -m flag if home is managed" do
      resource[:managehome] = :true
      provider.expects(:execute).with(includes('-m'), kind_of(Hash))
      provider.create
    end

    it "should return an array with -r flag if home is managed" do
      resource[:managehome] = :true
      resource[:ensure] = :absent
      provider.stubs(:exists?).returns(true)
      provider.expects(:execute).with(includes('-r'))
      provider.delete
    end

    it "should use -M flag if home is not managed and on Redhat" do
      Facter.stubs(:value).with(:osfamily).returns("RedHat")
      resource[:managehome] = :false
      provider.expects(:execute).with(includes('-M'), kind_of(Hash))
      provider.create
    end

    it "should not use -M flag if home is not managed and not on Redhat" do
      Facter.stubs(:value).with(:osfamily).returns("not RedHat")
      resource[:managehome] = :false
      provider.expects(:execute).with(Not(includes('-M')), kind_of(Hash))
      provider.create
    end
  end

  describe "#addcmd" do
    before do
      resource[:allowdupe] = :true
      resource[:managehome] = :true
      resource[:system] = :true
      resource[:groups] = [ 'somegroup' ]
    end

    it "should call command with :add" do
      provider.expects(:command).with(:add)
      provider.addcmd
    end

    it "should add properties" do
      provider.expects(:add_properties).returns(['-foo_add_properties'])
      expect(provider.addcmd).to include '-foo_add_properties'
    end

    it "should check and add if dup allowed" do
      provider.expects(:check_allow_dup).returns(['-allow_dup_flag'])
      expect(provider.addcmd).to include '-allow_dup_flag'
    end

    it "should check and add if home is managed" do
      provider.expects(:check_manage_home).returns(['-manage_home_flag'])
      expect(provider.addcmd).to include '-manage_home_flag'
    end

    it "should add the resource :name" do
      expect(provider.addcmd).to include 'myuser'
    end

    describe "on systems featuring system_users", :if => described_class.system_users? do
      it "should return an array with -r if system? is true" do
        resource[:system] = :true
        expect(provider.addcmd).to include("-r")
      end

      it "should return an array without -r if system? is false" do
        resource[:system] = :false
        expect(provider.addcmd).not_to include("-r")
      end
    end

    describe "on systems not featuring system_users", :unless => described_class.system_users? do
      [:false, :true].each do |system|
        it "should return an array without -r if system? is #{system}" do
          resource[:system] = system
          expect(provider.addcmd).not_to include("-r")
        end
      end
    end

    it "should return an array with the full command and expiry as MM/DD/YY when on Solaris" do
      Facter.stubs(:value).with(:operatingsystem).returns 'Solaris'
      described_class.expects(:system_users?).returns true
      resource[:expiry] = "2012-08-18"
      expect(provider.addcmd).to eq(['/usr/sbin/useradd', '-e', '08/18/2012', '-G', 'somegroup', '-o', '-m', '-r', 'myuser'])
    end

    it "should return an array with the full command and expiry as YYYY-MM-DD when not on Solaris" do
      Facter.stubs(:value).with(:operatingsystem).returns 'not_solaris'
      described_class.expects(:system_users?).returns true
      resource[:expiry] = "2012-08-18"
      expect(provider.addcmd).to eq(['/usr/sbin/useradd', '-e', '2012-08-18', '-G', 'somegroup', '-o', '-m', '-r', 'myuser'])
    end

    it "should return an array without -e if expiry is undefined full command" do
      described_class.expects(:system_users?).returns true
      expect(provider.addcmd).to eq(["/usr/sbin/useradd", "-G", "somegroup", "-o", "-m", "-r", "myuser"])
    end

    it "should pass -e \"\" if the expiry has to be removed" do
      described_class.expects(:system_users?).returns true
      resource[:expiry] = :absent

      expect(provider.addcmd).to eq(['/usr/sbin/useradd', '-e', '', '-G', 'somegroup', '-o', '-m', '-r', 'myuser'])
    end
  end

  {
    :password_min_age => 10,
    :password_max_age => 20,
    :password         => '$6$FvW8Ib8h$qQMI/CR9m.QzIicZKutLpBgCBBdrch1IX0rTnxuI32K1pD9.RXZrmeKQlaC.RzODNuoUtPPIyQDufunvLOQWF0'
  }.each_pair do |property, expected_value|
    describe "##{property}" do
      before :each do
        resource # just to link the resource to the provider
      end

      it "should return absent if libshadow feature is not present" do
        Puppet.features.stubs(:libshadow?).returns false
        # Shadow::Passwd.expects(:getspnam).never # if we really don't have libshadow we dont have Shadow::Passwd either
        expect(provider.send(property)).to eq(:absent)
      end

      it "should return absent if user cannot be found", :if => Puppet.features.libshadow? do
        Shadow::Passwd.expects(:getspnam).with('myuser').returns nil
        expect(provider.send(property)).to eq(:absent)
      end

      it "should return the correct value if libshadow is present", :if => Puppet.features.libshadow? do
        Shadow::Passwd.expects(:getspnam).with('myuser').returns shadow_entry
        expect(provider.send(property)).to eq(expected_value)
      end
    end
  end

  describe '#expiry' do
    before :each do
      resource # just to link the resource to the provider
    end

    it "should return absent if libshadow feature is not present" do
      Puppet.features.stubs(:libshadow?).returns false
      expect(provider.expiry).to eq(:absent)
    end

    it "should return absent if user cannot be found", :if => Puppet.features.libshadow? do
      Shadow::Passwd.expects(:getspnam).with('myuser').returns nil
      expect(provider.expiry).to eq(:absent)
    end

    it "should return absent if expiry is -1", :if => Puppet.features.libshadow? do
      shadow_entry.sp_expire = -1
      Shadow::Passwd.expects(:getspnam).with('myuser').returns shadow_entry
      expect(provider.expiry).to eq(:absent)
    end

    it "should convert to YYYY-MM-DD", :if => Puppet.features.libshadow? do
      Shadow::Passwd.expects(:getspnam).with('myuser').returns shadow_entry
      expect(provider.expiry).to eq('2013-01-01')
    end
  end

  describe "#passcmd" do
    before do
      resource[:allowdupe] = :true
      resource[:managehome] = :true
      resource[:system] = :true
      described_class.has_feature :manages_password_age
    end

    it "should call command with :pass" do
      # command(:password) is only called inside passcmd if
      # password_min_age or password_max_age is set
      resource[:password_min_age] = 123
      provider.expects(:command).with(:password)
      provider.passcmd
    end

    it "should return nil if neither min nor max is set" do
      expect(provider.passcmd).to be_nil
    end

    it "should return a chage command array with -m <value> and the user name if password_min_age is set" do
      resource[:password_min_age] = 123
      expect(provider.passcmd).to eq(['/usr/bin/chage','-m',123,'myuser'])
    end

    it "should return a chage command array with -M <value> if password_max_age is set" do
      resource[:password_max_age] = 999
      expect(provider.passcmd).to eq(['/usr/bin/chage','-M',999,'myuser'])
    end

    it "should return a chage command array with -M <value> -m <value> if both password_min_age and password_max_age are set" do
      resource[:password_min_age] = 123
      resource[:password_max_age] = 999
      expect(provider.passcmd).to eq(['/usr/bin/chage','-m',123,'-M',999,'myuser'])
    end
  end

  describe "#check_valid_shell" do
    it "should raise an error if shell does not exist" do
      resource[:shell] = 'foo/bin/bash'
      expect { provider.check_valid_shell }.to raise_error(Puppet::Error, /Shell foo\/bin\/bash must exist/)
    end

    it "should raise an error if the shell is not executable" do
      resource[:shell] = 'LICENSE'
      expect { provider.check_valid_shell }.to raise_error(Puppet::Error, /Shell LICENSE must be executable/)
    end
  end

end
