require 'spec_helper'

describe Puppet::Type.type(:package).provider(:portage) do
  before do
    packagename = "sl"
    @resource = double('resource', :should => true)
    allow(@resource).to receive(:[]).with(:name).and_return(packagename)
    allow(@resource).to receive(:[]).with(:install_options).and_return(['--foo', '--bar'])
    allow(@resource).to receive(:[]).with(:uninstall_options).and_return(['--foo', { '--bar' => 'baz', '--baz' => 'foo' }])

    unslotted_packagename = "dev-lang/ruby"
    @unslotted_resource = double('resource', :should => true)
    allow(@unslotted_resource).to receive(:should).with(:ensure).and_return(:latest)
    allow(@unslotted_resource).to receive(:[]).with(:name).and_return(unslotted_packagename)
    allow(@unslotted_resource).to receive(:[]).with(:install_options).and_return([])

    slotted_packagename = "dev-lang/ruby:2.1"
    @slotted_resource = double('resource', :should => true)
    allow(@slotted_resource).to receive(:[]).with(:name).and_return(slotted_packagename)
    allow(@slotted_resource).to receive(:[]).with(:install_options).and_return(['--foo', { '--bar' => 'baz', '--baz' => 'foo' }])

    versioned_packagename = "=dev-lang/ruby-1.9.3"
    @versioned_resource = double('resource', :should => true)
    allow(@versioned_resource).to receive(:[]).with(:name).and_return(versioned_packagename)
    allow(@versioned_resource).to receive(:[]).with(:install_options).and_return([])
    allow(@versioned_resource).to receive(:[]).with(:uninstall_options).and_return([])

    versioned_slotted_packagename = "=dev-lang/ruby-1.9.3:1.9"
    @versioned_slotted_resource = double('resource', :should => true)
    allow(@versioned_slotted_resource).to receive(:[]).with(:name).and_return(versioned_slotted_packagename)
    allow(@versioned_slotted_resource).to receive(:[]).with(:install_options).and_return([])
    allow(@versioned_slotted_resource).to receive(:[]).with(:uninstall_options).and_return([])

    set_packagename = "@system"
    @set_resource = double('resource', :should => true)
    allow(@set_resource).to receive(:[]).with(:name).and_return(set_packagename)
    allow(@set_resource).to receive(:[]).with(:install_options).and_return([])

    package_sets = "system\nworld\n"
    @provider = described_class.new(@resource)
    allow(@provider).to receive(:qatom).and_return({:category=>nil, :pn=>"sl", :pv=>nil, :pr=>nil, :slot=>nil, :pfx=>nil, :sfx=>nil})
    allow(@provider.class).to receive(:emerge).with('--list-sets').and_return(package_sets)
    @unslotted_provider = described_class.new(@unslotted_resource)
    allow(@unslotted_provider).to receive(:qatom).and_return({:category=>"dev-lang", :pn=>"ruby", :pv=>nil, :pr=>nil, :slot=>nil, :pfx=>nil, :sfx=>nil})
    allow(@unslotted_provider.class).to receive(:emerge).with('--list-sets').and_return(package_sets)
    @slotted_provider = described_class.new(@slotted_resource)
    allow(@slotted_provider).to receive(:qatom).and_return({:category=>"dev-lang", :pn=>"ruby", :pv=>nil, :pr=>nil, :slot=>"2.1", :pfx=>nil, :sfx=>nil})
    allow(@slotted_provider.class).to receive(:emerge).with('--list-sets').and_return(package_sets)
    @versioned_provider = described_class.new(@versioned_resource)
    allow(@versioned_provider).to receive(:qatom).and_return({:category=>"dev-lang", :pn=>"ruby", :pv=>"1.9.3", :pr=>nil, :slot=>nil, :pfx=>"=", :sfx=>nil})
    allow(@versioned_provider.class).to receive(:emerge).with('--list-sets').and_return(package_sets)
    @versioned_slotted_provider = described_class.new(@versioned_slotted_resource)
    allow(@versioned_slotted_provider).to receive(:qatom).and_return({:category=>"dev-lang", :pn=>"ruby", :pv=>"1.9.3", :pr=>nil, :slot=>"1.9", :pfx=>"=", :sfx=>nil})
    allow(@versioned_slotted_provider.class).to receive(:emerge).with('--list-sets').and_return(package_sets)
    @set_provider = described_class.new(@set_resource)
    allow(@set_provider).to receive(:qatom).and_return({:category=>nil, :pn=>"@system", :pv=>nil, :pr=>nil, :slot=>nil, :pfx=>nil, :sfx=>nil})
    allow(@set_provider.class).to receive(:emerge).with('--list-sets').and_return(package_sets)

    portage   = double(:executable => "foo",:execute => true)
    allow(Puppet::Provider::CommandDefiner).to receive(:define).and_return(portage)

    @nomatch_result = ""
    @match_result    = "app-misc sl [] [5.02] [] [] [5.02] [5.02:0] http://www.tkl.iis.u-tokyo.ac.jp/~toyoda/index_e.html https://github.com/mtoyoda/sl/ sophisticated graphical program which corrects your miss typing\n"
    @slot_match_result = "dev-lang ruby [2.1.8] [2.1.9] [2.1.8:2.1] [2.1.8] [2.1.9,,,,,,,] [2.1.9:2.1] http://www.ruby-lang.org/ An object-oriented scripting language\n"
  end

  it "is versionable" do
    expect(described_class).to be_versionable
  end

  it "is reinstallable" do
    expect(described_class).to be_reinstallable
  end

  it "should be the default provider on :osfamily => Gentoo" do
    expect(Facter).to receive(:value).with(:osfamily).and_return("Gentoo")
    expect(described_class.default?).to be_truthy
  end

  it 'should support string install options' do
    expect(@provider).to receive(:emerge).with('--foo', '--bar', @resource[:name])

    @provider.install
  end

  it 'should support updating' do
    expect(@unslotted_provider).to receive(:emerge).with('--update', @unslotted_resource[:name])

    @unslotted_provider.install
  end

  it 'should support hash install options' do
    expect(@slotted_provider).to receive(:emerge).with('--foo', '--bar=baz', '--baz=foo', @slotted_resource[:name])

    @slotted_provider.install
  end

  it 'should support hash uninstall options' do
    expect(@provider).to receive(:emerge).with('--rage-clean', '--foo', '--bar=baz', '--baz=foo', @resource[:name])

    @provider.uninstall
  end

  it 'should support install of specific version' do
    expect(@versioned_provider).to receive(:emerge).with(@versioned_resource[:name])

    @versioned_provider.install
  end

  it 'should support install of specific version and slot' do
    expect(@versioned_slotted_provider).to receive(:emerge).with(@versioned_slotted_resource[:name])

    @versioned_slotted_provider.install
  end

  it 'should support uninstall of specific version' do
    expect(@versioned_provider).to receive(:emerge).with('--rage-clean', @versioned_resource[:name])

    @versioned_provider.uninstall
  end

  it 'should support uninstall of specific version and slot' do
    expect(@versioned_slotted_provider).to receive(:emerge).with('--rage-clean', @versioned_slotted_resource[:name])

    @versioned_slotted_provider.uninstall
  end

  it "uses :emerge to install packages" do
    expect(@provider).to receive(:emerge)

    @provider.install
  end

  it "uses query to find the latest package" do
    expect(@provider).to receive(:query).and_return({:versions_available => "myversion"})

    @provider.latest
  end

  it "uses eix to search the lastest version of a package" do
    allow(@provider).to receive(:update_eix)
    expect(@provider).to receive(:eix).and_return(StringIO.new(@match_result))

    @provider.query
  end

  it "allows to emerge package sets" do
    expect(@set_provider).to receive(:emerge).with(@set_resource[:name])

    @set_provider.install
  end

  it "allows to emerge and update package sets" do
    allow(@set_resource).to receive(:should).with(:ensure).and_return(:latest)
    expect(@set_provider).to receive(:emerge).with('--update', @set_resource[:name])

    @set_provider.install
  end

  it "eix arguments must not include --stable" do
    expect(@provider.class.eix_search_arguments).not_to include("--stable")
  end

  it "eix arguments must not include --exact" do
    expect(@provider.class.eix_search_arguments).not_to include("--exact")
  end

  it "query uses default arguments" do
    allow(@provider).to receive(:update_eix)
    expect(@provider).to receive(:eix).and_return(StringIO.new(@match_result))
    expect(@provider.class).to receive(:eix_search_arguments).and_return([])

    @provider.query
  end

  it "can handle search output with empty square brackets" do
    allow(@provider).to receive(:update_eix)
    expect(@provider).to receive(:eix).and_return(StringIO.new(@match_result))

    expect(@provider.query[:name]).to eq("sl")
  end

  it "can provide the package name without slot" do
    expect(@unslotted_provider.qatom[:slot]).to be_nil
  end

  it "can extract the slot from the package name" do
    expect(@slotted_provider.qatom[:slot]).to eq('2.1')
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
    expect(@versioned_slotted_provider.qatom[:slot]).to eq('1.9')
  end

  it "can handle search output with slots for unslotted packages" do
    allow(@unslotted_provider).to receive(:update_eix)
    expect(@unslotted_provider).to receive(:eix).and_return(StringIO.new(@slot_match_result))

    result = @unslotted_provider.query
    expect(result[:name]).to eq('ruby')
    expect(result[:ensure]).to eq('2.1.8')
    expect(result[:version_available]).to eq('2.1.9')
  end

  it "can handle search output with slots" do
    allow(@slotted_provider).to receive(:update_eix)
    expect(@slotted_provider).to receive(:eix).and_return(StringIO.new(@slot_match_result))

    result = @slotted_provider.query
    expect(result[:name]).to eq('ruby')
    expect(result[:ensure]).to eq('2.1.8')
    expect(result[:version_available]).to eq('2.1.9')
  end
end
