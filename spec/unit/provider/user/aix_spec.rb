require 'spec_helper'

provider_class = Puppet::Type.type(:user).provider(:aix)

describe provider_class do

  let(:lsuser_all_example) do
    <<-OUTPUT
root id=0 pgrp=system groups=system,bin,sys,security,cron,audit,lp home=/root shell=/usr/bin/bash auditclasses=general login=true su=true rlogin=true daemon=true admin=true sugroups=ALL admgroups=lolt,allstaff tpath=nosak ttys=ALL expires=0 auth1=SYSTEM auth2=NONE umask=22 registry=files SYSTEM=compat logintimes= loginretries=0 pwdwarntime=0 account_locked=false minage=0 maxage=0 maxexpired=-1 minalpha=0 minother=0 mindiff=0 maxrepeats=8 minlen=0 histexpire=0 histsize=0 pwdchecks= dictionlist= default_roles= fsize=2097151 cpu=-1 data=262144 stack=65536 core=2097151 rss=65536 nofiles=2000 time_last_login=1358465855 time_last_unsuccessful_login=1358378454 tty_last_login=ssh tty_last_unsuccessful_login=ssh host_last_login=rpm-builder.puppetlabs.lan host_last_unsuccessful_login=192.168.100.78 unsuccessful_login_count=0 roles=
guest id=100 pgrp=usr groups=usr home=/home/guest login=true su=true rlogin=true daemon=true admin=false sugroups=ALL admgroups= tpath=nosak ttys=ALL expires=0 auth1=SYSTEM auth2=NONE umask=22 registry=files SYSTEM=compat logintimes= loginretries=0 pwdwarntime=0 account_locked=false minage=0 maxage=0 maxexpired=-1 minalpha=0 minother=0 mindiff=0 maxrepeats=8 minlen=0 histexpire=0 histsize=0 pwdchecks= dictionlist= default_roles= fsize=2097151 cpu=-1 data=262144 stack=65536 core=2097151 rss=65536 nofiles=2000 roles=
    OUTPUT
  end

  let(:lsgroup_all_example) do
    <<-OUTPUT
root id=0 pgrp=system groups=system,bin,sys,security,cron,audit,lp home=/root shell=/usr/bin/bash
guest id=100 pgrp=usr groups=usr home=/home/guest
    OUTPUT
  end

  before do
    @resource = stub('resource')
    @provider = provider_class.new(@resource)
  end

  it "should be able to return a group name based on a group ID" do
    @provider.stubs(:lsgroupscmd)

    @provider.stubs(:execute).returns(lsgroup_all_example)

    expect(@provider.groupname_by_id(100)).to eq('guest')
  end

  it "should be able to list all users" do
    provider_class.stubs(:command)

    provider_class.stubs(:execute).returns(lsuser_all_example)

    expect(provider_class.list_all).to eq(['root', 'guest'])
  end

  describe "#managed_attribute_keys" do
    let(:existing_attributes) do
      { :account_locked => 'false',
        :admin => 'false',
        :login => 'true',
        'su' => 'true'
      }
    end

    before(:each) do
      original_parameters = { :attributes => attribute_array }
      @resource.stubs(:original_parameters).returns(original_parameters)
    end

    describe "invoked via manifest" do
      let(:attribute_array) { ["rlogin=false", "login =true"] }
      let(:single_attribute_array) { "rlogin=false" }

      it "should return only the keys of the attribute key=value pair from manifest" do
        keys = @provider.managed_attribute_keys(existing_attributes)
        expect(keys).to be_include(:rlogin)
        expect(keys).to be_include(:login)
        expect(keys).not_to be_include(:su)
      end

      it "should strip spaces from symbols" do
        keys = @provider.managed_attribute_keys(existing_attributes)
        expect(keys).to be_include(:login)
        expect(keys).not_to be_include(:"login ")
      end

      it "should have the same count as that from the manifest" do
        keys = @provider.managed_attribute_keys(existing_attributes)
        expect(keys.size).to eq(attribute_array.size)
      end

      it "should convert the keys to symbols" do
        keys = @provider.managed_attribute_keys(existing_attributes)
        all_symbols = keys.all? {|k| k.is_a? Symbol}
        expect(all_symbols).to be_truthy
      end

      it "should allow a single attribute to be specified" do
        @resource.stubs(:original_parameters).returns({ :attributes => single_attribute_array })
        keys = @provider.managed_attribute_keys(existing_attributes)
        expect(keys).to be_include(:rlogin)
      end
    end

    describe "invoked via RAL" do
      let(:attribute_array) { nil }

      it "should return the keys in supplied hash" do
        keys = @provider.managed_attribute_keys(existing_attributes)
        expect(keys).not_to be_include(:rlogin)
        expect(keys).to be_include(:login)
        expect(keys).to be_include(:su)
      end

      it "should convert the keys to symbols" do
        keys = @provider.managed_attribute_keys(existing_attributes)
        all_symbols = keys.all? {|k| k.is_a? Symbol}
        expect(all_symbols).to be_truthy
      end
    end
  end

  describe "#should_include?" do
    it "should exclude keys translated into something else" do
      managed_keys = [:rlogin]
      @provider.class.attribute_mapping_from.stubs(:include?).with(:rlogin).returns(true)
      @provider.class.stubs(:attribute_ignore).returns([])
      expect(@provider.should_include?(:rlogin, managed_keys)).to be_falsey
    end

    it "should exclude keys explicitly ignored" do
      managed_keys = [:rlogin]
      @provider.class.attribute_mapping_from.stubs(:include?).with(:rlogin).returns(false)
      @provider.class.stubs(:attribute_ignore).returns([:rlogin])
      expect(@provider.should_include?(:rlogin, managed_keys)).to be_falsey
    end

    it "should exclude keys not specified in manifest" do
      managed_keys = [:su]
      @provider.class.attribute_mapping_from.stubs(:include?).with(:rlogin).returns(false)
      @provider.class.stubs(:attribute_ignore).returns([])
      expect(@provider.should_include?(:rlogin, managed_keys)).to be_falsey
    end

    it "should include keys specified in manifest if not translated or ignored" do
      managed_keys = [:rlogin]
      @provider.class.attribute_mapping_from.stubs(:include?).with(:rlogin).returns(false)
      @provider.class.stubs(:attribute_ignore).returns([])
      expect(@provider.should_include?(:rlogin, managed_keys)).to be_truthy
    end
  end
  describe "when handling passwords" do
    let(:passwd_without_spaces) do
        # from http://pic.dhe.ibm.com/infocenter/aix/v7r1/index.jsp?topic=%2Fcom.ibm.aix.files%2Fdoc%2Faixfiles%2Fpasswd_security.htm
        <<-OUTPUT
smith:
  password = MGURSj.F056Dj
  lastupdate = 623078865
  flags = ADMIN,NOCHECK
        OUTPUT
    end

    let(:passwd_with_spaces) do
        # add trailing space to the password
        passwd_without_spaces.gsub(/password = (.*)/, 'password = \1   ')
    end


    it "should be able to read the hashed password" do
      @provider.stubs(:open_security_passwd).returns(StringIO.new(passwd_without_spaces))
      @resource.stubs(:[]).returns('smith')

      expect(@provider.password).to eq('MGURSj.F056Dj')
    end

    it "should be able to read the hashed password, even with trailing spaces" do
      @provider.stubs(:open_security_passwd).returns(StringIO.new(passwd_with_spaces))
      @resource.stubs(:[]).returns('smith')

      expect(@provider.password).to eq('MGURSj.F056Dj')
    end
  end
end
