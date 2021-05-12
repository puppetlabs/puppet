require 'spec_helper'

describe 'Puppet::Type::Service::Provider::Src',
         unless: Puppet::Util::Platform.windows? || Puppet::Util::Platform.jruby? do
  let(:provider_class) { Puppet::Type.type(:service).provider(:src) }

  before :each do
    @resource = double('resource')
    allow(@resource).to receive(:[]).and_return(nil)
    allow(@resource).to receive(:[]).with(:name).and_return("myservice")

    @provider = provider_class.new
    @provider.resource = @resource

    allow(@provider).to receive(:command).with(:stopsrc).and_return("/usr/bin/stopsrc")
    allow(@provider).to receive(:command).with(:startsrc).and_return("/usr/bin/startsrc")
    allow(@provider).to receive(:command).with(:lssrc).and_return("/usr/bin/lssrc")
    allow(@provider).to receive(:command).with(:refresh).and_return("/usr/bin/refresh")
    allow(@provider).to receive(:command).with(:lsitab).and_return("/usr/sbin/lsitab")
    allow(@provider).to receive(:command).with(:mkitab).and_return("/usr/sbin/mkitab")
    allow(@provider).to receive(:command).with(:rmitab).and_return("/usr/sbin/rmitab")
    allow(@provider).to receive(:command).with(:chitab).and_return("/usr/sbin/chitab")

    allow(@provider).to receive(:stopsrc)
    allow(@provider).to receive(:startsrc)
    allow(@provider).to receive(:lssrc)
    allow(@provider).to receive(:refresh)
    allow(@provider).to receive(:lsitab)
    allow(@provider).to receive(:mkitab)
    allow(@provider).to receive(:rmitab)
    allow(@provider).to receive(:chitab)
  end

  context ".instances" do
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
      allow(provider_class).to receive(:lssrc).and_return(sample_output)
      expect(provider_class.instances.map(&:name)).to eq([
        'myservice.1',
        'myservice.2',
        'myservice.3',
        'myservice.4'
      ])
    end
  end

  context "when starting a service" do
    it "should execute the startsrc command" do
      expect(@provider).to receive(:execute).with(['/usr/bin/startsrc', '-s', "myservice"], {:override_locale => false, :squelch => false, :combine => true, :failonfail => true})
      expect(@provider).to receive(:status).and_return(:running)
      @provider.start
    end

    it "should error if timeout occurs while stopping the service" do
      expect(@provider).to receive(:execute).with(['/usr/bin/startsrc', '-s', "myservice"], {:override_locale => false, :squelch => false, :combine => true, :failonfail => true})
      expect(Timeout).to receive(:timeout).with(60).and_raise(Timeout::Error)
      expect { @provider.start }.to raise_error Puppet::Error, ('Timed out waiting for myservice to transition states')
    end
  end

  context "when stopping a service" do
    it "should execute the stopsrc command" do
      expect(@provider).to receive(:execute).with(['/usr/bin/stopsrc', '-s', "myservice"], {:override_locale => false, :squelch => false, :combine => true, :failonfail => true})
      expect(@provider).to receive(:status).and_return(:stopped)
      @provider.stop
    end

    it "should error if timeout occurs while stopping the service" do
      expect(@provider).to receive(:execute).with(['/usr/bin/stopsrc', '-s', "myservice"], {:override_locale => false, :squelch => false, :combine => true, :failonfail => true})
      expect(Timeout).to receive(:timeout).with(60).and_raise(Timeout::Error)
      expect { @provider.stop }.to raise_error Puppet::Error, ('Timed out waiting for myservice to transition states')
    end
  end

  context "should have a set of methods" do
    [:enabled?, :enable, :disable, :start, :stop, :status, :restart].each do |method|
      it "should have a #{method} method" do
        expect(@provider).to respond_to(method)
      end
    end
  end

  context "when enabling" do
    it "should execute the mkitab command" do
      expect(@provider).to receive(:mkitab).with("myservice:2:once:/usr/bin/startsrc -s myservice").once
      @provider.enable
    end
  end

  context "when disabling" do
    it "should execute the rmitab command" do
      expect(@provider).to receive(:rmitab).with("myservice")
      @provider.disable
    end
  end

  context "when checking if it is enabled" do
    it "should execute the lsitab command" do
      expect(@provider).to receive(:execute)
        .with(['/usr/sbin/lsitab', 'myservice'], {:combine => true, :failonfail => false})
        .and_return(Puppet::Util::Execution::ProcessOutput.new('', 0))
      @provider.enabled?
    end

    it "should return false when lsitab returns non-zero" do
      expect(@provider).to receive(:execute).and_return(Puppet::Util::Execution::ProcessOutput.new('', 1))
      expect(@provider.enabled?).to eq(:false)
    end

    it "should return true when lsitab returns zero" do
      allow(@provider).to receive(:execute).and_return(Puppet::Util::Execution::ProcessOutput.new('', 0))
      expect(@provider.enabled?).to eq(:true)
    end
  end

  context "when checking a subsystem's status" do
    it "should execute status and return running if the subsystem is active" do
      sample_output = <<_EOF_
  Subsystem         Group            PID          Status
  myservice         tcpip            1234         active
