require 'spec_helper'
require 'puppet/pops'
require 'puppet_spec/pops'

describe 'BinderConfig' do
  include PuppetSpec::Pops

  let(:acceptor)    { Puppet::Pops::Validation::Acceptor.new() }
  let(:diag)        { Puppet::Pops::Binder::Config::DiagnosticProducer.new(acceptor) }
  let(:issues)      { Puppet::Pops::Binder::Config::Issues }

  it 'should load default config if no config file exists' do
    diagnostics = diag
    config = Puppet::Pops::Binder::Config::BinderConfig.new(diagnostics)
    expect(acceptor.errors?()).to be == false
    expect(config.layering_config[0]['name']).to    be == 'site'
    expect(config.layering_config[0]['include']).to be == ['confdir-hiera:/', 'confdir:/default?optional']
    expect(config.layering_config[1]['name']).to    be == 'modules'
    expect(config.layering_config[1]['include']).to be == ['module-hiera:/*/', 'module:/*::default']

    expect(config.categorization.is_a?(Array)).to be == true
    expect(config.categorization.size).to be == 4
    expect(config.categorization[0][0]).to be == 'node'
    expect(config.categorization[1][0]).to be == 'osfamily'
    expect(config.categorization[2][0]).to be == 'environment'
    expect(config.categorization[3][0]).to be == 'common'
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

    expect(config.categorization.is_a?(Array)).to be == true
    expect(config.categorization.size).to be == 3
    expect(config.categorization[0][0]).to be == 'node'
    expect(config.categorization[1][0]).to be == 'environment'
    expect(config.categorization[2][0]).to be == 'common'
  end

  # TODO: test error conditions (see BinderConfigChecker for what to test)

end