require "spec_helper"
require "stringio"

describe Puppet::Type.type(:package).provider(:xbps) do
  before do
    @resource = Puppet::Type.type(:package).new(name: "gcc", provider: "xbps")
    @provider = described_class.new(@resource)
    @resolver = Puppet::Util

    allow(described_class).to receive(:which).with("/usr/bin/xbps-install").and_return("/usr/bin/xbps-install")
    allow(described_class).to receive(:which).with("/usr/bin/xbps-remove").and_return("/usr/bin/xbps-remove")
    allow(described_class).to receive(:which).with("/usr/bin/xbps-query").and_return("/usr/bin/xbps-query")
  end

  it { is_expected.to be_installable }
  it { is_expected.to be_uninstallable }
  it { is_expected.to be_install_options }
  it { is_expected.to be_uninstall_options }
  it { is_expected.to be_upgradeable }
  it { is_expected.to be_holdable }
  it { is_expected.to be_virtual_packages }

  it "should be the default provider on 'os.name' => Void" do
    expect(Facter).to receive(:value).with('os.name').and_return("Void")
    expect(described_class.default?).to be_truthy
  end

  describe "when determining instances" do
    it "should return installed packages" do
      sample_installed_packages = %{
ii gcc-12.2.0_1                            GNU Compiler Collection
ii ruby-devel-3.1.3_1                      Ruby programming language - development files
}

      expect(described_class).to receive(:execpipe).with(["/usr/bin/xbps-query", "-l"])
                                   .and_yield(StringIO.new(sample_installed_packages))

      instances = described_class.instances
      expect(instances.length).to eq(2)

      expect(instances[0].properties).to eq({
        :name => "gcc",
        :ensure => "12.2.0_1",
        :provider => :xbps,
      })

      expect(instances[1].properties).to eq({
        :name => "ruby-devel",
        :ensure => "3.1.3_1",
        :provider => :xbps,
      })
    end

    it "should warn on invalid input" do
      expect(described_class).to receive(:execpipe).and_yield(StringIO.new("blah"))
      expect(described_class).to receive(:warning).with('Failed to match line \'blah\'')
      expect(described_class.instances).to eq([])
    end
  end

  describe "when installing" do
    it "and install_options are given it should call xbps to install the package quietly with the passed options" do
      @resource[:install_options] = ["-x", { "--arg" => "value" }]
      args = ["-S", "-y", "-x", "--arg=value", @resource[:name]]
      expect(@provider).to receive(:xbps_install).with(*args).and_return("")
      expect(described_class).to receive(:execpipe).with(["/usr/bin/xbps-query", "-l"])

      @provider.install
    end

    it "and source is given it should call xbps to install the package from the source as repository" do
      @resource[:source] = "/path/to/xbps/containing/directory"
      args = ["-S", "-y", "--repository=#{@resource[:source]}", @resource[:name]]
      expect(@provider).to receive(:xbps_install).at_least(:once).with(*args).and_return("")
      expect(described_class).to receive(:execpipe).with(["/usr/bin/xbps-query", "-l"])

      @provider.install
    end
  end

  describe "when updating" do
    it "should call install" do
      expect(@provider).to receive(:install).and_return("ran install")
      expect(@provider.update).to eq("ran install")
    end
  end

  describe "when uninstalling" do
    it "should call xbps to remove the right package quietly" do
      args = ["-R", "-y", @resource[:name]]
      expect(@provider).to receive(:xbps_remove).with(*args).and_return("")
      @provider.uninstall
    end

    it "adds any uninstall_options" do
      @resource[:uninstall_options] = ["-x", { "--arg" => "value" }]
      args = ["-R", "-y", "-x", "--arg=value", @resource[:name]]
      expect(@provider).to receive(:xbps_remove).with(*args).and_return("")
      @provider.uninstall
    end
  end

  describe "when determining the latest version" do
    it "should return the latest version number of the package" do
      @resource[:name] = "ruby-devel"

      expect(described_class).to receive(:execpipe).with(["/usr/bin/xbps-query", "-l"]).and_yield(StringIO.new(%{
ii ruby-devel-3.1.3_1                      Ruby programming language - development files
}))

      expect(@provider.latest).to eq("3.1.3_1")
    end
  end

  describe "when querying" do
    it "should call self.instances and return nil if the package is missing" do
      expect(described_class).to receive(:instances)
                                   .and_return([])

      expect(@provider.query).to be_nil
    end

    it "should get real-package in case allow_virtual is true" do
      @resource[:name] = "nodejs-runtime"
      @resource[:allow_virtual] = true

      expect(described_class).to receive(:execpipe).with(["/usr/bin/xbps-query", "-l"])
                                   .and_yield(StringIO.new(""))

      args = ["-Rs", @resource[:name]]
      expect(@provider).to receive(:xbps_query).with(*args).and_return(%{
[*] nodejs-16.19.0_1      Evented I/O for V8 javascript
[-] nodejs-lts-12.22.10_2 Evented I/O for V8 javascript'
})

      expect(@provider.query).to eq({
        :name => "nodejs",
        :ensure => "16.19.0_1",
        :provider => :xbps,
      })
    end
  end
end
