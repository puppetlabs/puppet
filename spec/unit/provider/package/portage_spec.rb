#! /usr/bin/env ruby

require 'spec_helper'

provider = Puppet::Type.type(:package).provider(:portage)

describe provider do
  before do
    packagename="sl"
    @resource = stub('resource', :[] => packagename,:should => true)
    @provider = provider.new(@resource)
    
    portage   = stub(:executable => "foo",:execute => true)
    Puppet::Provider::CommandDefiner.stubs(:define).returns(portage)

    @nomatch_result = ""
    @match_result   = "app-misc sl [] [] http://www.tkl.iis.u-tokyo.ac.jp/~toyoda/index_e.html http://www.izumix.org.uk/sl/ sophisticated graphical program which corrects your miss typing\n"
  end

  it "is versionable" do
    expect(provider).to be_versionable
  end

  it "is reinstallable" do
    expect(provider).to be_reinstallable
  end

  it "uses :emerge to install packages" do
    @provider.expects(:emerge)
    
    @provider.install
  end

  it "uses query to find the latest package" do
    @provider.expects(:query).returns({:versions_available => "myversion"})
    
    @provider.latest
  end

  it "uses eix to search the lastest version of a package" do
    @provider.stubs(:update_eix)
    @provider.expects(:eix).returns(StringIO.new(@match_result))
    
    @provider.query
  end

  it "eix arguments must not include --stable" do
    expect(@provider.class.eix_search_arguments).not_to include("--stable")
  end

  it "eix arguments must not include --exact" do
    expect(@provider.class.eix_search_arguments).not_to include("--exact")
  end

  it "query uses default arguments" do
    @provider.stubs(:update_eix)
    @provider.expects(:eix).returns(StringIO.new(@match_result))
    @provider.class.expects(:eix_search_arguments).returns([])
    
    @provider.query
  end

  it "can handle search output with empty square brackets" do
    @provider.stubs(:update_eix)
    @provider.expects(:eix).returns(StringIO.new(@match_result))
    
    expect(@provider.query[:name]).to eq("sl")
  end
end
