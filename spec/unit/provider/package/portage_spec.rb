#! /usr/bin/env ruby

require 'spec_helper'

provider = Puppet::Type.type(:package).provider(:portage)

describe provider do
  before do
    packagename="sl"
    @resource = stub('resource', :should => true)
    @resource.stubs(:[]).with(:name).returns(packagename)
    @resource.stubs(:[]).with(:category).returns(nil)

    unslotted_packagename = "dev-lang/ruby"
    @unslotted_resource = stub('resource', :should => true)
    @unslotted_resource.stubs(:[]).with(:name).returns(unslotted_packagename)
    @unslotted_resource.stubs(:[]).with(:category).returns(nil)

    slotted_packagename = "dev-lang/ruby:1.9"
    @slotted_resource = stub('resource', :should => true)
    @slotted_resource.stubs(:[]).with(:name).returns(slotted_packagename)
    @slotted_resource.stubs(:[]).with(:category).returns(nil)

    @provider = provider.new(@resource)
    @unslotted_provider = provider.new(@unslotted_resource)
    @slotted_provider = provider.new(@slotted_resource)

    portage   = stub(:executable => "foo",:execute => true)
    Puppet::Provider::CommandDefiner.stubs(:define).returns(portage)

    @nomatch_result = ""
    @match_result   = "app-misc sl [] [] [] [] http://www.tkl.iis.u-tokyo.ac.jp/~toyoda/index_e.html http://www.izumix.org.uk/sl/ sophisticated graphical program which corrects your miss typing\n"
    @slot_match_result = "dev-lang ruby [2.0.0] [2.1.0] [1.8.7:1.8,1.9.2:1.9,2.0.0:2.0] [1.9.3:1.9,2.0.1:2.0,2.1.0:2.1] http://www.ruby-lang.org/ An object-oriented scripting language\n"
  end

  it "is versionable" do
    provider.should be_versionable
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
    @provider.class.eix_search_arguments.should_not include("--stable")
  end

  it "eix arguments must not include --exact" do
    @provider.class.eix_search_arguments.should_not include("--exact")
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

    @provider.query[:name].should eq("sl")
  end

  it "can provide the package name without slot" do
    @slotted_provider.package_name_without_slot.should eq("dev-lang/ruby")
  end

  it "can extract the slot from the package name" do
    @slotted_provider.package_slot.should eq("1.9")
  end

  it "returns nil for as the slot when no slot is specified" do
    @provider.package_slot.should be_nil
  end

  it "provides correct package atoms for unslotted packages" do
    @provider.package_atom_with_version("1.0").should eq("=sl-1.0")
  end

  it "provides correct package atoms for slotted packages" do
    @slotted_provider.package_atom_with_version("1.9.3").should eq("=dev-lang/ruby-1.9.3:1.9")
  end

  it "can handle search output with slots for unslotted packages" do
    @unslotted_provider.stubs(:update_eix)
    @unslotted_provider.expects(:eix).returns(StringIO.new(@slot_match_result))

    result = @unslotted_provider.query
    result[:name].should eq("ruby")
    result[:ensure].should eq("2.0.0")
    result[:version_available].should eq("2.1.0")
  end

  it "can handle search output with slots" do
    @slotted_provider.stubs(:update_eix)
    @slotted_provider.expects(:eix).returns(StringIO.new(@slot_match_result))

    result = @slotted_provider.query
    result[:name].should eq("ruby")
    result[:ensure].should eq("1.9.2")
    result[:version_available].should eq("1.9.3")
  end
end
