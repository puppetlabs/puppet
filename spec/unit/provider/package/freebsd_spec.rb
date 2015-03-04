#! /usr/bin/env ruby
require 'spec_helper'

provider_class = Puppet::Type.type(:package).provider(:freebsd)

describe provider_class do
  before :each do
    # Create a mock resource
    @resource = stub 'resource'

    # A catch all; no parameters set
    @resource.stubs(:[]).returns(nil)

    # But set name and source
    @resource.stubs(:[]).with(:name).returns   "mypackage"
    @resource.stubs(:[]).with(:ensure).returns :installed

    @provider = provider_class.new
    @provider.resource = @resource
  end

  it "should have an install method" do
    @provider = provider_class.new
    expect(@provider).to respond_to(:install)
  end

  describe "when installing" do
    before :each do
      @resource.stubs(:should).with(:ensure).returns(:installed)
    end

    it "should install a package from a path to a directory" do
      # For better or worse, trailing '/' is needed. --daniel 2011-01-26
      path = '/path/to/directory/'
      @resource.stubs(:[]).with(:source).returns(path)
      Puppet::Util.expects(:withenv).once.with({:PKG_PATH => path}).yields
      @provider.expects(:pkgadd).once.with("mypackage")

      expect { @provider.install }.to_not raise_error
    end

    %w{http https ftp}.each do |protocol|
      it "should install a package via #{protocol}" do
        # For better or worse, trailing '/' is needed. --daniel 2011-01-26
        path = "#{protocol}://localhost/"
        @resource.stubs(:[]).with(:source).returns(path)
        Puppet::Util.expects(:withenv).once.with({:PACKAGESITE => path}).yields
        @provider.expects(:pkgadd).once.with('-r', "mypackage")

        expect { @provider.install }.to_not raise_error
      end
    end
  end
end
