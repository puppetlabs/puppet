require 'spec_helper'

describe Puppet::Type.type(:package).provider(:hpux) do
  before(:each) do
    # Create a mock resource
    @resource = double('resource')

    # A catch all; no parameters set
    allow(@resource).to receive(:[]).and_return(nil)

    # But set name and source
    allow(@resource).to receive(:[]).with(:name).and_return("mypackage")
    allow(@resource).to receive(:[]).with(:source).and_return("mysource")
    allow(@resource).to receive(:[]).with(:ensure).and_return(:installed)

    @provider = subject()
    allow(@provider).to receive(:resource).and_return(@resource)
  end

  it "should have an install method" do
    @provider = subject()
    expect(@provider).to respond_to(:install)
  end

  it "should have an uninstall method" do
    @provider = subject()
    expect(@provider).to respond_to(:uninstall)
  end

  it "should have a swlist method" do
    @provider = subject()
    expect(@provider).to respond_to(:swlist)
  end

  context "when installing" do
    it "should use a command-line like 'swinstall -x mount_all_filesystems=false -s SOURCE PACKAGE-NAME'" do
      expect(@provider).to receive(:swinstall).with('-x', 'mount_all_filesystems=false', '-s', 'mysource', 'mypackage')
      @provider.install
    end
  end

  context "when uninstalling" do
    it "should use a command-line like 'swremove -x mount_all_filesystems=false PACKAGE-NAME'" do
      expect(@provider).to receive(:swremove).with('-x', 'mount_all_filesystems=false', 'mypackage')
      @provider.uninstall
    end
  end
end
