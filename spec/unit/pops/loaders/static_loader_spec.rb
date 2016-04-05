require 'spec_helper'
require 'puppet/pops'
require 'puppet/loaders'

describe 'the static loader' do
  it 'has no parent' do
    expect(Puppet::Pops::Loader::StaticLoader.new.parent).to be(nil)
  end

  it 'identifies itself in string form' do
    expect(Puppet::Pops::Loader::StaticLoader.new.to_s).to be_eql('(StaticLoader)')
  end

  it 'support the Loader API' do
    # it may produce things later, this is just to test that calls work as they should - now all lookups are nil.
    loader = Puppet::Pops::Loader::StaticLoader.new()
    a_typed_name = typed_name(:function, 'foo')
    expect(loader[a_typed_name]).to be(nil)
    expect(loader.load_typed(a_typed_name)).to be(nil)
    expect(loader.find(a_typed_name)).to be(nil)
  end

  context 'provides access to logging functions' do
    let(:loader) { loader = Puppet::Pops::Loader::StaticLoader.new() }
    # Ensure all logging functions produce output
    before(:each) { Puppet::Util::Log.level = :debug }

    Puppet::Util::Log.levels.each do |level|
      it "defines the function #{level.to_s}" do
        expect(loader.load(:function, level).class.name).to eql(level.to_s)
      end

      it 'and #{level.to_s} can be called' do
        expect(loader.load(:function, level).call({}, 'yay').to_s).to eql('yay')
      end

      it "uses the evaluator to format output" do
        expect(loader.load(:function, level).call({}, ['yay', 'surprise']).to_s).to eql('[yay, surprise]')
      end

      it 'outputs name of source (scope) by passing it to the Log utility' do
        the_scope = {}
        Puppet::Util::Log.any_instance.expects(:source=).with(the_scope)
        loader.load(:function, level).call(the_scope, 'x')
      end
    end
  end

  context 'provides access to resource types built into puppet' do
    let(:loader) { loader = Puppet::Pops::Loader::StaticLoader.new() }

    %w{
      Auegas
      Component
      Computer
      Cron
      Exec
      File
      Filebucket
      Group
      Host
      Interface
      K5login
      Macauthorization
      Mailalias
      Maillist
      Mcx
      Mount
      Nagios_command
      Nagios_contact
      Nagios_contactgroup
      Nagios_host
      Nagios_hostdependency
      Nagios_hostescalation
      Nagios_hostescalation
      Nagios_hostgroup
      Nagios_service
      Nagios_servicedependency
      Nagios_serviceescalation
      Nagios_serviceextinfo
      Nagios_servicegroup
      Nagios_timeperiod
      Notify
      Package
      Resources
      Router
      Schedule
      Scheduled_task
      Selboolean
      Selmodule
      Service
      Ssh_authorized_key
      Sshkey
      Stage
      Tidy
      User
      Vlan
      Whit
      Yumrepo
      Zfs
      Zone
      Zpool
    }.each do |name |
      it "such that #{name} is available" do
        expect(loader.load(:type, name.downcase)).to be_the_type(resource_type(name))
      end
    end
  end

  context 'provides access to app-management specific resource types built into puppet' do
    before(:each) { Puppet[:app_management] = true }
    after(:each) { Puppet[:app_management] = false }

    let(:loader) { loader = Puppet::Pops::Loader::StaticLoader.new() }

    %w{Node}.each do |name|
      it "such that #{name} is avaiable" do
        expect(loader.load(:type, name.downcase)).to be_the_type(resource_type(name))
      end
    end
  end

  def typed_name(type, name)
    Puppet::Pops::Loader::Loader::TypedName.new(type, name)
  end

  def resource_type(name)
    Puppet::Pops::Types::TypeFactory.resource(name)
  end

  matcher :be_the_type do |type|
    calc = Puppet::Pops::Types::TypeCalculator.new

    match do |actual|
      calc.assignable?(actual, type) && calc.assignable?(type, actual)
    end

    failure_message do |actual|
      "expected #{type.to_s}, but was #{actual.to_s}"
    end
  end

end
