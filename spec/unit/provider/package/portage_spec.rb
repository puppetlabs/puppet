#! /usr/bin/env ruby

require 'spec_helper'

provider = Puppet::Type.type(:package).provider(:portage)

describe provider do
  before do
    packagename="sl"
    @resource = stub('resource', :should => true)
    @resource.stubs(:[]).with(:name).returns(packagename)
    @resource.stubs(:[]).with(:install_options).returns(['--foo', '--bar'])
    @resource.stubs(:[]).with(:uninstall_options).returns(['--foo', { '--bar' => 'baz', '--baz' => 'foo' }])

    unslotted_packagename = "dev-lang/ruby"
    @unslotted_resource = stub('resource', :should => true)
    @unslotted_resource.stubs(:should).with(:ensure).returns :latest
    @unslotted_resource.stubs(:[]).with(:name).returns(unslotted_packagename)
    @unslotted_resource.stubs(:[]).with(:install_options).returns([])

    slotted_packagename = "dev-lang/ruby:2.1"
    @slotted_resource = stub('resource', :should => true)
    @slotted_resource.stubs(:[]).with(:name).returns(slotted_packagename)
    @slotted_resource.stubs(:[]).with(:install_options).returns(['--foo', { '--bar' => 'baz', '--baz' => 'foo' }])

    versioned_packagename = "dev-lang/ruby-1.9.3"
    @versioned_resource = stub('resource', :should => true)
    @versioned_resource.stubs(:[]).with(:name).returns(versioned_packagename)
    @versioned_resource.stubs(:[]).with(:uninstall_options).returns([])

    versioned_slotted_packagename = "=dev-lang/ruby-1.9.3:1.9"
    @versioned_slotted_resource = stub('resource', :should => true)
    @versioned_slotted_resource.stubs(:[]).with(:name).returns(versioned_slotted_packagename)
    @versioned_slotted_resource.stubs(:[]).with(:uninstall_options).returns([])

    set_packagename = "@system"
    @set_resource = stub('resource', :should => true)
    @set_resource.stubs(:[]).with(:name).returns(set_packagename)
    @set_resource.stubs(:[]).with(:install_options).returns([])

    package_sets = "system\nworld\n"
    @provider = provider.new(@resource)
    @provider.stubs(:qatom).returns({:category=>nil, :pn=>"sl", :pv=>nil, :pr=>nil, :slot=>nil, :pfx=>nil, :sfx=>nil})
    @provider.class.stubs(:emerge).with('--list-sets').returns(package_sets)
    @unslotted_provider = provider.new(@unslotted_resource)
    @unslotted_provider.stubs(:qatom).returns({:category=>"dev-lang", :pn=>"ruby", :pv=>nil, :pr=>nil, :slot=>nil, :pfx=>nil, :sfx=>nil})
    @unslotted_provider.class.stubs(:emerge).with('--list-sets').returns(package_sets)
    @slotted_provider = provider.new(@slotted_resource)
    @slotted_provider.stubs(:qatom).returns({:category=>"dev-lang", :pn=>"ruby", :pv=>nil, :pr=>nil, :slot=>":2.1", :pfx=>nil, :sfx=>nil})
    @slotted_provider.class.stubs(:emerge).with('--list-sets').returns(package_sets)
    @versioned_provider = provider.new(@versioned_resource)
    @versioned_provider.stubs(:qatom).returns({:category=>"dev-lang", :pn=>"ruby", :pv=>"1.9.3", :pr=>nil, :slot=>nil, :pfx=>nil, :sfx=>nil})
    @versioned_provider.class.stubs(:emerge).with('--list-sets').returns(package_sets)
    @versioned_slotted_provider = provider.new(@versioned_slotted_resource)
    @versioned_slotted_provider.stubs(:qatom).returns({:category=>"dev-lang", :pn=>"ruby", :pv=>"1.9.3", :pr=>nil, :slot=>":1.9", :pfx=>"=", :sfx=>nil})
    @versioned_slotted_provider.class.stubs(:emerge).with('--list-sets').returns(package_sets)
    @set_provider = provider.new(@set_resource)
    @set_provider.stubs(:qatom).returns({:category=>nil, :pn=>"@system", :pv=>nil, :pr=>nil, :slot=>nil, :pfx=>nil, :sfx=>nil})
    @set_provider.class.stubs(:emerge).with('--list-sets').returns(package_sets)

    portage   = stub(:executable => "foo",:execute => true)
    Puppet::Provider::CommandDefiner.stubs(:define).returns(portage)

    @nomatch_result = ""
    @match_result    = "app-misc sl [] [5.02] [] [] [5.02] [5.02:0] http://www.tkl.iis.u-tokyo.ac.jp/~toyoda/index_e.html https://github.com/mtoyoda/sl/ sophisticated graphical program which corrects your miss typing\n"
    @slot_match_result = "dev-lang ruby [2.1.8] [2.1.9] [2.1.8:2.1] [2.1.8] [2.1.9,,,,,,,] [2.1.9:2.1] http://www.ruby-lang.org/ An object-oriented scripting language\n"
  end

  it "is versionable" do
    expect(provider).to be_versionable
  end

  it "is reinstallable" do
    expect(provider).to be_reinstallable
  end

  it 'should support string install options' do
    @provider.expects(:emerge).with('--foo', '--bar', @resource[:name])

    @provider.install
  end

  it 'should support updating' do
    @unslotted_provider.expects(:emerge).with('--update', @unslotted_resource[:name])

    @unslotted_provider.install
  end

  it 'should support hash install options' do
    @slotted_provider.expects(:emerge).with('--foo', '--bar=baz', '--baz=foo', @slotted_resource[:name])

    @slotted_provider.install
  end

  it 'should support hash uninstall options' do
    @provider.expects(:emerge).with('--rage-clean', '--foo', '--bar=baz', '--baz=foo', @resource[:name])

    @provider.uninstall
  end

  it 'should support uninstall of specific version' do
    @versioned_provider.expects(:emerge).with('--rage-clean', @versioned_resource[:name])

    @versioned_provider.uninstall
  end

  it 'should support uninstall of specific version and slot' do
    @versioned_slotted_provider.expects(:emerge).with('--rage-clean', @versioned_slotted_resource[:name])

    @versioned_slotted_provider.uninstall
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

  it "allows to emerge package sets" do
    @set_provider.expects(:emerge).with(@set_resource[:name])

    @set_provider.install
  end

  it "allows to emerge and update package sets" do
    @set_resource.stubs(:should).with(:ensure).returns :latest
    @set_provider.expects(:emerge).with('--update', @set_resource[:name])

    @set_provider.install
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

  it "can provide the package name without slot" do
    expect(@unslotted_provider.qatom[:slot]).to be_nil
  end

  it "can extract the slot from the package name" do
    expect(@slotted_provider.qatom[:slot]).to eq(':2.1')
  end

  it "returns nil for as the slot when no slot is specified" do
    expect(@provider.qatom[:slot]).to be_nil
  end

  it "provides correct package atoms for unslotted packages" do
    expect(@versioned_provider.qatom[:pv]).to eq('1.9.3')
  end

  it "provides correct package atoms for slotted packages" do
    expect(@versioned_slotted_provider.qatom[:pfx]).to eq('=')
    expect(@versioned_slotted_provider.qatom[:category]).to eq('dev-lang')
    expect(@versioned_slotted_provider.qatom[:pn]).to eq('ruby')
    expect(@versioned_slotted_provider.qatom[:pv]).to eq('1.9.3')
    expect(@versioned_slotted_provider.qatom[:slot]).to eq(':1.9')
  end

  it "can handle search output with slots for unslotted packages" do
    @unslotted_provider.stubs(:update_eix)
    @unslotted_provider.expects(:eix).returns(StringIO.new(@slot_match_result))

    result = @unslotted_provider.query
    expect(result[:name]).to eq('ruby')
    expect(result[:ensure]).to eq('2.1.8')
    expect(result[:version_available]).to eq('2.1.9')
  end

  it "can handle search output with slots" do
    @slotted_provider.stubs(:update_eix)
    @slotted_provider.expects(:eix).returns(StringIO.new(@slot_match_result))

    result = @slotted_provider.query
    expect(result[:name]).to eq('ruby')
    expect(result[:ensure]).to eq('2.1.8')
    expect(result[:version_available]).to eq('2.1.9')
  end
end
