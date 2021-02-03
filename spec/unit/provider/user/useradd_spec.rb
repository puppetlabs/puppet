require 'spec_helper'

RSpec::Matchers.define_negated_matcher :excluding, :include

describe Puppet::Type.type(:user).provider(:useradd) do
  before :each do
    allow(Puppet::Util::POSIX).to receive(:groups_of).and_return([])
    allow(described_class).to receive(:command).with(:password).and_return('/usr/bin/chage')
    allow(described_class).to receive(:command).with(:localpassword).and_return('/usr/sbin/lchage')
    allow(described_class).to receive(:command).with(:add).and_return('/usr/sbin/useradd')
    allow(described_class).to receive(:command).with(:localadd).and_return('/usr/sbin/luseradd')
    allow(described_class).to receive(:command).with(:modify).and_return('/usr/sbin/usermod')
    allow(described_class).to receive(:command).with(:localmodify).and_return('/usr/sbin/lusermod')
    allow(described_class).to receive(:command).with(:delete).and_return('/usr/sbin/userdel')
    allow(described_class).to receive(:command).with(:localdelete).and_return('/usr/sbin/luserdel')
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
      allow(provider).to receive(:exists?).and_return(false)
    end

    it "should not redact the command from debug logs if there is no password" do
      described_class.has_feature :manages_passwords
      resource[:ensure] = :present
      expect(provider).to receive(:execute).with(kind_of(Array), hash_including(sensitive: false))
      provider.create
    end

    it "should redact the command from debug logs if there is a password" do
      described_class.has_feature :manages_passwords
      resource2 = Puppet::Type.type(:user).new(
        :name       => 'myuser',
        :password   => 'a pass word',
        :managehome => :false,
        :system     => :false,
        :provider   => provider,
      )
      resource2[:ensure] = :present
      expect(provider).to receive(:execute).with(kind_of(Array), hash_including(sensitive: true))
      provider.create
    end

    it "should add -g when no gid is specified and group already exists" do
      allow(Puppet::Util).to receive(:gid).and_return(true)
      resource[:ensure] = :present
      expect(provider).to receive(:execute).with(include('-g'), kind_of(Hash))
      provider.create
    end

    context "when setting groups" do
      it "uses -G to set groups" do
        allow(Facter).to receive(:value).with(:osfamily).and_return('Solaris')
        allow(Facter).to receive(:value).with(:operatingsystemmajrelease)
        resource[:ensure] = :present
        resource[:groups] = ['group1', 'group2']
        expect(provider).to receive(:execute).with(['/usr/sbin/useradd', '-G', 'group1,group2', 'myuser'], kind_of(Hash))
        provider.create
      end

      it "uses -G to set groups with -M on supported systems" do
        allow(Facter).to receive(:value).with(:osfamily).and_return('RedHat')
        allow(Facter).to receive(:value).with(:operatingsystemmajrelease)
        resource[:ensure] = :present
        resource[:groups] = ['group1', 'group2']
        expect(provider).to receive(:execute).with(['/usr/sbin/useradd', '-G', 'group1,group2', '-M', 'myuser'], kind_of(Hash))
        provider.create
      end
    end

    it "should add -o when allowdupe is enabled and the user is being created" do
      resource[:allowdupe] = true
      expect(provider).to receive(:execute).with(include('-o'), kind_of(Hash))
      provider.create
    end

    describe "on systems that support has_system", :if => described_class.system_users? do
      it "should add -r when system is enabled" do
        resource[:system] = :true
        expect(provider).to be_system_users
        expect(provider).to receive(:execute).with(include('-r'), kind_of(Hash))
        provider.create
      end
    end

    describe "on systems that do not support has_system", :unless => described_class.system_users? do
      it "should not add -r when system is enabled" do
        resource[:system] = :true
        expect(provider).not_to be_system_users
        expect(provider).to receive(:execute).with(['/usr/sbin/useradd', 'myuser'], kind_of(Hash))
        provider.create
      end
    end

    it "should set password age rules" do
      described_class.has_feature :manages_password_age
      resource[:password_min_age] = 5
      resource[:password_max_age] = 10
      resource[:password_warn_days] = 15
      expect(provider).to receive(:execute).with(include('/usr/sbin/useradd'), kind_of(Hash))
      expect(provider).to receive(:execute).with(['/usr/bin/chage', '-m', 5, '-M', 10, '-W', 15, 'myuser'], hash_including(failonfail: true, combine: true, custom_environment: {}))
      provider.create
    end

    describe "on systems with the libuser and forcelocal=true" do
      before do
         described_class.has_feature :manages_local_users_and_groups
         resource[:forcelocal] = true
      end

      it "should use luseradd instead of useradd" do
        expect(provider).to receive(:execute).with(include('/usr/sbin/luseradd'), hash_including(custom_environment: hash_including('LIBUSER_CONF')))
        provider.create
      end

      it "should NOT use -o when allowdupe=true" do
        resource[:allowdupe] = :true
        expect(provider).to receive(:execute).with(excluding('-o'), hash_including(custom_environment: hash_including('LIBUSER_CONF')))
        provider.create
      end

      it "should raise an exception for duplicate UIDs" do
        resource[:uid] = 505
        allow(provider).to receive(:finduser).and_return(true)
        expect { provider.create }.to raise_error(Puppet::Error, "UID 505 already exists, use allowdupe to force user creation")
      end

      it "should not use -G for luseradd and should call usermod with -G after luseradd when groups property is set" do
        resource[:groups] = ['group1', 'group2']
        allow(provider).to receive(:localgroups)
        expect(provider).to receive(:execute).with(include('/usr/sbin/luseradd').and(excluding('-G')), hash_including(custom_environment: hash_including('LIBUSER_CONF')))
        expect(provider).to receive(:execute).with(include('/usr/sbin/usermod').and(include('-G')), hash_including(custom_environment: hash_including('LIBUSER_CONF')))
        provider.create
      end

      it "should not use -m when managehome set" do
        resource[:managehome] = :true
        expect(provider).to receive(:execute).with(excluding('-m'), hash_including(custom_environment: hash_including('LIBUSER_CONF')))
        provider.create
      end

      it "should not use -e with luseradd, should call usermod with -e after luseradd when expiry is set" do
        resource[:expiry] = '2038-01-24'
        expect(provider).to receive(:execute).with(include('/usr/sbin/luseradd').and(excluding('-e')), hash_including(custom_environment: hash_including('LIBUSER_CONF')))
        expect(provider).to receive(:execute).with(include('/usr/sbin/usermod').and(include('-e')), hash_including(custom_environment: hash_including('LIBUSER_CONF')))
        provider.create
      end

      it 'should set password age rules locally' do
        described_class.has_feature :manages_password_age
        resource[:password_min_age] = 5
        resource[:password_max_age] = 10
        resource[:password_warn_days] = 15
        expect(provider).to receive(:execute).with(include('/usr/sbin/luseradd'), hash_including(custom_environment: hash_including('LIBUSER_CONF')))
        expect(provider).to receive(:execute).with(['/usr/sbin/lchage', '-m', 5, '-M', 10, '-W', 15, 'myuser'], hash_including(custom_environment: hash_including('LIBUSER_CONF')))
        provider.create
      end
    end

    describe "on systems that allow to set shell" do
      it "should trigger shell validation" do
        resource[:shell] = '/bin/bash'
        expect(provider).to receive(:check_valid_shell)
        expect(provider).to receive(:execute).with(include('-s'), kind_of(Hash))
        provider.create
      end
    end
  end

  describe 'when modifying the password' do
    before do
      described_class.has_feature :manages_local_users_and_groups
      described_class.has_feature :manages_passwords
      #Setting any resource value here initializes needed variables and methods in the resource and provider
      #Setting a password value here initializes the existence and management of the password parameter itself
      #Otherwise, this value would not need to be initialized for the test
      resource[:password] = ''
    end

    it "should not call execute with sensitive if non-sensitive data is changed" do
      expect(provider).to receive(:execute).with(kind_of(Array), hash_including(sensitive: false))
      provider.home = 'foo/bar'
    end

    it "should call execute with sensitive if sensitive data is changed" do
      expect(provider).to receive(:execute).with(kind_of(Array), hash_including(sensitive: true))
      provider.password = 'bird bird bird'
    end
  end

  describe '#modify' do
    describe "on systems with the libuser and forcelocal=false" do
      before do
         described_class.has_feature :manages_local_users_and_groups
         resource[:forcelocal] = false
      end

      it "should use usermod" do
        expect(provider).to receive(:execute).with(['/usr/sbin/usermod', '-u', 150, 'myuser'], hash_including(failonfail: true, combine: true, custom_environment: {}))
        provider.uid = 150
      end

      it "should use -o when allowdupe=true" do
        resource[:allowdupe] = :true
        expect(provider).to receive(:execute).with(include('-o'), hash_including(failonfail: true, combine: true, custom_environment: {}))
        provider.uid = 505
      end

      it 'should use chage for password_min_age' do
        expect(provider).to receive(:execute).with(['/usr/bin/chage', '-m', 100, 'myuser'], hash_including(failonfail: true, combine: true, custom_environment: {}))
        provider.password_min_age = 100
      end

      it 'should use chage for password_max_age' do
        expect(provider).to receive(:execute).with(['/usr/bin/chage', '-M', 101, 'myuser'], hash_including(failonfail: true, combine: true, custom_environment: {}))
        provider.password_max_age = 101
      end

      it 'should use chage for password_warn_days' do
        expect(provider).to receive(:execute).with(['/usr/bin/chage', '-W', 99, 'myuser'], hash_including(failonfail: true, combine: true, custom_environment: {}))
        provider.password_warn_days = 99
      end

      it 'should not call check_allow_dup if not modifying the uid' do
        expect(provider).not_to receive(:check_allow_dup)
        expect(provider).to receive(:execute)
        provider.home = 'foo/bar'
      end
    end

    describe "on systems with the libuser and forcelocal=true" do
      before do
         described_class.has_feature :libuser
         resource[:forcelocal] = true
      end

      it "should use lusermod and not usermod" do
        expect(provider).to receive(:execute).with(['/usr/sbin/lusermod', '-u', 150, 'myuser'], hash_including(custom_environment: hash_including('LIBUSER_CONF')))
        provider.uid = 150
      end

      it "should NOT use -o when allowdupe=true" do
        resource[:allowdupe] = :true
        expect(provider).to receive(:execute).with(excluding('-o'), hash_including(custom_environment: hash_including('LIBUSER_CONF')))
        provider.uid = 505
      end

      it "should raise an exception for duplicate UIDs" do
        resource[:uid] = 505
        allow(provider).to receive(:finduser).and_return(true)
        expect { provider.uid = 505 }.to raise_error(Puppet::Error, "UID 505 already exists, use allowdupe to force user creation")
      end

      it 'should use lchage for password_warn_days' do
        expect(provider).to receive(:execute).with(['/usr/sbin/lchage', '-W', 99, 'myuser'], hash_including(custom_environment: hash_including('LIBUSER_CONF')))
        provider.password_warn_days = 99
      end

      it 'should use lchage for password_min_age' do
        expect(provider).to receive(:execute).with(['/usr/sbin/lchage', '-m', 100, 'myuser'], hash_including(custom_environment: hash_including('LIBUSER_CONF')))
        provider.password_min_age = 100
      end

      it 'should use lchage for password_max_age' do
        expect(provider).to receive(:execute).with(['/usr/sbin/lchage', '-M', 101, 'myuser'], hash_including(custom_environment: hash_including('LIBUSER_CONF')))
        provider.password_max_age = 101
      end
    end
  end

  describe "#uid=" do
    it "should add -o when allowdupe is enabled and the uid is being modified" do
      resource[:allowdupe] = :true
      expect(provider).to receive(:execute).with(['/usr/sbin/usermod', '-u', 150, '-o', 'myuser'], hash_including(custom_environment: {}))
      provider.uid = 150
    end
  end

  describe "#expiry=" do
    it "should pass expiry to usermod as MM/DD/YY when on Solaris" do
      expect(Facter).to receive(:value).with(:operatingsystem).and_return('Solaris')
      resource[:expiry] = '2012-10-31'
      expect(provider).to receive(:execute).with(['/usr/sbin/usermod', '-e', '10/31/2012', 'myuser'], hash_including(custom_environment: {}))
      provider.expiry = '2012-10-31'
    end

    it "should pass expiry to usermod as YYYY-MM-DD when not on Solaris" do
      expect(Facter).to receive(:value).with(:operatingsystem).and_return('not_solaris')
      resource[:expiry] = '2012-10-31'
      expect(provider).to receive(:execute).with(['/usr/sbin/usermod', '-e', '2012-10-31', 'myuser'], hash_including(custom_environment: {}))
      provider.expiry = '2012-10-31'
    end

    it "should use -e with an empty string when the expiry property is removed" do
      resource[:expiry] = :absent
      expect(provider).to receive(:execute).with(['/usr/sbin/usermod', '-e', '', 'myuser'], hash_including(custom_environment: {}))
      provider.expiry = :absent
    end

    it "should use -e with -1 when the expiry property is removed on SLES11" do
      allow(Facter).to receive(:value).with(:operatingsystem).and_return('SLES')
      allow(Facter).to receive(:value).with(:operatingsystemmajrelease).and_return('11')
      resource[:expiry] = :absent
      expect(provider).to receive(:execute).with(['/usr/sbin/usermod', '-e', -1, 'myuser'], hash_including(custom_environment: {}))
      provider.expiry = :absent
    end
  end

  describe "#comment" do
    before { described_class.has_feature :manages_local_users_and_groups }

    let(:content) { "myuser:x:x:x:local comment:x:x" }

    it "should return the local comment string when forcelocal is true" do
      resource[:forcelocal] = true
      allow(Puppet::FileSystem).to receive(:exist?).with('/etc/passwd').and_return(true)
      allow(Puppet::FileSystem).to receive(:each_line).with('/etc/passwd').and_yield(content)
      expect(provider.comment).to eq('local comment')
    end

    it "should fall back to nameservice comment string when forcelocal is false" do
      resource[:forcelocal] = false
      allow(provider).to receive(:get).with(:comment).and_return('remote comment')
      expect(provider).not_to receive(:localcomment)
      expect(provider.comment).to eq('remote comment')
    end
  end

  describe "#gid" do
    before { described_class.has_feature :manages_local_users_and_groups }

    let(:content) { "myuser:x:x:999:x:x:x" }

    it "should return the local GID when forcelocal is true" do
      resource[:forcelocal] = true
      allow(Puppet::FileSystem).to receive(:exist?).with('/etc/passwd').and_return(true)
      allow(Puppet::FileSystem).to receive(:each_line).with('/etc/passwd').and_yield(content)
      expect(provider.gid).to eq('999')
    end

    it "should fall back to nameservice GID when forcelocal is false" do
      resource[:forcelocal] = false
      allow(provider).to receive(:get).with(:gid).and_return('1234')
      expect(provider).not_to receive(:localgid)
      expect(provider.gid).to eq('1234')
    end
  end

  describe "#groups" do
    before { described_class.has_feature :manages_local_users_and_groups }

    let(:content) do
      <<~EOF
      group1:x:0:myuser
      group2:x:999:
      group3:x:998:myuser
      EOF
    end

    it "should return the local groups string when forcelocal is true" do
      resource[:forcelocal] = true
      group1, group2, group3 = content.split
      allow(Puppet::FileSystem).to receive(:exist?).with('/etc/group').and_return(true)
      allow(Puppet::FileSystem).to receive(:each_line).with('/etc/group').and_yield(group1).and_yield(group2).and_yield(group3)
      expect(provider.groups).to eq(['group1', 'group3'])
    end

    it "should fall back to nameservice groups when forcelocal is false" do
      resource[:forcelocal] = false
      allow(Puppet::Util::POSIX).to receive(:groups_of).with('myuser').and_return(['remote groups'])
      expect(provider).not_to receive(:localgroups)
      expect(provider.groups).to eq('remote groups')
    end
  end

  describe "#finduser" do
    before do
      allow(Puppet::FileSystem).to receive(:exist?).with('/etc/passwd').and_return(true)
      allow(Puppet::FileSystem).to receive(:each_line).with('/etc/passwd').and_yield(content)
    end

    let(:content) { "sample_account:sample_password:sample_uid:sample_gid:sample_gecos:sample_directory:sample_shell" }
    let(:output) do
      {
        account: 'sample_account',
        password: 'sample_password',
        uid: 'sample_uid',
        gid: 'sample_gid',
        gecos: 'sample_gecos',
        directory: 'sample_directory',
        shell: 'sample_shell',
      }
    end

    [:account, :password, :uid, :gid, :gecos, :directory, :shell].each do |key|
      it "finds an user by #{key} when asked" do
        expect(provider.finduser(key, "sample_#{key}")).to eq(output)
      end
    end

    it "returns false when specified key/value pair is not found" do
      expect(provider.finduser(:account, 'invalid_account')).to eq(false)
    end

    it "reads the user file only once per resource" do
      expect(Puppet::FileSystem).to receive(:each_line).with('/etc/passwd').once
      5.times { provider.finduser(:account, 'sample_account') }
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
      expect(described_class).to receive(:system_users?).and_return(true)
      expect(resource).to receive(:system?)
      provider.check_system_users
    end

    it "should return an array with a flag if it's a system user" do
      expect(described_class).to receive(:system_users?).and_return(true)
      resource[:system] = :true
      expect(provider.check_system_users).to eq(["-r"])
    end

    it "should return an empty array if it's not a system user" do
      expect(described_class).to receive(:system_users?).and_return(true)
      resource[:system] = :false
      expect(provider.check_system_users).to eq([])
    end

    it "should return an empty array if system user is not featured" do
      expect(described_class).to receive(:system_users?).and_return(false)
      resource[:system] = :true
      expect(provider.check_system_users).to eq([])
    end
  end

  describe "#check_manage_home" do
    it "should return an array with -m flag if home is managed" do
      resource[:managehome] = :true
      expect(provider).to receive(:execute).with(include('-m'), hash_including(custom_environment: {}))
      provider.create
    end

    it "should return an array with -r flag if home is managed" do
      resource[:managehome] = :true
      resource[:ensure] = :absent
      allow(provider).to receive(:exists?).and_return(true)
      expect(provider).to receive(:execute).with(include('-r'), hash_including(custom_environment: {}))
      provider.delete
    end

    it "should use -M flag if home is not managed on a supported system" do
      allow(Facter).to receive(:value).with(:osfamily).and_return("RedHat")
      allow(Facter).to receive(:value).with(:operatingsystemmajrelease)
      resource[:managehome] = :false
      expect(provider).to receive(:execute).with(include('-M'), kind_of(Hash))
      provider.create
    end

    it "should not use -M flag if home is not managed on an unsupported system" do
      allow(Facter).to receive(:value).with(:osfamily).and_return("Suse")
      allow(Facter).to receive(:value).with(:operatingsystemmajrelease).and_return("11")
      resource[:managehome] = :false
      expect(provider).to receive(:execute).with(excluding('-M'), kind_of(Hash))
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
      expect(provider).to receive(:command).with(:add)
      provider.addcmd
    end

    it "should add properties" do
      expect(provider).to receive(:add_properties).and_return(['-foo_add_properties'])
      expect(provider.addcmd).to include '-foo_add_properties'
    end

    it "should check and add if dup allowed" do
      expect(provider).to receive(:check_allow_dup).and_return(['-allow_dup_flag'])
      expect(provider.addcmd).to include '-allow_dup_flag'
    end

    it "should check and add if home is managed" do
      expect(provider).to receive(:check_manage_home).and_return(['-manage_home_flag'])
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
      allow(Facter).to receive(:value).with(:operatingsystem).and_return('Solaris')
      expect(described_class).to receive(:system_users?).and_return(true)
      resource[:expiry] = "2012-08-18"
      expect(provider.addcmd).to eq(['/usr/sbin/useradd', '-e', '08/18/2012', '-G', 'somegroup', '-o', '-m', '-r', 'myuser'])
    end

    it "should return an array with the full command and expiry as YYYY-MM-DD when not on Solaris" do
      allow(Facter).to receive(:value).with(:operatingsystem).and_return('not_solaris')
      expect(described_class).to receive(:system_users?).and_return(true)
      resource[:expiry] = "2012-08-18"
      expect(provider.addcmd).to eq(['/usr/sbin/useradd', '-e', '2012-08-18', '-G', 'somegroup', '-o', '-m', '-r', 'myuser'])
    end

    it "should return an array without -e if expiry is undefined full command" do
      expect(described_class).to receive(:system_users?).and_return(true)
      expect(provider.addcmd).to eq(["/usr/sbin/useradd", "-G", "somegroup", "-o", "-m", "-r", "myuser"])
    end

    it "should pass -e \"\" if the expiry has to be removed" do
      expect(described_class).to receive(:system_users?).and_return(true)
      resource[:expiry] = :absent

      expect(provider.addcmd).to eq(['/usr/sbin/useradd', '-e', '', '-G', 'somegroup', '-o', '-m', '-r', 'myuser'])
    end

    it "should use lgroupadd with forcelocal=true" do
      resource[:forcelocal] = :true
      expect(provider.addcmd[0]).to eq('/usr/sbin/luseradd')
    end

    it "should not pass -o with forcelocal=true and allowdupe=true" do
      resource[:forcelocal] = :true
      resource[:allowdupe] = :true
      expect(provider.addcmd).not_to include("-o")
    end

    context 'when forcelocal=true' do
      before do
        resource[:forcelocal] = :true
      end

      it 'does not pass lchage options to luseradd for password_max_age' do
        resource[:password_max_age] = 100
        expect(provider.addcmd).not_to include('-M')
      end

      it 'does not pass lchage options to luseradd for password_min_age' do
        resource[:managehome] = false  # This needs to be set so that we don't pass in -m to create the home
        resource[:password_min_age] = 100
        expect(provider.addcmd).not_to include('-m')
      end

      it 'does not pass lchage options to luseradd for password_warn_days' do
        resource[:password_warn_days] = 100
        expect(provider.addcmd).not_to include('-W')
      end
    end
  end

  {
    :password_min_age   => 10,
    :password_max_age   => 20,
    :password_warn_days => 30,
    :password           => '$6$FvW8Ib8h$qQMI/CR9m.QzIicZKutLpBgCBBdrch1IX0rTnxuI32K1pD9.RXZrmeKQlaC.RzODNuoUtPPIyQDufunvLOQWF0'
  }.each_pair do |property, expected_value|
    describe "##{property}" do
      before :each do
        resource # just to link the resource to the provider
      end

      it "should return absent if libshadow feature is not present" do
        allow(Puppet.features).to receive(:libshadow?).and_return(false)
        # Shadow::Passwd.expects(:getspnam).never # if we really don't have libshadow we dont have Shadow::Passwd either
        expect(provider.send(property)).to eq(:absent)
      end

      it "should return absent if user cannot be found", :if => Puppet.features.libshadow? do
        expect(Shadow::Passwd).to receive(:getspnam).with('myuser').and_return(nil)
        expect(provider.send(property)).to eq(:absent)
      end

      it "should return the correct value if libshadow is present", :if => Puppet.features.libshadow? do
        expect(Shadow::Passwd).to receive(:getspnam).with('myuser').and_return(shadow_entry)
        expect(provider.send(property)).to eq(expected_value)
      end

      # nameservice provider instances are initialized with a @canonical_name
      # instance variable to track the original name of the instance on disk
      # before converting it to UTF-8 if appropriate. When re-querying the
      # system for attributes of this user such as password info, we need to
      # supply the pre-UTF8-converted value.
      it "should query using the canonical_name attribute of the user", :if => Puppet.features.libshadow? do
        canonical_name = [253, 241].pack('C*').force_encoding(Encoding::EUC_KR)
        provider = described_class.new(:name => '??', :canonical_name => canonical_name)

        expect(Shadow::Passwd).to receive(:getspnam).with(canonical_name).and_return(shadow_entry)
        provider.password
      end
    end
  end

  describe '#expiry' do
    before :each do
      resource # just to link the resource to the provider
    end

    it "should return absent if libshadow feature is not present" do
      allow(Puppet.features).to receive(:libshadow?).and_return(false)
      expect(provider.expiry).to eq(:absent)
    end

    it "should return absent if user cannot be found", :if => Puppet.features.libshadow? do
      expect(Shadow::Passwd).to receive(:getspnam).with('myuser').and_return(nil)
      expect(provider.expiry).to eq(:absent)
    end

    it "should return absent if expiry is -1", :if => Puppet.features.libshadow? do
      shadow_entry.sp_expire = -1
      expect(Shadow::Passwd).to receive(:getspnam).with('myuser').and_return(shadow_entry)
      expect(provider.expiry).to eq(:absent)
    end

    it "should convert to YYYY-MM-DD", :if => Puppet.features.libshadow? do
      expect(Shadow::Passwd).to receive(:getspnam).with('myuser').and_return(shadow_entry)
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
      expect(provider).to receive(:command).with(:password)
      provider.passcmd
    end

    it "should return nil if neither min nor max is set" do
      expect(provider.passcmd).to be_nil
    end

    it "should return a chage command array with -m <value> and the user name if password_min_age is set" do
      resource[:password_min_age] = 123
      expect(provider.passcmd).to eq(['/usr/bin/chage', '-m', 123, 'myuser'])
    end

    it "should return a chage command array with -M <value> if password_max_age is set" do
      resource[:password_max_age] = 999
      expect(provider.passcmd).to eq(['/usr/bin/chage', '-M', 999, 'myuser'])
    end

    it "should return a chage command array with -W <value> if password_warn_days is set" do
      resource[:password_warn_days] = 999
      expect(provider.passcmd).to eq(['/usr/bin/chage', '-W', 999, 'myuser'])
    end

    it "should return a chage command array with -M <value> -m <value> if both password_min_age and password_max_age are set" do
      resource[:password_min_age] = 123
      resource[:password_max_age] = 999
      expect(provider.passcmd).to eq(['/usr/bin/chage', '-m', 123, '-M', 999, 'myuser'])
    end

    it "should return a chage command array with -M <value> -m <value> -W <value> if password_min_age, password_max_age and password_warn_days are set" do
      resource[:password_min_age] = 123
      resource[:password_max_age] = 999
      resource[:password_warn_days] = 555
      expect(provider.passcmd).to eq(['/usr/bin/chage', '-m', 123, '-M', 999, '-W', 555, 'myuser'])
    end

    context 'with forcelocal=true' do
      before do
        resource[:forcelocal] = true
      end

      it 'should return a lchage command array with -M <value> -m <value> -W <value> if password_min_age, password_max_age and password_warn_days are set' do
        resource[:password_min_age] = 123
        resource[:password_max_age] = 999
        resource[:password_warn_days] = 555
        expect(provider.passcmd).to eq(['/usr/sbin/lchage', '-m', 123, '-M', 999, '-W', 555, 'myuser'])
      end
    end
  end

  describe "#check_valid_shell" do
    it "should raise an error if shell does not exist" do
      resource[:shell] = 'foo/bin/bash'
      expect { provider.check_valid_shell }.to raise_error(Puppet::Error, /Shell foo\/bin\/bash must exist/)
    end

    it "should raise an error if the shell is not executable" do
      allow(FileTest).to receive(:executable?).with('LICENSE').and_return(false)
      resource[:shell] = 'LICENSE'
      expect { provider.check_valid_shell }.to raise_error(Puppet::Error, /Shell LICENSE must be executable/)
    end
  end

  describe "#delete" do
    before do
       allow(provider).to receive(:exists?).and_return(true)
       resource[:ensure] = :absent
    end

    describe "on systems with the libuser and forcelocal=false" do
      before do
         described_class.has_feature :manages_local_users_and_groups
         resource[:forcelocal] = false
      end

      it "should use userdel to delete users" do
        expect(provider).to receive(:execute).with(include('/usr/sbin/userdel'), hash_including(custom_environment: {}))
        provider.delete
      end
    end

    describe "on systems with the libuser and forcelocal=true" do
      before do
         described_class.has_feature :manages_local_users_and_groups
         resource[:forcelocal] = true
      end

      it "should use luserdel to delete users" do
        expect(provider).to receive(:execute).with(include('/usr/sbin/luserdel'), hash_including(custom_environment: hash_including('LIBUSER_CONF')))
        provider.delete
      end
    end
  end
end
