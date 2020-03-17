require 'spec_helper'

describe Puppet::Type.type(:package).provider(:apt) do
  let(:name) { 'asdf' }

  let(:resource) do
    Puppet::Type.type(:package).new(
      :name     => name,
      :provider => 'apt'
    )
  end

  let(:provider) do
    provider = subject()
    provider.resource = resource
    provider
  end

  it "should be the default provider on :osfamily => Debian" do
    expect(Facter).to receive(:value).with(:osfamily).and_return("Debian")
    expect(described_class.default?).to be_truthy
  end

  it "should be versionable" do
    expect(described_class).to be_versionable
  end

  it "should use :install to update" do
    expect(provider).to receive(:install)
    provider.update
  end

  it "should use 'apt-get remove' to uninstall" do
    expect(provider).to receive(:aptget).with("-y", "-q", :remove, name)
    expect(provider).to receive(:properties).and_return({:mark => :none})
    provider.uninstall
  end

  it "should use 'apt-get purge' and 'dpkg purge' to purge" do
    expect(provider).to receive(:aptget).with("-y", "-q", :remove, "--purge", name)
    expect(provider).to receive(:dpkg).with("--purge", name)
    expect(provider).to receive(:properties).and_return({:mark => :none})
    provider.purge
  end

  it "should use 'apt-cache policy' to determine the latest version of a package" do
    expect(provider).to receive(:aptcache).with(:policy, name).and_return(<<-HERE)
#{name}:
Installed: 1:1.0
Candidate: 1:1.1
Version table:
1:1.0
  650 http://ftp.osuosl.org testing/main Packages
*** 1:1.1
  100 /var/lib/dpkg/status
    HERE

    expect(provider.latest).to eq("1:1.1")
  end

  it "should print and error and return nil if no policy is found" do
    expect(provider).to receive(:aptcache).with(:policy, name).and_return("#{name}:")

    expect(provider).to receive(:err)
    expect(provider.latest).to be_nil
  end

  it "should be able to preseed" do
    expect(provider).to respond_to(:run_preseed)
  end

  it "should preseed with the provided responsefile when preseeding is called for" do
    resource[:responsefile] = '/my/file'
    expect(Puppet::FileSystem).to receive(:exist?).with('/my/file').and_return(true)

    expect(provider).to receive(:info)
    expect(provider).to receive(:preseed).with('/my/file')

    provider.run_preseed
  end

  it "should not preseed if no responsefile is provided" do
    expect(provider).to receive(:info)
    expect(provider).not_to receive(:preseed)

    provider.run_preseed
  end

  describe "when installing" do
    it "should preseed if a responsefile is provided" do
      resource[:responsefile] = "/my/file"
      expect(provider).to receive(:run_preseed)
      expect(provider).to receive(:properties).and_return({:mark => :none})
      allow(provider).to receive(:aptget)
      provider.install
    end

    it "should check for a cdrom" do
      expect(provider).to receive(:checkforcdrom)
      expect(provider).to receive(:properties).and_return({:mark => :none})
      allow(provider).to receive(:aptget)
      provider.install
    end

    it "should use 'apt-get install' with the package name if no version is asked for" do
      resource[:ensure] = :installed
      expect(provider).to receive(:aptget) do |*command|
        expect(command[-1]).to eq(name)
        expect(command[-2]).to eq(:install)
      end
      expect(provider).to receive(:properties).and_return({:mark => :none})

      provider.install
    end

    it "should specify the package version if one is asked for" do
      resource[:ensure] = '1.0'
      expect(provider).to receive(:aptget) do |*command|
        expect(command[-1]).to eq("#{name}=1.0")
      end
      expect(provider).to receive(:properties).and_return({:mark => :none})

      provider.install
    end

    it "should select latest available version if range is specified" do
      resource[:ensure] = '>72.0'
      expect(provider).to receive(:aptget) do |*command|
        expect(command[-1]).to eq("#{name}=72.0.1+build1-0ubuntu0.19.04.1")
      end
      expect(provider).to receive(:aptcache).with(:madison, name).and_return(<<-HERE)
   #{name} | 72.0.1+build1-0ubuntu0.19.04.1 | http://ro.archive.ubuntu.com/ubuntu disco-updates/main amd64 Packages
   #{name} | 72.0.1+build1-0ubuntu0.19.04.1 | http://security.ubuntu.com/ubuntu disco-security/main amd64 Packages
   #{name} | 66.0.3+build1-0ubuntu1 | http://ro.archive.ubuntu.com/ubuntu disco/main amd64 Packages
    HERE
      expect(provider).to receive(:properties).and_return({:mark => :none})

      provider.install
    end

    it "should pass through ensure is no version can be selected" do
      resource[:ensure] = '>74.0'
      expect(provider).to receive(:aptget) do |*command|
        expect(command[-1]).to eq("#{name}=>74.0")
      end
      expect(provider).to receive(:aptcache).with(:madison, name).and_return(<<-HERE)
   #{name} | 72.0.1+build1-0ubuntu0.19.04.1 | http://ro.archive.ubuntu.com/ubuntu disco-updates/main amd64 Packages
   #{name} | 72.0.1+build1-0ubuntu0.19.04.1 | http://security.ubuntu.com/ubuntu disco-security/main amd64 Packages
   #{name} | 66.0.3+build1-0ubuntu1 | http://ro.archive.ubuntu.com/ubuntu disco/main amd64 Packages
    HERE
      expect(provider).to receive(:properties).and_return({:mark => :none})

      provider.install
    end

    it "should use --force-yes if a package version is specified" do
      resource[:ensure] = '1.0'
      expect(provider).to receive(:aptget) do |*command|
        expect(command).to include("--force-yes")
      end
      expect(provider).to receive(:properties).and_return({:mark => :none})

      provider.install
    end

    it "should do a quiet install" do
      expect(provider).to receive(:aptget) do |*command|
        expect(command).to include("-q")
      end
      expect(provider).to receive(:properties).and_return({:mark => :none})

      provider.install
    end

    it "should default to 'yes' for all questions" do
      expect(provider).to receive(:aptget) do |*command|
        expect(command).to include("-y")
      end
      expect(provider).to receive(:properties).and_return({:mark => :none})

      provider.install
    end

    it "should keep config files if asked" do
      resource[:configfiles] = :keep
      expect(provider).to receive(:aptget) do |*command|
        expect(command).to include("DPkg::Options::=--force-confold")
      end
      expect(provider).to receive(:properties).and_return({:mark => :none})

      provider.install
    end

    it "should replace config files if asked" do
      resource[:configfiles] = :replace
      expect(provider).to receive(:aptget) do |*command|
        expect(command).to include("DPkg::Options::=--force-confnew")
      end
      expect(provider).to receive(:properties).and_return({:mark => :none})

      provider.install
    end

    it 'should support string install options' do
      resource[:install_options] = ['--foo', '--bar']
      expect(provider).to receive(:aptget).with('-q', '-y', '-o', 'DPkg::Options::=--force-confold', '--foo', '--bar', :install, name)
      expect(provider).to receive(:properties).and_return({:mark => :none})

      provider.install
    end

    it 'should support hash install options' do
      resource[:install_options] = ['--foo', { '--bar' => 'baz', '--baz' => 'foo' }]
      expect(provider).to receive(:aptget).with('-q', '-y', '-o', 'DPkg::Options::=--force-confold', '--foo', '--bar=baz', '--baz=foo', :install, name)
      expect(provider).to receive(:properties).and_return({:mark => :none})

      provider.install
    end
  end
end
