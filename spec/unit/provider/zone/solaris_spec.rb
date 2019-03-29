require 'spec_helper'

describe Puppet::Type.type(:zone).provider(:solaris) do
  let(:resource) { Puppet::Type.type(:zone).new(:name => 'dummy', :path => '/', :provider => :solaris) }
  let(:provider) { described_class.new(resource) }

  context "#configure" do
    it "should add the create args to the create str" do
      allow(resource).to receive(:properties).and_return([])
      resource[:create_args] = "create_args"
      expect(provider).to receive(:setconfig).with("create -b create_args")
      provider.configure
    end

    it "should add the create args to the create str" do
      iptype = double("property")
      allow(iptype).to receive(:name).with(no_args).and_return(:iptype)
      allow(iptype).to receive(:safe_insync?).with(iptype).and_return(false)
      allow(provider).to receive(:properties).and_return({:iptype => iptype})
      allow(resource).to receive(:properties).with(no_args).and_return([iptype])
      resource[:create_args] = "create_args"
      expect(provider).to receive(:setconfig).with("create -b create_args\nset ip-type=shared")
      provider.configure
    end
  end

  context "#install" do
    context "clone" do
      it "should call zoneadm" do
        expect(provider).to receive(:zoneadm).with(:install)
        provider.install
      end

      it "with the resource's clone attribute" do
        resource[:clone] = :clone_argument
        expect(provider).to receive(:zoneadm).with(:clone, :clone_argument)
        provider.install
      end
    end

    context "not clone" do
      it "should just install if there are no install args" do
        # there is a nil check in type.rb:[]= so we cannot directly set nil.
        allow(resource).to receive(:[]).with(:clone).and_return(nil)
        allow(resource).to receive(:[]).with(:install_args).and_return(nil)
        expect(provider).to receive(:zoneadm).with(:install)
        provider.install
      end

      it "should add the install args to the command if they exist" do
        # there is a nil check in type.rb:[]= so we cannot directly set nil.
        allow(resource).to receive(:[]).with(:clone).and_return(nil)
        allow(resource).to receive(:[]).with(:install_args).and_return('install args')
        expect(provider).to receive(:zoneadm).with(:install, ["install", "args"])
        provider.install
      end
    end
  end

  context "#instances" do
    it "should list the instances correctly" do
      expect(described_class).to receive(:adm).with(:list, "-cp").and_return("0:dummy:running:/::native:shared")
      instances = described_class.instances.map { |p| {:name => p.get(:name), :ensure => p.get(:ensure)} }
      expect(instances.size).to eq(1)
      expect(instances[0]).to eq({
        :name=>"dummy",
        :ensure=>:running,
      })
    end
  end

  context "#setconfig" do
    it "should correctly set configuration" do
      expect(provider).to receive(:command).with(:cfg).and_return('/usr/sbin/zonecfg')
      expect(provider).to receive(:exec_cmd).with(:input => "set zonepath=/\ncommit\nexit", :cmd => '/usr/sbin/zonecfg -z dummy -f -').and_return({:out=>'', :exit => 0})
      provider.setconfig("set zonepath=\/")
      provider.flush
    end

    it "should correctly warn on 'not allowed'" do
      expect(provider).to receive(:command).with(:cfg).and_return('/usr/sbin/zonecfg')
      expect(provider).to receive(:exec_cmd).with(:input => "set zonepath=/\ncommit\nexit", :cmd => '/usr/sbin/zonecfg -z dummy -f -').and_return({:out=>"Zone z2 already installed; set zonepath not allowed.\n", :exit => 0})
      provider.setconfig("set zonepath=\/")
      expect {
        provider.flush
      }.to raise_error(ArgumentError, /Failed to apply configuration/)
    end
  end

  context "#getconfig" do
    describe "with a shared iptype zone" do
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
        expect(provider).to receive(:zonecfg).with(:info).and_return(zone_info)
        expect(provider.getconfig).to eq({
          :brand=>"native",
          :autoboot=>"true",
          :"ip-type"=>"shared",
          :zonename=>"dummy",
          "net"=>[{:physical=>"ex0001", :address=>"1.1.1.1"}, {:physical=>"ex0002", :address=>"1.1.1.2"}],
          :zonepath=>"/dummy/z"
        })
      end
    end

    describe "with an exclusive iptype zone" do
      zone_info =<<-EOF
