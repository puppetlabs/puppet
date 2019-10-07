require 'spec_helper'

describe Puppet::Type.type(:package).provider(:freebsd) do
  before :each do
    # Create a mock resource
    @resource = double('resource')

    # A catch all; no parameters set
    allow(@resource).to receive(:[]).and_return(nil)

    # But set name and source
    allow(@resource).to receive(:[]).with(:name).and_return("mypackage")
    allow(@resource).to receive(:[]).with(:ensure).and_return(:installed)

    @provider = subject()
    @provider.resource = @resource
  end

  it "should have an install method" do
    @provider = subject()
    expect(@provider).to respond_to(:install)
  end

  context "when installing" do
    before :each do
      allow(@resource).to receive(:should).with(:ensure).and_return(:installed)
    end

    it "should install a package from a path to a directory" do
      # For better or worse, trailing '/' is needed. --daniel 2011-01-26
      path = '/path/to/directory/'
      allow(@resource).to receive(:[]).with(:source).and_return(path)
      expect(Puppet::Util).to receive(:withenv).once.with({:PKG_PATH => path}).and_yield
      expect(@provider).to receive(:pkgadd).once.with("mypackage")

      expect { @provider.install }.to_not raise_error
    end

    %w{http https ftp}.each do |protocol|
      it "should install a package via #{protocol}" do
        # For better or worse, trailing '/' is needed. --daniel 2011-01-26
        path = "#{protocol}://localhost/"
        allow(@resource).to receive(:[]).with(:source).and_return(path)
        expect(Puppet::Util).to receive(:withenv).once.with({:PACKAGESITE => path}).and_yield
        expect(@provider).to receive(:pkgadd).once.with('-r', "mypackage")

        expect { @provider.install }.to_not raise_error
      end
    end
  end
end
