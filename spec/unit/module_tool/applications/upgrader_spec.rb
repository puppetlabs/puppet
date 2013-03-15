require 'spec_helper'
require 'puppet/module_tool/applications'
require 'puppet_spec/modules'
require 'semver'

describe Puppet::ModuleTool::Applications::Upgrader do
  include PuppetSpec::Files

  let(:unpacker)       { stub(:run) }
  let(:upgrader_class) { Puppet::ModuleTool::Applications::Upgrader }
  let(:modpath)        { File.join(tmpdir('upgrader'), 'modpath') }
  let(:fake_env)       { Puppet::Node::Environment.new('fake_env') }
  let(:options)        { { :target_dir => modpath } }

  let(:forge) {
    forge = mock("Puppet::Forge")

    forge.stubs(:multiple_remote_dependency_info).returns(remote_dependency_info)
    forge.stubs(:uri).returns('forge-dev.puppetlabs.com')
    remote_dependency_info.each_key do |mod|
      remote_dependency_info[mod].each do |release|
        forge.stubs(:retrieve).with(release['file']).returns("/fake_cache#{release['file']}")
      end
    end

    forge
  }

  let(:remote_dependency_info) {
    {
      "pmtacceptance/stdlib" => [
        { "dependencies" => [],
          "version"      => "0.0.1",
          "file"         => "/pmtacceptance-stdlib-0.0.1.tar.gz" },
        { "dependencies" => [],
          "version"      => "0.0.2",
          "file"         => "/pmtacceptance-stdlib-0.0.2.tar.gz" },
        { "dependencies" => [],
          "version"      => "1.0.0",
          "file"         => "/pmtacceptance-stdlib-1.0.0.tar.gz" }
      ],
      "pmtacceptance/java" => [
        { "dependencies" => [["pmtacceptance/stdlib", ">= 0.0.1"]],
          "version"      => "1.7.0",
          "file"         => "/pmtacceptance-java-1.7.0.tar.gz" },
        { "dependencies" => [["pmtacceptance/stdlib", "1.0.0"]],
          "version"      => "1.7.1",
          "file"         => "/pmtacceptance-java-1.7.1.tar.gz" }
      ],
      "pmtacceptance/apollo" => [
        { "dependencies" => [
            ["pmtacceptance/java", "1.7.1"],
            ["pmtacceptance/stdlib", "0.0.1"]
          ],
          "version" => "0.0.1",
          "file"    => "/pmtacceptance-apollo-0.0.1.tar.gz" },
        { "dependencies" => [
            ["pmtacceptance/java", ">= 1.7.0"],
            ["pmtacceptance/stdlib", ">= 1.0.0"]
          ],
          "version" => "0.0.2",
          "file"    => "/pmtacceptance-apollo-0.0.2.tar.gz" }
      ]
    }
  }

  before do
    FileUtils.mkdir_p(modpath)
    fake_env.modulepath = [modpath]
    Puppet.settings[:modulepath] = modpath
  end

  def upgrader_run(*args)
    upgrader = upgrader_class.new(*args)
    upgrader.instance_exec(fake_env) { |environment|
      @environment = environment
    }

    upgrader.run
  end

  it "should update the requested module" do
    local_module = mock('Puppet::Module')
    local_module.stubs(:forge_name).returns('pmtacceptance/stdlib')
    local_module.stubs(:name).returns('stdlib')
    local_module.stubs(:version).returns('0.5.0')
    local_module.stubs(:has_metadata?).returns(true)
    local_module.stubs(:has_local_changes?).returns(false)
    local_module.stubs(:modulepath).returns(modpath)
    local_module.stubs(:dependencies).returns([])

    fake_env.stubs(:modules_by_path).returns({
      modpath => [ local_module ]
    })

    Puppet::ModuleTool::Applications::Unpacker.expects(:new).
      with('/fake_cache/pmtacceptance-stdlib-1.0.0.tar.gz', options).
      returns(unpacker)

    results = upgrader_run('pmtacceptance-stdlib', forge, options)
    results[:affected_modules].length.should == 1
    results[:affected_modules][0][:module].should == 'pmtacceptance-stdlib'
    results[:affected_modules][0][:version][:vstring].should == '1.0.0'
  end

  it 'should fail when updating a module that is not installed' do
    fake_env.stubs(:modules_by_path).returns({})

    results = upgrader_run('pmtacceptance-stdlib', forge, options)

    results[:result].should == :failure
    results[:error][:oneline].should == "Could not upgrade 'pmtacceptance-stdlib'; module is not installed"
  end

  it 'should warn when the latest version is already installed' do
    local_module = mock('Puppet::Module')
    local_module.stubs(:forge_name).returns('pmtacceptance/stdlib')
    local_module.stubs(:name).returns('stdlib')
    local_module.stubs(:version).returns('1.0.0')
    local_module.stubs(:has_metadata?).returns(true)
    local_module.stubs(:has_local_changes?).returns(false)
    local_module.stubs(:modulepath).returns(modpath)
    local_module.stubs(:dependencies).returns([])

    fake_env.stubs(:modules_by_path).returns({
      modpath => [ local_module ]
    })

    results = upgrader_run('pmtacceptance-stdlib', forge, options)

    results[:result].should == :noop
    results[:error][:oneline].should == "Could not upgrade 'pmtacceptance-stdlib'; a better release is already installed"
  end

  it 'should not update a module that is not installed even when --force is specified' do
    options[:force] = true

    fake_env.stubs(:modules_by_path).returns({})

    results = upgrader_run('pmtacceptance-stdlib', forge, options)

    results[:result].should == :failure
    results[:error][:oneline].should == "Could not upgrade 'pmtacceptance-stdlib'; module is not installed"
  end
end
