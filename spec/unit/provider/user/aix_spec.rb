require 'spec_helper'

provider_class = Puppet::Type.type(:user).provider(:aix)

describe provider_class do
  before do
    @resource = stub('resource')
    @provider = provider_class.new(@resource)
  end

  it "should be able to return a group name based on a group ID" do
    @provider.stubs(:lsgroupscmd)

    @provider.stubs(:execute).returns <<-OUTPUT
root id=0 pgrp=system groups=system,bin,sys,security,cron,audit,lp home=/root shell=/usr/bin/bash
guest id=100 pgrp=usr groups=usr home=/home/guest
    OUTPUT

    @provider.groupname_by_id(100).should == 'guest'
  end
end
