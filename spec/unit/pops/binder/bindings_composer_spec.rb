require 'spec_helper'
require 'puppet/pops'
require 'puppet_spec/pops'
require 'puppet/plugins'

describe 'BinderComposer' do
  include PuppetSpec::Pops

  def config_dir(config_name)
    my_fixture(config_name)
  end

  let(:acceptor)    { Puppet::Pops::Validation::Acceptor.new() }
  let(:diag)        { Puppet::Pops::Binder::Config::DiagnosticProducer.new(acceptor) }
  let(:issues)      { Puppet::Pops::Binder::Config::Issues }
  let(:node)        { Puppet::Node.new('localhost') }
  let(:compiler)    { Puppet::Parser::Compiler.new(node)}
  let(:scope)       { Puppet::Parser::Scope.new(compiler) }
  let(:parser)      { Puppet::Pops::Parser::Parser.new() }
  let(:factory)     { Puppet::Pops::Binder::BindingsFactory }

  it 'should load default config if no config file exists' do
    diagnostics = diag
    composer = Puppet::Pops::Binder::BindingsComposer.new()
    composer.compose(scope)
  end

  context "when loading a complete configuration with modules" do
    let(:config_directory) { config_dir('ok') }

    it 'should load everything without errors' do
      Puppet.settings[:confdir] = config_directory
      Puppet.settings[:libdir] = File.join(config_directory, 'lib')

      environments = Puppet::Environments::Static.new(Puppet::Node::Environment.create(:production, [File.join(config_directory, 'modules')]))
      Puppet.override(:environments => environments, :current_environment => environments.get('production')) do
        # this ensure the binder is active at the right time
        # (issues with getting a /dev/null path for "confdir" / "libdir")
        raise "Binder not active" unless scope.compiler.activate_binder

        diagnostics = diag
        composer = Puppet::Pops::Binder::BindingsComposer.new()
        the_scope = scope
        the_scope['fqdn'] = 'localhost'
        the_scope['environment'] = 'production'
        layered_bindings = composer.compose(scope)
        # puts Puppet::Pops::Binder::BindingsModelDumper.new().dump(layered_bindings)
        binder = Puppet::Pops::Binder::Binder.new(layered_bindings)
        injector = Puppet::Pops::Binder::Injector.new(binder)
        expect(injector.lookup(scope, 'awesome_x')).to be == 'golden'
        expect(injector.lookup(scope, 'good_x')).to be == 'golden'
        expect(injector.lookup(scope, 'rotten_x')).to be == nil
        expect(injector.lookup(scope, 'the_meaning_of_life')).to be == 42
        expect(injector.lookup(scope, 'has_funny_hat')).to be == 'the pope'
        expect(injector.lookup(scope, 'all your base')).to be == 'are belong to us'
        expect(injector.lookup(scope, 'env_meaning_of_life')).to be == 'production thinks it is 42'
        expect(injector.lookup(scope, '::quick::brown::fox')).to be == 'echo: quick brown fox'
      end
    end
  end

  # TODO: test error conditions (see BinderConfigChecker for what to test)

end
