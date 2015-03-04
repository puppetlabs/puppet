require 'spec_helper'

provider_class = Puppet::Type.type(:package).provider(:macports)

describe provider_class do
  let :resource_name do
    "foo"
  end

  let :resource do
    Puppet::Type.type(:package).new(:name => resource_name, :provider => :macports)
  end

  let :provider do
    prov = resource.provider
    prov.expects(:execute).never
    prov
  end

  let :current_hash do
    {:name => resource_name, :ensure => "1.2.3", :revision => "1", :provider => :macports}
  end

  describe "provider features" do
    subject { provider }

    it { is_expected.to be_installable }
    it { is_expected.to be_uninstallable }
    it { is_expected.to be_upgradeable }
    it { is_expected.to be_versionable }
  end

  describe "when listing all instances" do
    it "should call port -q installed" do
      provider_class.expects(:port).with("-q", :installed).returns("")
      provider_class.instances
    end

    it "should create instances from active ports" do
      provider_class.expects(:port).returns("foo @1.234.5_2 (active)")
      expect(provider_class.instances.size).to eq(1)
    end

    it "should ignore ports that aren't activated" do
      provider_class.expects(:port).returns("foo @1.234.5_2")
      expect(provider_class.instances.size).to eq(0)
    end

    it "should ignore variants" do
      expect(provider_class.parse_installed_query_line("bar @1.0beta2_38_1+x11+java (active)")).
        to eq({:provider=>:macports, :revision=>"1", :name=>"bar", :ensure=>"1.0beta2_38"})
    end

  end

  describe "when installing" do
   it "should not specify a version when ensure is set to latest" do
     resource[:ensure] = :latest
     provider.expects(:port).with { |flag, method, name, version|
       expect(version).to be_nil
     }
     provider.install
   end

   it "should not specify a version when ensure is set to present" do
     resource[:ensure] = :present
     provider.expects(:port).with { |flag, method, name, version|
       expect(version).to be_nil
     }
     provider.install
   end

   it "should specify a version when ensure is set to a version" do
     resource[:ensure] = "1.2.3"
     provider.expects(:port).with { |flag, method, name, version|
       expect(version).to be
     }
     provider.install
   end
  end

  describe "when querying for the latest version" do
    let :new_info_line do
      "1.2.3 2"
    end
    let :infoargs do
      ["/opt/local/bin/port", "-q", :info, "--line", "--version", "--revision",  resource_name]
    end
    let(:arguments) do {:failonfail => false, :combine => false} end

    before :each do
      provider.stubs(:command).with(:port).returns("/opt/local/bin/port")
    end

    it "should return nil when the package cannot be found" do
      resource[:name] = resource_name
      provider.expects(:execute).with(infoargs, arguments).returns("")
      expect(provider.latest).to eq(nil)
    end

    it "should return the current version if the installed port has the same revision" do
      current_hash[:revision] = "2"
      provider.expects(:execute).with(infoargs, arguments).returns(new_info_line)
      provider.expects(:query).returns(current_hash)
      expect(provider.latest).to eq(current_hash[:ensure])
    end

    it "should return the new version_revision if the installed port has a lower revision" do
      current_hash[:revision] = "1"
      provider.expects(:execute).with(infoargs, arguments).returns(new_info_line)
      provider.expects(:query).returns(current_hash)
      expect(provider.latest).to eq("1.2.3_2")
    end

    it "should return the newest version if the port is not installed" do
      resource[:name] = resource_name
      provider.expects(:execute).with(infoargs, arguments).returns(new_info_line)
      provider.expects(:execute).with(["/opt/local/bin/port", "-q", :installed, resource[:name]], arguments).returns("")
      expect(provider.latest).to eq("1.2.3_2")
    end
  end

  describe "when updating a port" do
    it "should execute port install if the port is installed" do
      resource[:name] = resource_name
      resource[:ensure] = :present
      provider.stubs(:query).returns(current_hash)
      provider.expects(:port).with("-q", :install, resource_name)
      provider.update
    end

    it "should execute port install if the port is not installed" do
      resource[:name] = resource_name
      resource[:ensure] = :present
      provider.stubs(:query).returns("")
      provider.expects(:port).with("-q", :install, resource_name)
      provider.update
    end
  end
end