zonename: dummy
zonepath: /dummy/z
brand: native
autoboot: true
bootargs:
pool:
limitpriv:
scheduling-class:
ip-type: exclusive
hostid:
net:
        address not specified
        allowed-address not specified
        configure-allowed-address: true
        physical: net1
        defrouter not specified
      EOF

      it "should correctly parse zone info" do
        expect(provider).to receive(:zonecfg).with(:info).and_return(zone_info)
        expect(provider.getconfig).to eq({
          :brand=>"native",
          :autoboot=>"true",
          :"ip-type"=>"exclusive",
          :zonename=>"dummy",
          "net"=>[{:physical=>"net1",:'configure-allowed-address'=>"true"}],
          :zonepath=>"/dummy/z"
        })
      end
    end

    describe "with an invalid or unrecognized config" do
      it "should produce an error message with provider context when given an invalid config" do
        erroneous_zone_info =<<-EOF
          physical: net1'
        EOF

        expect(provider).to receive(:zonecfg).with(:info).and_return(erroneous_zone_info)
        expect(provider).to receive('err').with("Ignoring '          physical: net1''")
        provider.getconfig
      end

      it "should produce a debugging message with provider context when given an unrecognized config" do
        unrecognized_zone_info = "dummy"
        expect(provider).to receive(:zonecfg).with(:info).and_return(unrecognized_zone_info)
        expect(provider).to receive('debug').with("Ignoring zone output 'dummy'")
        provider.getconfig
      end
    end
  end

  context "#flush" do
    it "should correctly execute pending commands" do
      expect(provider).to receive(:command).with(:cfg).and_return('/usr/sbin/zonecfg')
      expect(provider).to receive(:exec_cmd).with(:input => "set iptype=shared\ncommit\nexit", :cmd => '/usr/sbin/zonecfg -z dummy -f -').and_return({:out=>'', :exit => 0})
      provider.setconfig("set iptype=shared")
      provider.flush
    end

    it "should correctly raise error on failure" do
      expect(provider).to receive(:command).with(:cfg).and_return('/usr/sbin/zonecfg')
      expect(provider).to receive(:exec_cmd).with(:input => "set iptype=shared\ncommit\nexit", :cmd => '/usr/sbin/zonecfg -z dummy -f -').and_return({:out=>'', :exit => 1})
      provider.setconfig("set iptype=shared")
      expect {
        provider.flush
      }.to raise_error(ArgumentError, /Failed to apply/)
    end
  end

  context "#start" do
    it "should not require path if sysidcfg is specified" do
      resource[:path] = '/mypath'
      resource[:sysidcfg] = 'dummy'
      allow(Puppet::FileSystem).to receive(:exist?).with('/mypath/root/etc/sysidcfg').and_return(true)
      allow(File).to receive(:directory?).with('/mypath/root/etc').and_return(true)
      expect(provider).to receive(:zoneadm).with(:boot)
      provider.start
    end

    it "should require path if sysidcfg is specified" do
      allow(resource).to receive(:[]).with(:path).and_return(nil)
      allow(resource).to receive(:[]).with(:sysidcfg).and_return('dummy')
      expect {
        provider.start
      }.to raise_error(Puppet::Error, /Path is required/)
    end
  end

  context "#line2hash" do
    it "should parse lines correctly" do
      expect(described_class.line2hash('0:dummy:running:/z::native:shared')).to eq({:ensure=>:running, :iptype=>"shared", :path=>"/z", :name=>"dummy", :id=>"0"})
    end

    it "should parse lines correctly(2)" do
      expect(described_class.line2hash('0:dummy:running:/z:ipkg:native:shared')).to eq({:ensure=>:running, :iptype=>"shared", :path=>"/z", :name=>"dummy", :id=>"0"})
    end

    it "should parse lines correctly(3)" do
      expect(described_class.line2hash('-:dummy:running:/z:ipkg:native:shared')).to eq({:ensure=>:running, :iptype=>"shared", :path=>"/z", :name=>"dummy"})
    end

    it "should parse lines correctly(3)" do
      expect(described_class.line2hash('-:dummy:running:/z:ipkg:native:exclusive')).to eq({:ensure=>:running, :iptype=>"exclusive", :path=>"/z", :name=>"dummy"})
    end
  end

  context "#multi_conf" do
    it "should correctly add and remove properties" do
      allow(provider).to receive(:properties).with(no_args).and_return({:ip => ['1.1.1.1', '2.2.2.2']})
      should = ['1.1.1.1', '3.3.3.3']
      p = Proc.new do |a, str|
        case a
        when :add; 'add:' + str
        when :rm; 'rm:' + str
        end
      end
      expect(provider.multi_conf(:ip, should, &p)).to eq("rm:2.2.2.2\nadd:3.3.3.3")
    end
  end

  context "single props" do
    {:iptype => /set ip-type/, :autoboot => /set autoboot/, :path => /set zonepath/, :pool => /set pool/, :shares => /add rctl/}.each do |p, v|
      it "#{p.to_s}: should correctly return conf string" do
        expect(provider.send(p.to_s + '_conf', 'dummy')).to match(v)
      end

      it "#{p.to_s}: should correctly set property string" do
        expect(provider).to receive((p.to_s + '_conf').intern).and_return('dummy')
        expect(provider).to receive(:setconfig).with('dummy').and_return('dummy2')
        expect(provider.send(p.to_s + '=', 'dummy')).to eq('dummy2')
      end
    end
  end
end
