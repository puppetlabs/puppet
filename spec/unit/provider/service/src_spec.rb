#!/usr/bin/env rspec
#
# Unit testing for the AIX System Resource Controller (src) provider
#

require 'spec_helper'

provider_class = Puppet::Type.type(:service).provider(:src)

describe provider_class do

  before :each do
    @resource = stub 'resource'
    @resource.stubs(:[]).returns(nil)
    @resource.stubs(:[]).with(:name).returns "myservice"

    @provider = provider_class.new
    @provider.resource = @resource

    @provider.stubs(:command).with(:stopsrc).returns "/usr/bin/stopsrc"
    @provider.stubs(:command).with(:startsrc).returns "/usr/bin/startsrc"
    @provider.stubs(:command).with(:lssrc).returns "/usr/bin/lssrc"
    @provider.stubs(:command).with(:refresh).returns "/usr/bin/refresh"

    @provider.stubs(:stopsrc)
    @provider.stubs(:startsrc)
    @provider.stubs(:lssrc)
    @provider.stubs(:refresh)
  end

  [:start, :stop, :status, :restart].each do |method|
    it "should have a #{method} method" do
      @provider.should respond_to(method)
    end
  end

  it "should execute the startsrc command" do
    @provider.expects(:execute).with(['/usr/bin/startsrc', '-s', "myservice"], {:squelch => true, :failonfail => true})
    @provider.start
  end

  it "should execute the stopsrc command" do
    @provider.expects(:execute).with(['/usr/bin/stopsrc', '-s', "myservice"], {:squelch => true, :failonfail => true})
    @provider.stop
  end

  it "should execute status and return running if the subsystem is active", :'fails_on_ruby_1.9.2' => true do
    sample_output = <<_EOF_
Subsystem         Group            PID          Status
myservice         tcpip            1234         active
_EOF_

    @provider.expects(:execute).with(['/usr/bin/lssrc', '-s', "myservice"]).returns sample_output
    @provider.status.should == :running
  end

  it "should execute status and return stopped if the subsystem is inoperative", :'fails_on_ruby_1.9.2' => true do
    sample_output = <<_EOF_
Subsystem         Group            PID          Status
myservice         tcpip                         inoperative
_EOF_

    @provider.expects(:execute).with(['/usr/bin/lssrc', '-s', "myservice"]).returns sample_output
    @provider.status.should == :stopped
  end

  it "should execute status and return nil if the status is not known", :'fails_on_ruby_1.9.2' => true do
    sample_output = <<_EOF_
Subsystem         Group            PID          Status
myservice         tcpip                         randomdata
_EOF_

    @provider.expects(:execute).with(['/usr/bin/lssrc', '-s', "myservice"]).returns sample_output
    @provider.status.should == nil
  end

  it "should execute restart which runs refresh", :'fails_on_ruby_1.9.2' => true do
    sample_output = <<_EOF_
#subsysname:synonym:cmdargs:path:uid:auditid:standin:standout:standerr:action:multi:contact:svrkey:svrmtype:priority:signorm:sigforce:display:waittime:grpname:
myservice:::/usr/sbin/inetd:0:0:/dev/console:/dev/console:/dev/console:-O:-Q:-K:0:0:20:0:0:-d:20:tcpip:
_EOF_
    @provider.expects(:execute).with(['/usr/bin/lssrc', '-Ss', "myservice"]).returns sample_output
    @provider.expects(:execute).with(['/usr/bin/refresh', '-s', "myservice"])
    @provider.restart
  end

  it "should execute restart which runs stopsrc then startsrc", :'fails_on_ruby_1.9.2' => true do
    sample_output =  <<_EOF_
#subsysname:synonym:cmdargs:path:uid:auditid:standin:standout:standerr:action:multi:contact:svrkey:svrmtype:priority:signorm:sigforce:display:waittime:grpname:
myservice::--no-daemonize:/usr/sbin/puppetd:0:0:/dev/null:/var/log/puppet.log:/var/log/puppet.log:-O:-Q:-S:0:0:20:15:9:-d:20::"
_EOF_
    @provider.expects(:execute).with(['/usr/bin/lssrc', '-Ss', "myservice"]).returns sample_output
    @provider.expects(:execute).with(['/usr/bin/stopsrc', '-s', "myservice"], {:squelch => true, :failonfail => true})
    @provider.expects(:execute).with(['/usr/bin/startsrc', '-s', "myservice"], {:squelch => true, :failonfail => true})
    @provider.restart
  end
end
