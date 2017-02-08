#! /usr/bin/env ruby
#
# Unit testing for the AIX System Resource Controller (src) provider
#

require 'spec_helper'

provider_class = Puppet::Type.type(:service).provider(:src)

describe provider_class do

  if Puppet.features.microsoft_windows?
    # Get a pid for $CHILD_STATUS to latch on to
    command = "cmd.exe /c \"exit 0\""
    Puppet::Util::Execution.execute(command, {:failonfail => false})
  end

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
    @provider.stubs(:command).with(:lsitab).returns "/usr/sbin/lsitab"
    @provider.stubs(:command).with(:mkitab).returns "/usr/sbin/mkitab"
    @provider.stubs(:command).with(:rmitab).returns "/usr/sbin/rmitab"
    @provider.stubs(:command).with(:chitab).returns "/usr/sbin/chitab"

    @provider.stubs(:stopsrc)
    @provider.stubs(:startsrc)
    @provider.stubs(:lssrc)
    @provider.stubs(:refresh)
    @provider.stubs(:lsitab)
    @provider.stubs(:mkitab)
    @provider.stubs(:rmitab)
    @provider.stubs(:chitab)
  end

  describe ".instances" do
    it "should have a .instances method" do
      expect(provider_class).to respond_to :instances
    end

    it "should get a list of running services" do
      sample_output = <<_EOF_
#subsysname:synonym:cmdargs:path:uid:auditid:standin:standout:standerr:action:multi:contact:svrkey:svrmtype:priority:signorm:sigforce:display:waittime:grpname:
myservice.1:::/usr/sbin/inetd:0:0:/dev/console:/dev/console:/dev/console:-O:-Q:-K:0:0:20:0:0:-d:20:tcpip:
myservice.2:::/usr/sbin/inetd:0:0:/dev/console:/dev/console:/dev/console:-O:-Q:-K:0:0:20:0:0:-d:20:tcpip:
myservice.3:::/usr/sbin/inetd:0:0:/dev/console:/dev/console:/dev/console:-O:-Q:-K:0:0:20:0:0:-d:20:tcpip:
myservice.4:::/usr/sbin/inetd:0:0:/dev/console:/dev/console:/dev/console:-O:-Q:-K:0:0:20:0:0:-d:20:tcpip:
_EOF_
      provider_class.stubs(:lssrc).returns sample_output
      expect(provider_class.instances.map(&:name)).to eq([
        'myservice.1',
        'myservice.2',
        'myservice.3',
        'myservice.4'
      ])
    end

  end

  describe "when starting a service" do
    it "should execute the startsrc command" do
      @provider.expects(:execute).with(['/usr/bin/startsrc', '-s', "myservice"], {:override_locale => false, :squelch => false, :combine => true, :failonfail => true})
      @provider.expects(:status).returns :running
      @provider.start
    end

    it "should error if timeout occurs while stopping the service" do
      @provider.expects(:execute).with(['/usr/bin/startsrc', '-s', "myservice"], {:override_locale => false, :squelch => false, :combine => true, :failonfail => true})
      Timeout.expects(:timeout).with(60).raises(Timeout::Error)
      expect { @provider.start }.to raise_error Puppet::Error, ('Timed out waiting for myservice to transition states')
    end
  end

  describe "when stopping a service" do
    it "should execute the stopsrc command" do
      @provider.expects(:execute).with(['/usr/bin/stopsrc', '-s', "myservice"], {:override_locale => false, :squelch => false, :combine => true, :failonfail => true})
      @provider.expects(:status).returns :stopped
      @provider.stop
    end

    it "should error if timeout occurs while stopping the service" do
      @provider.expects(:execute).with(['/usr/bin/stopsrc', '-s', "myservice"], {:override_locale => false, :squelch => false, :combine => true, :failonfail => true})
      Timeout.expects(:timeout).with(60).raises(Timeout::Error)
      expect { @provider.stop }.to raise_error Puppet::Error, ('Timed out waiting for myservice to transition states')
    end
  end

  describe "should have a set of methods" do
    [:enabled?, :enable, :disable, :start, :stop, :status, :restart].each do |method|
      it "should have a #{method} method" do
        expect(@provider).to respond_to(method)
      end
    end
  end

  describe "when enabling" do
    it "should execute the mkitab command" do
      @provider.expects(:mkitab).with("myservice:2:once:/usr/bin/startsrc -s myservice").once
      @provider.enable
    end
  end

  describe "when disabling" do
    it "should execute the rmitab command" do
      @provider.expects(:rmitab).with("myservice")
      @provider.disable
    end
  end

  describe "when checking if it is enabled" do
    it "should execute the lsitab command" do
      @provider.expects(:execute).with(['/usr/sbin/lsitab', 'myservice'], {:combine => true, :failonfail => false})
      $CHILD_STATUS.stubs(:exitstatus).returns(0)
      @provider.enabled?
    end

    it "should return false when lsitab returns non-zero" do
      @provider.stubs(:execute)
      $CHILD_STATUS.stubs(:exitstatus).returns(1)
      expect(@provider.enabled?).to eq(:false)
    end

    it "should return true when lsitab returns zero" do
      @provider.stubs(:execute)
      $CHILD_STATUS.stubs(:exitstatus).returns(0)
      expect(@provider.enabled?).to eq(:true)
    end
  end


  describe "when checking a subsystem's status" do
    it "should execute status and return running if the subsystem is active" do
      sample_output = <<_EOF_
  Subsystem         Group            PID          Status
  myservice         tcpip            1234         active
