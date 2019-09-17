require 'spec_helper'

require 'puppet/pops'
require 'puppet/pops/evaluator/evaluator_impl'
require 'puppet/loaders'
require 'puppet_spec/pops'
require 'puppet_spec/scope'
require 'puppet/parser/e4_parser_adapter'

describe 'Puppet::Pops::MigrationMigrationChecker' do
  include PuppetSpec::Pops
  include PuppetSpec::Scope
  before(:each) do
    Puppet.push_context({strict_variables: true})

    # Puppetx cannot be loaded until the correct parser has been set (injector is turned off otherwise)
    require 'puppet_x'

    # Tests needs a known configuration of node/scope/compiler since it parses and evaluates
    # snippets as the compiler will evaluate them, butwithout the overhead of compiling a complete
    # catalog for each tested expression.
    #
    @parser  = Puppet::Pops::Parser::EvaluatingParser.new
    @node = Puppet::Node.new('node.example.com')
    @node.environment = Puppet::Node::Environment.create(:testing, [])
    @compiler = Puppet::Parser::Compiler.new(@node)
    @scope = Puppet::Parser::Scope.new(@compiler)
    @scope.source = Puppet::Resource::Type.new(:node, 'node.example.com')
    @scope.parent = @compiler.topscope
  end

  let(:scope) { @scope }

  describe "when there is no MigrationChecker in the PuppetContext" do
    it "a null implementation of the MigrationChecker gets created (once per impl that needs one)" do
      migration_checker = Puppet::Pops::Migration::MigrationChecker.new()
      expect(Puppet::Pops::Migration::MigrationChecker).to receive(:new).at_least(:once).and_return(migration_checker)
      expect(Puppet::Pops::Parser::EvaluatingParser.new.evaluate_string(scope, "1", __FILE__)).to eq(1)
    end
  end

  describe "when there is a MigrationChecker in the Puppet Context" do
    it "does not create any MigrationChecker instances when parsing and evaluating" do
      migration_checker = double()
      expect(Puppet::Pops::Migration::MigrationChecker).not_to receive(:new)
      Puppet.override({:migration_checker => migration_checker}, "test-context") do
        Puppet::Pops::Parser::EvaluatingParser.new.evaluate_string(scope, "true", __FILE__)
      end
    end
  end
end
