#! /usr/bin/env ruby -S rspec
require 'spec_helper'

describe Puppet::Type.type(:zone).provider(:solaris) do
  let(:resource) { Puppet::Type.type(:zone).new(:name => 'dummy', :path => '/', :provider => :solaris) }
  let(:provider) { resource.provider }

  context "#configure" do
    it "should add the create args to the create str" do
      resource.stubs(:properties).returns([])
      resource[:create_args] = "create_args"
      provider.expects(:setconfig).with("create -b create_args\ncommit")
      provider.configure
    end
  end

  context "#install" do
    context "clone" do
      it "should call zoneadm" do
        provider.expects(:zoneadm).with(:install)
        provider.install
      end

      it "with the resource's clone attribute" do
        resource[:clone] = :clone_argument
        provider.expects(:zoneadm).with(:clone, :clone_argument)
        provider.install
      end
    end

    context "not clone" do
      it "should just install if there are no install args" do
        # there is a nil check in type.rb:[]= so we cannot directly set nil.
        resource.stubs(:[]).with(:clone).returns(nil)
        resource.stubs(:[]).with(:install_args).returns(nil)
        provider.expects(:zoneadm).with(:install)
        provider.install
      end

      it "should add the install args to the command if they exist" do
        # there is a nil check in type.rb:[]= so we cannot directly set nil.
        resource.stubs(:[]).with(:clone).returns(nil)
        resource.stubs(:[]).with(:install_args).returns('install args')
        provider.expects(:zoneadm).with(:install, ["install", "args"])
        provider.install
      end
    end
  end
  context "#instances" do
    it "should list the instances correctly" do
      described_class.expects(:adm).with(:list, "-cp").returns("0:dummy:running:/::native:shared")
      instances = described_class.instances.map { |p| {:name => p.get(:name), :ensure => p.get(:ensure)} }
      instances.size.should == 1
      instances[0].should == {
        :name=>"dummy",
        :ensure=>:running,
      }
    end
  end
  context "#setconfig" do
    it "should correctly set configuration" do
      provider.expects(:cfg).with('-z', 'dummy', "create -b create_args\nset zonepath=\/\ncommit\n").returns('')
      $CHILD_STATUS.stubs(:exitstatus).with().returns 0
      provider.setconfig("create -b create_args\nset zonepath=\/\ncommit\n")
    end

    it "should correctly warn on 'not allowed'" do
      provider.expects(:cfg).with('-z', 'dummy', 'set zonepath=/').returns("Zone z2 already installed; set zonepath not allowed.\n")
      expect {
        provider.setconfig("set zonepath=\/")
      }.to raise_error(ArgumentError, /Failed to apply configuration/)
    end
  end
  context "#getconfig" do
    zone_info =<<-EOF
zonename: dummy
zonepath: /dummy/z
brand: native
autoboot: true
bootargs:
pool:
limitpriv:
scheduling-class:
ip-type: shared
hostid:
net:
        address: 1.1.1.1
        physical: ex0001
        defrouter not specified
net:
        address: 1.1.1.2
        physical: ex0002
        defrouter not specified
    EOF
    it "should correctly parse zone info" do
      provider.expects(:zonecfg).with(:info).returns(zone_info)
      provider.getconfig.should == {
        :brand=>"native",
        :autoboot=>"true",
        :"ip-type"=>"shared",
        :zonename=>"dummy",
        "net"=>[{:physical=>"ex0001", :address=>"1.1.1.1"}, {:physical=>"ex0002", :address=>"1.1.1.2"}],
        :zonepath=>"/dummy/z"
      }
    end
  end
  context "#start" do
    it "should not require path if sysidcfg is specified" do
      resource[:path] = '/mypath'
      resource[:sysidcfg] = 'dummy'
      File.stubs(:exists?).with('/mypath/root/etc/sysidcfg').returns true
      File.stubs(:directory?).with('/mypath/root/etc').returns true
      provider.expects(:zoneadm).with(:boot)
      provider.start
    end

    it "should require path if sysidcfg is specified" do
      resource.stubs(:[]).with(:path).returns nil
      resource.stubs(:[]).with(:sysidcfg).returns 'dummy'
      expect {
        provider.start
      }.to raise_error(Puppet::Error, /Path is required/)
    end
  end
  context "#line2hash" do
    it "should parse lines correctly" do
      described_class.line2hash('0:dummy:running:/z::native:shared').should == {:ensure=>:running, :iptype=>"shared", :path=>"/z", :name=>"dummy", :id=>"0"}
    end
    it "should parse lines correctly(2)" do
      described_class.line2hash('0:dummy:running:/z:ipkg:native:shared').should == {:ensure=>:running, :iptype=>"shared", :path=>"/z", :name=>"dummy", :id=>"0"}
    end
    it "should parse lines correctly(3)" do
      described_class.line2hash('-:dummy:running:/z:ipkg:native:shared').should == {:ensure=>:running, :iptype=>"shared", :path=>"/z", :name=>"dummy"}
    end
    it "should parse lines correctly(3)" do
      described_class.line2hash('-:dummy:running:/z:ipkg:native:exclusive').should == {:ensure=>:running, :iptype=>"exclusive", :path=>"/z", :name=>"dummy"}
    end
  end
  context "#multi_conf" do
    it "should correctly add and remove properties" do
      provider.stubs(:properties).with().returns({:ip => ['1.1.1.1', '2.2.2.2']})
      should = ['1.1.1.1', '3.3.3.3']
      p = Proc.new do |a, str|
        case a
        when :add; 'add:' + str
        when :rm; 'rm:' + str
        end
      end
      provider.multi_conf(:ip, should, &p).should == "rm:2.2.2.2\nadd:3.3.3.3"
    end
  end
  context "single props" do
    {:iptype => /set ip-type/, :autoboot => /set autoboot/, :path => /set zonepath/, :pool => /set pool/, :shares => /add rctl/}.each do |p, v|
      it "#{p.to_s}: should correctly return conf string" do
        provider.send(p.to_s + '_conf', 'dummy').should =~ v
      end
      it "#{p.to_s}: should correctly set property string" do
        provider.expects((p.to_s + '_conf').intern).returns('dummy')
        provider.expects(:setconfig).with('dummy').returns('dummy2')
        provider.send(p.to_s + '=', 'dummy').should == 'dummy2'
      end

    end
  end
end
