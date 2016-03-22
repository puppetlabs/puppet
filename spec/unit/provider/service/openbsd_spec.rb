#!/usr/bin/env ruby
#
# Unit testing for the OpenBSD service provider

require 'spec_helper'

provider_class = Puppet::Type.type(:service).provider(:openbsd)

describe provider_class do
  before :each do
    Puppet::Type.type(:service).stubs(:defaultprovider).returns described_class
    Facter.stubs(:value).with(:operatingsystem).returns :openbsd
    Facter.stubs(:value).with(:osfamily).returns 'OpenBSD'
  end

  let :rcscripts do
    [
      '/etc/rc.d/apmd',
      '/etc/rc.d/aucat',
      '/etc/rc.d/cron',
      '/etc/rc.d/puppetd'
    ]
  end

  describe "#instances" do
    it "should have an instances method" do
      described_class.should respond_to :instances
    end

    it "should list all available services" do
      File.expects(:directory?).with('/etc/rc.d').returns true
      Dir.expects(:glob).with('/etc/rc.d/*').returns rcscripts

      rcscripts.each do |script|
        File.expects(:executable?).with(script).returns true
      end

      described_class.instances.map(&:name).should == [
        'apmd',
        'aucat',
        'cron',
        'puppetd'
      ]
    end
  end

  describe "#start" do
    it "should use the supplied start command if specified" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :start => '/bin/foo'))
      provider.expects(:execute).with(['/bin/foo'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.start
    end

    it "should start the service otherwise" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      provider.expects(:execute).with(['/etc/rc.d/sshd', '-f', :start], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.expects(:search).with('sshd').returns('/etc/rc.d/sshd')
      provider.start
    end
  end

  describe "#stop" do
    it "should use the supplied stop command if specified" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :stop => '/bin/foo'))
      provider.expects(:execute).with(['/bin/foo'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.stop
    end

    it "should stop the service otherwise" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      provider.expects(:execute).with(['/etc/rc.d/sshd', :stop], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.expects(:search).with('sshd').returns('/etc/rc.d/sshd')
      provider.stop
    end
  end

  describe "#status" do
    it "should use the status command from the resource" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :status => '/bin/foo'))
      provider.expects(:execute).with(['/etc/rc.d/sshd', :status], :failonfail => false, :override_locale => false, :squelch => false, :combine => true).never
      provider.expects(:execute).with(['/bin/foo'], :failonfail => false, :override_locale => false, :squelch => false, :combine => true)
      provider.status
    end

    it "should return :stopped when status command returns with a non-zero exitcode" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :status => '/bin/foo'))
      provider.expects(:execute).with(['/etc/rc.d/sshd', :status], :failonfail => false, :override_locale => false, :squelch => false, :combine => true).never
      provider.expects(:execute).with(['/bin/foo'], :failonfail => false, :override_locale => false, :squelch => false, :combine => true)
      $CHILD_STATUS.stubs(:exitstatus).returns 3
      provider.status.should == :stopped
    end

    it "should return :running when status command returns with a zero exitcode" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :status => '/bin/foo'))
      provider.expects(:execute).with(['/etc/rc.d/sshd', :status], :failonfail => false, :override_locale => false, :squelch => false, :combine => true).never
      provider.expects(:execute).with(['/bin/foo'], :failonfail => false, :override_locale => false, :squelch => false, :combine => true)
      $CHILD_STATUS.stubs(:exitstatus).returns 0
      provider.status.should == :running
    end
  end

  describe "#restart" do
    it "should use the supplied restart command if specified" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :restart => '/bin/foo'))
      provider.expects(:execute).with(['/etc/rc.d/sshd', '-f', :restart], :failonfail => true, :override_locale => false, :squelch => false, :combine => true).never
      provider.expects(:execute).with(['/bin/foo'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.restart
    end

    it "should restart the service with rc-service restart if hasrestart is true" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :hasrestart => true))
      provider.expects(:execute).with(['/etc/rc.d/sshd', '-f', :restart], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.expects(:search).with('sshd').returns('/etc/rc.d/sshd')
      provider.restart
    end

    it "should restart the service with rc-service stop/start if hasrestart is false" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd', :hasrestart => false))
      provider.expects(:execute).with(['/etc/rc.d/sshd', '-f', :restart], :failonfail => true, :override_locale => false, :squelch => false, :combine => true).never
      provider.expects(:execute).with(['/etc/rc.d/sshd', :stop], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.expects(:execute).with(['/etc/rc.d/sshd', '-f', :start], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)
      provider.expects(:search).with('sshd').returns('/etc/rc.d/sshd')
      provider.restart
    end
  end

  describe "#parse_rc_line" do
    it "can parse a flag line with a known value" do
      output = described_class.parse_rc_line('daemon_flags=')
      output.should eq('')
    end

    it "can parse a flag line with a flag is wrapped in single quotes" do
      output = described_class.parse_rc_line('daemon_flags=\'\'')
      output.should eq('\'\'')
    end

    it "can parse a flag line with a flag is wrapped in double quotes" do
      output = described_class.parse_rc_line('daemon_flags=""')
      output.should eq('')
    end

    it "can parse a flag line with a trailing comment" do
      output = described_class.parse_rc_line('daemon_flags="-d" # bees')
      output.should eq('-d')
    end

    it "can parse a flag line with a bare word" do
      output = described_class.parse_rc_line('daemon_flags=YES')
      output.should eq('YES')
    end

    it "can parse a flag line with a flag that contains an equals" do
      output = described_class.parse_rc_line('daemon_flags="-Dbla -tmpdir=foo"')
      output.should eq('-Dbla -tmpdir=foo')
    end
  end

  describe "#pkg_scripts" do
    it "can retrieve the package_scripts array from rc.conf.local" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'cupsd'))
      provider.expects(:load_rcconf_local_array).returns ['pkg_scripts="dbus_daemon cupsd"']
      expect(provider.pkg_scripts).to match_array(['dbus_daemon', 'cupsd'])
    end

    it "returns an empty array when no pkg_scripts line is found" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'cupsd'))
      provider.expects(:load_rcconf_local_array).returns ["#\n#\n#"]
      expect(provider.pkg_scripts).to match_array([])
    end
  end

  describe "#pkg_scripts_append" do
    it "can append to the package_scripts array and return the result" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'cupsd'))
      provider.expects(:load_rcconf_local_array).returns ['pkg_scripts="dbus_daemon"']
      provider.pkg_scripts_append.should === ['dbus_daemon', 'cupsd']
    end

    it "should not duplicate the script name" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'cupsd'))
      provider.expects(:load_rcconf_local_array).returns ['pkg_scripts="cupsd dbus_daemon"']
      provider.pkg_scripts_append.should === ['cupsd', 'dbus_daemon']
    end
  end

  describe "#pkg_scripts_remove" do
    it "can append to the package_scripts array and return the result" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'cupsd'))
      provider.expects(:load_rcconf_local_array).returns ['pkg_scripts="dbus_daemon cupsd"']
      expect(provider.pkg_scripts_remove).to match_array(['dbus_daemon'])
    end

    it "should not remove the script from the array unless its needed" do
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'cupsd'))
      provider.expects(:load_rcconf_local_array).returns ['pkg_scripts="dbus_daemon"']
      expect(provider.pkg_scripts_remove).to match_array(['dbus_daemon'])
    end
  end

  describe "#set_content_flags" do
    it "can create the necessary content where none is provided" do
      content = []
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'cupsd'))
      provider.set_content_flags(content,'-d').should match_array(['cupsd_flags="-d"'])
    end

    it "can modify the existing content" do
      content = ['cupsd_flags="-f"']
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'cupsd'))
      output = provider.set_content_flags(content,"-d")
      output.should match_array(['cupsd_flags="-d"'])
    end

    it "does not set empty flags for package scripts" do
      content = []
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'cupsd'))
      provider.expects(:in_base?).returns(false)
      output = provider.set_content_flags(content,'')
      output.should match_array([nil])
    end

    it "does set empty flags for base scripts" do
      content = []
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'ntpd'))
      provider.expects(:in_base?).returns(true)
      output = provider.set_content_flags(content,'')
      output.should match_array(['ntpd_flags=""'])
    end
  end

  describe "#remove_content_flags" do
    it "can remove the flags line from the requested content" do
      content = ['cupsd_flags="-d"']
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'cupsd'))
      output = provider.remove_content_flags(content)
      output.should_not match_array(['cupsd_flags="-d"'])
    end
  end

  describe "#set_content_scripts" do
    it "should append to the list of scripts" do
      content = ['pkg_scripts="dbus_daemon"']
      scripts = ['dbus_daemon','cupsd']
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'cupsd'))
      provider.set_content_scripts(content,scripts).should match_array(['pkg_scripts="dbus_daemon cupsd"'])
    end
  end

  describe "#in_base?" do
    it "should true if in base" do
      File.stubs(:readlines).with('/etc/rc.conf').returns(['sshd_flags=""'])
      provider = described_class.new(Puppet::Type.type(:service).new(:name => 'sshd'))
      provider.in_base?.should be_true
    end
  end
end
