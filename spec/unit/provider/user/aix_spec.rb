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

    @provider.groupname_by_id(100).should == 'guest'
  end

  it "should be able to list all users" do
    provider_class.stubs(:command)

    provider_class.stubs(:execute).returns(lsuser_all_example)

    provider_class.list_all.should == ['root', 'guest']
  end

end
