require 'spec_helper'
require 'puppet/pops'
require 'puppet_spec/pops'

describe 'foo' do
  include PuppetSpec::Pops

  let(:acceptor)    { Puppet::Pops::Validation::Acceptor.new() }
  let(:diag)        { Puppet::Pops::Binder::Config::DiagnosticProducer.new(acceptor) }
  let(:issues)      { Puppet::Pops::Binder::Config::Issues }

  it 'should load default config if no config file exists' do
    config = Puppet::Pops::Binder::Config::BinderConfig.new(diag)
    expect(acceptor.errors?()).to be == false
    expect(config.layering_config[0]['name']).to    be == 'site'
    expect(config.layering_config[0]['include']).to be == 'confdir-hiera:/'
    expect(config.layering_config[1]['name']).to    be == 'modules'
    expect(config.layering_config[1]['include']).to be == 'module-hiera:/*/'
#    expect(acceptor).to have_issue(issues::DUPLICATE_LAYER_NAME)
  end

  it 'should load binder_config.yaml if it exists in confdir)' do
    Puppet::Pops::Binder::Config::BinderConfig.any_instance.stubs(:confdir).returns(my_fixture("/ok/"))
    config = Puppet::Pops::Binder::Config::BinderConfig.new(diag)
    expect(acceptor.errors?()).to be == false
    expect(config.layering_config[0]['name']).to    be == 'site'
    expect(config.layering_config[0]['include']).to be == 'confdir-hiera:/'
    expect(config.layering_config[1]['name']).to    be == 'modules'
    expect(config.layering_config[1]['include']).to be == 'module-hiera:/*/'
    expect(config.layering_config[1]['exclude']).to be == 'module-hiera:/bad/'
  end

  # TODO: test error conditions (see BinderConfigChecker for what to test)

end