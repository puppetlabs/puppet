require 'spec_helper'
require 'puppet/module_tool/installed_modules'
require 'puppet_spec/modules'

describe Puppet::ModuleTool::InstalledModules do
  include PuppetSpec::Files

  around do |example|
    dir = tmpdir("deep_path")

    FileUtils.mkdir_p(@modpath = File.join(dir, "modpath"))

    @env = Puppet::Node::Environment.create(:env, [@modpath])
    Puppet.override(:current_environment => @env) do
      example.run
    end
  end

  it 'works when given a semantic version' do
    mod = PuppetSpec::Modules.create('goodsemver', @modpath, :metadata => {:version => '1.2.3'})
    installed = described_class.new(@env)
    expect(installed.modules["puppetlabs-#{mod.name}"].version).to eq(Semantic::Version.parse('1.2.3'))
  end

  it 'defaults when not given a semantic version' do
    mod = PuppetSpec::Modules.create('badsemver', @modpath, :metadata => {:version => 'banana'})
    Puppet.expects(:warning).with(regexp_matches(/Semantic Version/))
    installed = described_class.new(@env)
    expect(installed.modules["puppetlabs-#{mod.name}"].version).to eq(Semantic::Version.parse('0.0.0'))
  end

  it 'defaults when not given a full semantic version' do
    mod = PuppetSpec::Modules.create('badsemver', @modpath, :metadata => {:version => '1.2'})
    Puppet.expects(:warning).with(regexp_matches(/Semantic Version/))
    installed = described_class.new(@env)
    expect(installed.modules["puppetlabs-#{mod.name}"].version).to eq(Semantic::Version.parse('0.0.0'))
  end

  it 'still works if there is an invalid version in one of the modules' do
    mod1 = PuppetSpec::Modules.create('badsemver', @modpath, :metadata => {:version => 'banana'})
    mod2 = PuppetSpec::Modules.create('goodsemver', @modpath, :metadata => {:version => '1.2.3'})
    mod3 = PuppetSpec::Modules.create('notquitesemver', @modpath, :metadata => {:version => '1.2'})
    Puppet.expects(:warning).with(regexp_matches(/Semantic Version/)).twice
    installed = described_class.new(@env)
    expect(installed.modules["puppetlabs-#{mod1.name}"].version).to eq(Semantic::Version.parse('0.0.0'))
    expect(installed.modules["puppetlabs-#{mod2.name}"].version).to eq(Semantic::Version.parse('1.2.3'))
    expect(installed.modules["puppetlabs-#{mod3.name}"].version).to eq(Semantic::Version.parse('0.0.0'))
  end
end