_EOF_

      expect(@provider).to receive(:execute).with(['/usr/bin/lssrc', '-s', "myservice"]).and_return(sample_output)
      expect(@provider.status).to eq(:running)
    end

    it "should execute status and return stopped if the subsystem is inoperative" do
      sample_output = <<_EOF_
  Subsystem         Group            PID          Status
  myservice         tcpip                         inoperative
_EOF_

      expect(@provider).to receive(:execute).with(['/usr/bin/lssrc', '-s', "myservice"]).and_return(sample_output)
      expect(@provider.status).to eq(:stopped)
    end

    it "should execute status and return nil if the status is not known" do
      sample_output = <<_EOF_
  Subsystem         Group            PID          Status
  myservice         tcpip                         randomdata
_EOF_

      expect(@provider).to receive(:execute).with(['/usr/bin/lssrc', '-s', "myservice"]).and_return(sample_output)
      expect(@provider.status).to eq(nil)
    end

    it "should consider a non-existing service to be have a status of :stopped" do
      expect(@provider).to receive(:execute).with(['/usr/bin/lssrc', '-s', 'myservice']).and_raise(Puppet::ExecutionFailure, "fail")
      expect(@provider.status).to eq(:stopped)
    end
  end

  context "when restarting a service" do
    it "should execute restart which runs refresh" do
      sample_output = <<_EOF_
#subsysname:synonym:cmdargs:path:uid:auditid:standin:standout:standerr:action:multi:contact:svrkey:svrmtype:priority:signorm:sigforce:display:waittime:grpname:
myservice:::/usr/sbin/inetd:0:0:/dev/console:/dev/console:/dev/console:-O:-Q:-K:0:0:20:0:0:-d:20:tcpip:
_EOF_
      expect(@provider).to receive(:execute).with(['/usr/bin/lssrc', '-Ss', "myservice"]).and_return(sample_output)
      expect(@provider).to receive(:execute).with(['/usr/bin/refresh', '-s', "myservice"])
      @provider.restart
    end

    it "should execute restart which runs stop then start" do
      sample_output =  <<_EOF_
#subsysname:synonym:cmdargs:path:uid:auditid:standin:standout:standerr:action:multi:contact:svrkey:svrmtype:priority:signorm:sigforce:display:waittime:grpname:
myservice::--no-daemonize:/usr/sbin/puppetd:0:0:/dev/null:/var/log/puppet.log:/var/log/puppet.log:-O:-Q:-S:0:0:20:15:9:-d:20::"
_EOF_

      expect(@provider).to receive(:execute).with(['/usr/bin/lssrc', '-Ss', "myservice"]).and_return(sample_output)
      expect(@provider).to receive(:stop)
      expect(@provider).to receive(:start)
      @provider.restart
    end
  end
end
