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
    Puppet[:strict_variables] = true

    # These must be set since the 3x logic switches some behaviors on these even if the tests explicitly
    # use the 4x parser and evaluator.
    #
    Puppet[:parser] = 'future'

    # Puppetx cannot be loaded until the correct parser has been set (injector is turned off otherwise)
    require 'puppetx'

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
      Puppet::Pops::Migration::MigrationChecker.expects(:new).at_least_once.returns(migration_checker)
      Puppet::Pops::Parser::EvaluatingParser.new.evaluate_string(scope, "1", __FILE__).should == 1
      Puppet::Pops::Migration::MigrationChecker.unstub(:new)
    end
  end

  describe "when there is a MigrationChecker in the Puppet Context" do
    it "does not create any MigrationChecker instances when parsing and evaluating" do
      migration_checker = mock()
      Puppet::Pops::Migration::MigrationChecker.expects(:new).never
      Puppet.override({:migration_checker => migration_checker}, "test-context") do
        Puppet::Pops::Parser::EvaluatingParser.new.evaluate_string(scope, "true", __FILE__)
      end
      Puppet::Pops::Migration::MigrationChecker.unstub(:new)
    end
  end

  describe "when validating parsed code" do
    it "is called for each integer" do
      migration_checker = mock()
      migration_checker.expects(:report_ambiguous_integer).times(3)
      Puppet.override({:migration_checker => migration_checker}, "migration-context") do
        Puppet::Pops::Parser::EvaluatingParser.new.evaluate_string(scope, "$a = [1,2,3]", __FILE__)
      end
    end

    it "is called for each float" do
      migration_checker = mock()
      migration_checker.expects(:report_ambiguous_float).times(3)
      Puppet.override({:migration_checker => migration_checker}, "migration-context") do
        Puppet::Pops::Parser::EvaluatingParser.new.evaluate_string(scope, "$a = [1.0,2.0,3.1415]", __FILE__)
      end
    end

    it "last expressions in blocks are checked" do
      migration_checker = mock()
      migration_checker.expects(:report_array_last_in_block).twice  # the program itself is a block too
      Puppet.override({:migration_checker => migration_checker}, "migration-context") do
        Puppet::Pops::Parser::EvaluatingParser.new.evaluate_string(scope, "$b = {} if true { $a = $b [false] }", __FILE__)
      end
    end

  end

  describe "when evaluating code" do
    it "is called for boolean coercion of String" do
      migration_checker = mock()
      migration_checker.expects(:report_empty_string_true).times(2)
      Puppet.override({:migration_checker => migration_checker}, "migration-context") do
        Puppet::Pops::Parser::EvaluatingParser.new.evaluate_string(scope, "$a = ('a' and '')", __FILE__)
      end
    end

    context "with a case expression" do
      it "the test expression is checked for UC_bareword" do
        migration_checker = mock()
        migration_checker.expects(:report_uc_bareword_type).once
        migration_checker.expects(:report_option_type_mismatch).once
        Puppet.override({:migration_checker => migration_checker}, "migration-context") do
          Puppet::Pops::Parser::EvaluatingParser.new.evaluate_string(scope, "case Foo { 'Foo': {}}", __FILE__)
        end
      end

      it "all case options are checked for UC_bareword" do
        migration_checker = mock()
        migration_checker.expects(:report_uc_bareword_type).times(4)
        migration_checker.expects(:report_option_type_mismatch).times(4)
        Puppet.override({:migration_checker => migration_checker}, "migration-context") do
          Puppet::Pops::Parser::EvaluatingParser.new.evaluate_string(scope, 
            "case true { Foo, Bar: {} Fee, 'not': {}}", __FILE__)
        end
      end
    end

    context "with a selector expression" do
      it "the test expression is checked for UC_bareword" do
        migration_checker = mock()
        migration_checker.expects(:report_uc_bareword_type).once
        Puppet.override({:migration_checker => migration_checker}, "migration-context") do
          Puppet::Pops::Parser::EvaluatingParser.new.evaluate_string(scope, "Foo ? { default => false}", __FILE__)
        end
      end

      it "all options are checked for UC_bareword" do
        migration_checker = mock()
        migration_checker.expects(:report_uc_bareword_type).times(3)
        migration_checker.expects(:report_option_type_mismatch).times(3)
        Puppet.override({:migration_checker => migration_checker}, "migration-context") do
          Puppet::Pops::Parser::EvaluatingParser.new.evaluate_string(scope, 
            "true ? { Foo => false, Bar => false, 'not' => false, default => true}", __FILE__)
        end
      end
    end

    context "with a comparison of" do
      ['==', '!=', ].each do |operator|
        it "'a' #{operator} 'b'" do
          migration_checker = mock()
          migration_checker.expects(:report_uc_bareword_type).twice
          migration_checker.expects(:report_equality_type_mismatch).once
          Puppet.override({:migration_checker => migration_checker}, "migration-context") do
            Puppet::Pops::Parser::EvaluatingParser.new.evaluate_string(scope, "'a' #{operator} 'b'", __FILE__)
          end
        end
      end

      ['<', '>', '<=', '>='].each do |operator|
        it "'a' #{operator} 'b'" do
          migration_checker = mock()
          migration_checker.expects(:report_uc_bareword_type).twice
          Puppet.override({:migration_checker => migration_checker}, "migration-context") do
            Puppet::Pops::Parser::EvaluatingParser.new.evaluate_string(scope, "'a' #{operator} 'b'", __FILE__)
          end
        end
      end

      ['=~', '!~'].each do |operator|
        it "'a' #{operator} /.*/" do
          migration_checker = mock()
          migration_checker.expects(:report_uc_bareword_type).once
          Puppet.override({:migration_checker => migration_checker}, "migration-context") do
            Puppet::Pops::Parser::EvaluatingParser.new.evaluate_string(scope, "'a' #{operator} /.*/", __FILE__)
          end
        end
      end
    end

    context "with an in operator" do
      it "'a' in [true,false]" do
        migration_checker = mock()
        migration_checker.expects(:report_uc_bareword_type).once
        migration_checker.expects(:report_in_expression).once
        Puppet.override({:migration_checker => migration_checker}, "migration-context") do
          Puppet::Pops::Parser::EvaluatingParser.new.evaluate_string(scope, "'a' in [true, false]", __FILE__)
        end
      end
    end
  end
end
