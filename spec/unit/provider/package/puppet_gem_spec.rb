require 'spec_helper'

describe Puppet::Type.type(:package).provider(:puppet_gem) do
  let(:resource) do
    Puppet::Type.type(:package).new(
      :name     => "myresource",
      :ensure   => :installed
    )
  end

  let(:provider) do
    provider = described_class.new
    provider.resource = resource
    provider
  end

  if Puppet.features.microsoft_windows?
    let(:puppet_gem) { "gem.bat" }
  else
    let(:puppet_gem) { "/opt/puppetlabs/puppet/bin/gem" }
  end

  before :each do
    resource.provider = provider
  end

  context "when installing" do
    before :each do
      described_class.stubs(:command).with(:gemcmd).returns puppet_gem
      described_class.stubs(:validate_package_command).with(puppet_gem).returns puppet_gem
      provider.stubs(:rubygem_version).with(:gemcmd).returns "1.9.9"
    end

    it "should use the path to the gem" do
      described_class.expects(:execute_gem_command).with(:gemcmd, any_parameters).returns ""
      provider.install
    end

    it "should not append install_options by default" do
      described_class.expects(:execute_gem_command).with(:gemcmd, ["install", "--no-rdoc", "--no-ri", "myresource"]).returns ""
      provider.install
    end

    it "should allow setting an install_options parameter" do
      resource[:install_options] = [ "--force", {"--bindir" => "/usr/bin" } ]
      described_class.expects(:execute_gem_command).with(:gemcmd, ["install", "--force", "--bindir=/usr/bin", "--no-rdoc", "--no-ri", "myresource"]).returns ""
      provider.install
    end
  end

  context "when uninstalling" do
    before :each do
      described_class.stubs(:command).with(:gemcmd).returns puppet_gem
      described_class.stubs(:validate_package_command).with(puppet_gem).returns puppet_gem
      provider.stubs(:rubygem_version).with(:gemcmd).returns "1.9.9"
    end

    it "should use the path to the gem" do
      described_class.expects(:execute_gem_command).with(:gemcmd, any_parameters).returns ""
      provider.uninstall
    end

    it "should not append uninstall_options by default" do
      described_class.expects(:execute_gem_command).with(:gemcmd, ["uninstall", "--executables", "--all", "myresource"]).returns ""
      provider.uninstall
    end

    it "should allow setting an uninstall_options parameter" do
      resource[:uninstall_options] = [ "--ignore-dependencies", {"--version" => "0.1.1" } ]
      described_class.expects(:execute_gem_command).with(:gemcmd, ["uninstall", "--executables", "--all", "myresource", "--ignore-dependencies", "--version=0.1.1"]).returns ""
      provider.uninstall
    end
  end
end