_EOF_

      @provider.expects(:execute).with(['/usr/bin/lssrc', '-s', "myservice"]).returns sample_output
      expect(@provider.status).to eq(:running)
    end

    it "should execute status and return stopped if the subsystem is inoperative" do
      sample_output = <<_EOF_
  Subsystem         Group            PID          Status
  myservice         tcpip                         inoperative
_EOF_

      @provider.expects(:execute).with(['/usr/bin/lssrc', '-s', "myservice"]).returns sample_output
      expect(@provider.status).to eq(:stopped)
    end

    it "should execute status and return nil if the status is not known" do
      sample_output = <<_EOF_
  Subsystem         Group            PID          Status
  myservice         tcpip                         randomdata
_EOF_

      @provider.expects(:execute).with(['/usr/bin/lssrc', '-s', "myservice"]).returns sample_output
      expect(@provider.status).to eq(nil)
    end

    it "should consider a non-existing service to be have a status of :stopped" do
      @provider.expects(:execute).with(['/usr/bin/lssrc', '-s', 'myservice']).raises(Puppet::ExecutionFailure, "fail")
      expect(@provider.status).to eq(:stopped)
    end
  end

  describe "when restarting a service" do
    it "should execute restart which runs refresh" do
      sample_output = <<_EOF_
#subsysname:synonym:cmdargs:path:uid:auditid:standin:standout:standerr:action:multi:contact:svrkey:svrmtype:priority:signorm:sigforce:display:waittime:grpname:
myservice:::/usr/sbin/inetd:0:0:/dev/console:/dev/console:/dev/console:-O:-Q:-K:0:0:20:0:0:-d:20:tcpip:
_EOF_
      @provider.expects(:execute).with(['/usr/bin/lssrc', '-Ss', "myservice"]).returns sample_output
      @provider.expects(:execute).with(['/usr/bin/refresh', '-s', "myservice"])
      @provider.restart
    end

    it "should execute restart which runs stop then start" do
      sample_output =  <<_EOF_
#subsysname:synonym:cmdargs:path:uid:auditid:standin:standout:standerr:action:multi:contact:svrkey:svrmtype:priority:signorm:sigforce:display:waittime:grpname:
myservice::--no-daemonize:/usr/sbin/puppetd:0:0:/dev/null:/var/log/puppet.log:/var/log/puppet.log:-O:-Q:-S:0:0:20:15:9:-d:20::"
_EOF_

      @provider.expects(:execute).with(['/usr/bin/lssrc', '-Ss', "myservice"]).returns sample_output
      @provider.expects(:stop)
      @provider.expects(:start)
      @provider.restart
    end
  end
end
