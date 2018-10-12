#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'
require 'puppet_spec/pops'
require_relative '../parser/parser_rspec_helper'

describe "validating 4x" do
  include ParserRspecHelper
  include PuppetSpec::Pops

  let(:acceptor) { Puppet::Pops::Validation::Acceptor.new() }
  let(:validator) { Puppet::Pops::Validation::ValidatorFactory_4_0.new().validator(acceptor) }
  let(:environment) { Puppet::Node::Environment.create(:bar, ['path']) }

  def validate(factory)
    validator.validate(factory.model)
    acceptor
  end

  def deprecation_count(acceptor)
    acceptor.diagnostics.select {|d| d.severity == :deprecation }.count
  end

  def with_environment(environment, env_params = {})
    override_env = environment
    override_env = environment.override_with({
      modulepath:     env_params[:modulepath]     || environment.full_modulepath,
      manifest:       env_params[:manifest]       || environment.manifest,
      config_version: env_params[:config_version] || environment.config_version
    }) if env_params.count > 0
    Puppet.override(current_environment: override_env) do
      yield
    end
  end

  it 'should raise error for illegal class names' do
    expect(validate(parse('class aaa::_bbb {}'))).to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_NAME)
    expect(validate(parse('class Aaa {}'))).to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_NAME)
    expect(validate(parse('class ::aaa {}'))).to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_NAME)
  end

  it 'should raise error for illegal define names' do
    expect(validate(parse('define aaa::_bbb {}'))).to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_NAME)
    expect(validate(parse('define Aaa {}'))).to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_NAME)
    expect(validate(parse('define ::aaa {}'))).to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_NAME)
  end

  it 'should raise error for illegal function names' do
    expect(validate(parse('function aaa::_bbb() {}'))).to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_NAME)
    expect(validate(parse('function Aaa() {}'))).to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_NAME)
    expect(validate(parse('function ::aaa() {}'))).to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_NAME)
  end

  it 'should raise error for illegal definition locations' do
    with_environment(environment) do
      expect(validate(parse('function aaa::ccc() {}', 'path/aaa/manifests/bbb.pp'))).to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_LOCATION)
      expect(validate(parse('class bbb() {}', 'path/aaa/manifests/init.pp'))).to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_LOCATION)
      expect(validate(parse('define aaa::bbb::ccc::eee() {}', 'path/aaa/manifests/bbb/ddd.pp'))).to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_LOCATION)
    end
  end

  it 'should not raise error for legal definition locations' do
    with_environment(environment) do
      expect(validate(parse('function aaa::bbb() {}',      'path/aaa/manifests/bbb.pp'))).not_to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_LOCATION)
      expect(validate(parse('class aaa() {}',      'path/aaa/manifests/init.pp'))).not_to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_LOCATION)
      expect(validate(parse('function aaa::bbB::ccc() {}', 'path/aaa/manifests/bBb.pp'))).not_to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_LOCATION)
      expect(validate(parse('function aaa::bbb::ccc() {}', 'path/aaa/manifests/bbb/CCC.pp'))).not_to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_LOCATION)
    end
  end

  it 'should not raise error for class locations when not parsing a file' do
    #nil/'' file means eval or some other way to get puppet language source code into the catalog
    with_environment(environment) do
      expect(validate(parse('function aaa::ccc() {}', nil))).not_to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_LOCATION)
      expect(validate(parse('function aaa::ccc() {}', ''))).not_to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_LOCATION)
    end
  end

  it 'should not raise error for definitions inside initial --manifest file' do
    with_environment(environment, :manifest => 'a/manifest/file.pp') do
      expect(validate(parse('class aaa() {}', 'a/manifest/file.pp'))).not_to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_LOCATION)
    end
  end

  it 'should not raise error for definitions inside initial --manifest directory' do
    with_environment(environment, :manifest => 'a/manifest/dir') do
      expect(validate(parse('class aaa() {}', 'a/manifest/dir/file1.pp'))).not_to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_LOCATION)
      expect(validate(parse('class bbb::ccc::ddd() {}', 'a/manifest/dir/and/more/stuff.pp'))).not_to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_LOCATION)
    end
  end

  it 'should not raise error for definitions not inside initial --manifest but also not in modulepath' do
    with_environment(environment, :manifest => 'a/manifest/somewhere/else') do
      expect(validate(parse('class aaa() {}', 'a/random/dir/file1.pp'))).not_to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_LOCATION)
    end
  end

  it 'should not raise error for empty files in modulepath' do
    with_environment(environment) do
      expect(validate(parse('', 'path/aaa/manifests/init.pp'))).not_to have_issue(Puppet::Pops::Issues::ILLEGAL_TOP_CONSTRUCT_LOCATION)
      expect(validate(parse('#this is a comment', 'path/aaa/manifests/init.pp'))).not_to have_issue(Puppet::Pops::Issues::ILLEGAL_TOP_CONSTRUCT_LOCATION)
    end
  end

  it 'should raise error if the file is in the modulepath but is not well formed' do
    with_environment(environment) do
      expect(validate(parse('class aaa::bbb::ccc() {}', 'path/manifest/aaa/bbb.pp'))).to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_LOCATION)
      expect(validate(parse('class aaa::bbb::ccc() {}', 'path/aaa/bbb/manifest/ccc.pp'))).to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_LOCATION)
    end
  end

  it 'should not raise error for definitions not inside initial --manifest but also not in modulepath because of only a case difference' do
    with_environment(environment) do
        expect(validate(parse('class aaa::bb() {}', 'Path/aaa/manifests/ccc.pp'))).not_to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_LOCATION)
    end
  end

  it 'should not raise error when one modulepath is a substring of another' do
    with_environment(environment, modulepath: ['path', 'pathplus']) do
      expect(validate(parse('class aaa::ccc() {}', 'pathplus/aaa/manifests/ccc.pp'))).not_to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_LOCATION)
    end
  end

  it 'should not raise error when a modulepath ends with a file separator' do
    with_environment(environment, modulepath: ['path/']) do
      expect(validate(parse('class aaa::ccc() {}', 'pathplus/aaa/manifests/ccc.pp'))).not_to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_LOCATION)
    end
  end

  it 'should raise error for illegal type names' do
    expect(validate(parse('type ::Aaa = Any'))).to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_NAME)
  end

  it 'should raise error for illegal variable names' do
    expect(validate(fqn('Aaa').var())).to have_issue(Puppet::Pops::Issues::ILLEGAL_VAR_NAME)
    expect(validate(fqn('AAA').var())).to have_issue(Puppet::Pops::Issues::ILLEGAL_VAR_NAME)
    expect(validate(fqn('aaa::_aaa').var())).to have_issue(Puppet::Pops::Issues::ILLEGAL_VAR_NAME)
  end

  it 'should not raise error for variable name with underscore first in first name segment' do
    expect(validate(fqn('_aa').var())).to_not have_issue(Puppet::Pops::Issues::ILLEGAL_VAR_NAME)
    expect(validate(fqn('::_aa').var())).to_not have_issue(Puppet::Pops::Issues::ILLEGAL_VAR_NAME)
  end

  context 'with the default settings for --strict' do
    it 'produces a warning for duplicate keys in a literal hash' do
      acceptor = validate(parse('{ a => 1, a => 2 }'))
      expect(acceptor.warning_count).to eql(1)
      expect(acceptor.error_count).to eql(0)
      expect(acceptor).to have_issue(Puppet::Pops::Issues::DUPLICATE_KEY)
    end

    it 'produces a deprecation for illegal function locations' do
      with_environment(environment) do
        acceptor = validate(parse('function aaa::ccc() {}', 'path/aaa/manifests/bbb.pp'))
        expect(deprecation_count(acceptor)).to eql(1)
        expect(acceptor.warning_count).to eql(1)
        expect(acceptor.error_count).to eql(0)
        expect(acceptor).to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_LOCATION)
      end
    end

    it 'produces a deprecation for illegal top level constructs' do
      with_environment(environment) do
        acceptor = validate(parse('$foo = 1', 'path/aaa/manifests/bbb.pp'))
        expect(deprecation_count(acceptor)).to eql(1)
        expect(acceptor.warning_count).to eql(1)
        expect(acceptor.error_count).to eql(0)
        expect(acceptor).to have_issue(Puppet::Pops::Issues::ILLEGAL_TOP_CONSTRUCT_LOCATION)
      end
    end
  end

  context 'with --strict set to warning' do
    before(:each) { Puppet[:strict] = :warning }
    it 'produces a warning for duplicate keys in a literal hash' do
      acceptor = validate(parse('{ a => 1, a => 2 }'))
      expect(acceptor.warning_count).to eql(1)
      expect(acceptor.error_count).to eql(0)
      expect(acceptor).to have_issue(Puppet::Pops::Issues::DUPLICATE_KEY)
    end

    it 'produces a warning for virtual class resource' do
      acceptor = validate(parse('@class { test: }'))
      expect(acceptor.warning_count).to eql(1)
      expect(acceptor.error_count).to eql(0)
      expect(acceptor).to have_issue(Puppet::Pops::Issues::CLASS_NOT_VIRTUALIZABLE)
    end

    it 'produces a warning for exported class resource' do
      acceptor = validate(parse('@@class { test: }'))
      expect(acceptor.warning_count).to eql(1)
      expect(acceptor.error_count).to eql(0)
      expect(acceptor).to have_issue(Puppet::Pops::Issues::CLASS_NOT_VIRTUALIZABLE)
    end

    it 'produces a deprecation for illegal function locations' do
      with_environment(environment) do
        acceptor = validate(parse('function aaa::ccc() {}', 'path/aaa/manifests/bbb.pp'))
        expect(deprecation_count(acceptor)).to eql(1)
        expect(acceptor.warning_count).to eql(1)
        expect(acceptor.error_count).to eql(0)
        expect(acceptor).to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_LOCATION)
      end
    end

    it 'produces a deprecation for illegal top level constructs' do
      with_environment(environment) do
        acceptor = validate(parse('$foo = 1', 'path/aaa/manifests/bbb.pp'))
        expect(deprecation_count(acceptor)).to eql(1)
        expect(acceptor.warning_count).to eql(1)
        expect(acceptor.error_count).to eql(0)
        expect(acceptor).to have_issue(Puppet::Pops::Issues::ILLEGAL_TOP_CONSTRUCT_LOCATION)
      end
    end
  end

  context 'with --strict set to error' do
    before(:each) { Puppet[:strict] = :error }
    it 'produces an error for duplicate keys in a literal hash' do
      acceptor = validate(parse('{ a => 1, a => 2 }'))
      expect(acceptor.warning_count).to eql(0)
      expect(acceptor.error_count).to eql(1)
      expect(acceptor).to have_issue(Puppet::Pops::Issues::DUPLICATE_KEY)
    end

    it 'produces an error for virtual class resource' do
      acceptor = validate(parse('@class { test: }'))
      expect(acceptor.warning_count).to eql(0)
      expect(acceptor.error_count).to eql(1)
      expect(acceptor).to have_issue(Puppet::Pops::Issues::CLASS_NOT_VIRTUALIZABLE)
    end

    it 'does not produce an error for regular class resource' do
      acceptor = validate(parse('class { test: }'))
      expect(acceptor.warning_count).to eql(0)
      expect(acceptor.error_count).to eql(0)
      expect(acceptor).not_to have_issue(Puppet::Pops::Issues::CLASS_NOT_VIRTUALIZABLE)
    end

    it 'produces an error for exported class resource' do
      acceptor = validate(parse('@@class { test: }'))
      expect(acceptor.warning_count).to eql(0)
      expect(acceptor.error_count).to eql(1)
      expect(acceptor).to have_issue(Puppet::Pops::Issues::CLASS_NOT_VIRTUALIZABLE)
    end

    it 'produces a deprecation for illegal function locations' do
      with_environment(environment) do
        acceptor = validate(parse('function aaa::ccc() {}', 'path/aaa/manifests/bbb.pp'))
        expect(deprecation_count(acceptor)).to eql(1)
        expect(acceptor.warning_count).to eql(1)
        expect(acceptor.error_count).to eql(0)
        expect(acceptor).to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_LOCATION)
      end
    end

    it 'produces a deprecation for illegal top level constructs' do
      with_environment(environment) do
        acceptor = validate(parse('$foo = 1', 'path/aaa/manifests/bbb.pp'))
        expect(deprecation_count(acceptor)).to eql(1)
        expect(acceptor.warning_count).to eql(1)
        expect(acceptor.error_count).to eql(0)
        expect(acceptor).to have_issue(Puppet::Pops::Issues::ILLEGAL_TOP_CONSTRUCT_LOCATION)
      end
    end
  end

  context 'with --strict set to off' do
    before(:each) { Puppet[:strict] = :off }
    it 'does not produce an error or warning for duplicate keys in a literal hash' do
      acceptor = validate(parse('{ a => 1, a => 2 }'))
      expect(acceptor.warning_count).to eql(0)
      expect(acceptor.error_count).to eql(0)
      expect(acceptor).to_not have_issue(Puppet::Pops::Issues::DUPLICATE_KEY)
    end

    it 'produces a deprecation for illegal function locations' do
      with_environment(environment) do
        acceptor = validate(parse('function aaa::ccc() {}', 'path/aaa/manifests/bbb.pp'))
        expect(deprecation_count(acceptor)).to eql(1)
        expect(acceptor.warning_count).to eql(1)
        expect(acceptor.error_count).to eql(0)
        expect(acceptor).to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_LOCATION)
      end
    end

    it 'produces a deprecation for illegal top level constructs' do
      with_environment(environment) do
        acceptor = validate(parse('$foo = 1', 'path/aaa/manifests/bbb.pp'))
        expect(deprecation_count(acceptor)).to eql(1)
        expect(acceptor.warning_count).to eql(1)
        expect(acceptor.error_count).to eql(0)
        expect(acceptor).to have_issue(Puppet::Pops::Issues::ILLEGAL_TOP_CONSTRUCT_LOCATION)
      end
    end
  end

  context 'irrespective of --strict' do
    it 'produces an error for duplicate default in a case expression' do
      acceptor = validate(parse('case 1 { default: {1} default : {2} }'))
      expect(acceptor.warning_count).to eql(0)
      expect(acceptor.error_count).to eql(1)
      expect(acceptor).to have_issue(Puppet::Pops::Issues::DUPLICATE_DEFAULT)
    end

    it 'produces an error for duplicate default in a selector expression' do
      acceptor = validate(parse(' 1 ? { default => 1, default => 2 }'))
      expect(acceptor.warning_count).to eql(0)
      expect(acceptor.error_count).to eql(1)
      expect(acceptor).to have_issue(Puppet::Pops::Issues::DUPLICATE_DEFAULT)
    end

    it 'produces a warning for virtual class resource' do
      acceptor = validate(parse('@class { test: }'))
      expect(acceptor.warning_count).to eql(1)
      expect(acceptor.error_count).to eql(0)
      expect(acceptor).to have_issue(Puppet::Pops::Issues::CLASS_NOT_VIRTUALIZABLE)
    end

    it 'produces a warning for exported class resource' do
      acceptor = validate(parse('@@class { test: }'))
      expect(acceptor.warning_count).to eql(1)
      expect(acceptor.error_count).to eql(0)
      expect(acceptor).to have_issue(Puppet::Pops::Issues::CLASS_NOT_VIRTUALIZABLE)
    end
  end

  context 'with --tasks set' do
    before(:each) { Puppet[:tasks] = true }

    it 'raises an error for illegal plan names' do
      with_environment(environment) do
        expect(validate(parse('plan aaa::ccc::eee() {}', 'path/aaa/plans/bbb/ccc/eee.pp'))).to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_LOCATION)
        expect(validate(parse('plan aaa() {}', 'path/aaa/plans/aaa.pp'))).to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_LOCATION)
        expect(validate(parse('plan aaa::bbb() {}', 'path/aaa/plans/bbb/bbb.pp'))).to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_LOCATION)
      end
    end

    it 'accepts legal plan names' do
      with_environment(environment) do
        expect(validate(parse('plan aaa::ccc::eee() {}', 'path/aaa/plans/ccc/eee.pp'))).not_to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_LOCATION)
        expect(validate(parse('plan aaa() {}', 'path/aaa/plans/init.pp'))).not_to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_LOCATION)
        expect(validate(parse('plan aaa::bbb() {}', 'path/aaa/plans/bbb.pp'))).not_to have_issue(Puppet::Pops::Issues::ILLEGAL_DEFINITION_LOCATION)
      end
    end

    it 'produces an error for application' do
      acceptor = validate(parse('application test {}'))
      expect(acceptor.error_count).to eql(1)
      expect(acceptor).to have_issue(Puppet::Pops::Issues::CATALOG_OPERATION_NOT_SUPPORTED_WHEN_SCRIPTING)
    end

    it 'produces an error for capability mapping' do
      acceptor = validate(parse('Foo produces Sql {}'))
      expect(acceptor.error_count).to eql(1)
      expect(acceptor).to have_issue(Puppet::Pops::Issues::CATALOG_OPERATION_NOT_SUPPORTED_WHEN_SCRIPTING)
    end

    it 'produces an error for collect expressions with virtual query' do
      acceptor = validate(parse("User <| title == 'admin' |>"))
      expect(acceptor.error_count).to eql(1)
      expect(acceptor).to have_issue(Puppet::Pops::Issues::CATALOG_OPERATION_NOT_SUPPORTED_WHEN_SCRIPTING)
    end

    it 'produces an error for collect expressions with exported query' do
      acceptor = validate(parse("User <<| title == 'admin' |>>"))
      expect(acceptor.error_count).to eql(1)
      expect(acceptor).to have_issue(Puppet::Pops::Issues::CATALOG_OPERATION_NOT_SUPPORTED_WHEN_SCRIPTING)
    end

    it 'produces an error for class expressions' do
      acceptor = validate(parse('class test {}'))
      expect(acceptor.error_count).to eql(1)
      expect(acceptor).to have_issue(Puppet::Pops::Issues::CATALOG_OPERATION_NOT_SUPPORTED_WHEN_SCRIPTING)
    end

    it 'produces an error for node expressions' do
      acceptor = validate(parse('node default {}'))
      expect(acceptor.error_count).to eql(1)
      expect(acceptor).to have_issue(Puppet::Pops::Issues::CATALOG_OPERATION_NOT_SUPPORTED_WHEN_SCRIPTING)
    end

    it 'produces an error for relationship expressions' do
      acceptor = validate(parse('$x -> $y'))
      expect(acceptor.error_count).to eql(1)
      expect(acceptor).to have_issue(Puppet::Pops::Issues::CATALOG_OPERATION_NOT_SUPPORTED_WHEN_SCRIPTING)
    end

    it 'produces an error for resource expressions' do
      acceptor = validate(parse('notify { nope: }'))
      expect(acceptor.error_count).to eql(1)
      expect(acceptor).to have_issue(Puppet::Pops::Issues::CATALOG_OPERATION_NOT_SUPPORTED_WHEN_SCRIPTING)
    end

    it 'produces an error for resource default expressions' do
      acceptor = validate(parse("File { mode => '0644' }"))
      expect(acceptor.error_count).to eql(1)
      expect(acceptor).to have_issue(Puppet::Pops::Issues::CATALOG_OPERATION_NOT_SUPPORTED_WHEN_SCRIPTING)
    end

    it 'produces an error for resource override expressions' do
      acceptor = validate(parse("File['/tmp/foo'] { mode => '0644' }"))
      expect(acceptor.error_count).to eql(1)
      expect(acceptor).to have_issue(Puppet::Pops::Issues::CATALOG_OPERATION_NOT_SUPPORTED_WHEN_SCRIPTING)
    end

    it 'produces an error for resource definitions' do
      acceptor = validate(parse('define foo($a) {}'))
      expect(acceptor.error_count).to eql(1)
      expect(acceptor).to have_issue(Puppet::Pops::Issues::CATALOG_OPERATION_NOT_SUPPORTED_WHEN_SCRIPTING)
    end

    it 'produces an error for site definitions' do
      acceptor = validate(parse('site {}'))
      expect(acceptor.error_count).to eql(1)
      expect(acceptor).to have_issue(Puppet::Pops::Issues::CATALOG_OPERATION_NOT_SUPPORTED_WHEN_SCRIPTING)
    end
  end

  context 'for non productive expressions' do
    [ '1',
      '3.14',
      "'a'",
      '"a"',
      '"${$a=10}"', # interpolation with side effect
      'false',
      'true',
      'default',
      'undef',
      '[1,2,3]',
      '{a=>10}',
      'if 1 {2}',
      'if 1 {2} else {3}',
      'if 1 {2} elsif 3 {4}',
      'unless 1 {2}',
      'unless 1 {2} else {3}',
      '1 ? 2 => 3',
      '1 ? { 2 => 3}',
      '-1',
      '-foo()', # unary minus on productive
      '1+2',
      '1<2',
      '(1<2)',
      '!true',
      '!foo()', # not on productive
      '$a',
      '$a[1]',
      'name',
      'Type',
      'Type[foo]'
      ].each do |expr|
      it "produces error for non productive: #{expr}" do
        source = "#{expr}; $a = 10"
        expect(validate(parse(source))).to have_issue(Puppet::Pops::Issues::IDEM_EXPRESSION_NOT_LAST)
      end

      it "does not produce error when last for non productive: #{expr}" do
        source = " $a = 10; #{expr}"
        expect(validate(parse(source))).to_not have_issue(Puppet::Pops::Issues::IDEM_EXPRESSION_NOT_LAST)
      end
    end

    [
      'if 1 {$a = 1}',
      'if 1 {2} else {$a=1}',
      'if 1 {2} elsif 3 {$a=1}',
      'unless 1 {$a=1}',
      'unless 1 {2} else {$a=1}',
      '$a = 1 ? 2 => 3',
      '$a = 1 ? { 2 => 3}',
      'Foo[a] -> Foo[b]',
      '($a=1)',
      'foo()',
      '$a.foo()',
      '"foo" =~ /foo/', # may produce or modify $n vars
      '"foo" !~ /foo/', # may produce or modify $n vars
      ].each do |expr|

      it "does not produce error when for productive: #{expr}" do
        source = "#{expr}; $x = 1"
        expect(validate(parse(source))).to_not have_issue(Puppet::Pops::Issues::IDEM_EXPRESSION_NOT_LAST)
      end
    end

    ['class', 'define', 'node'].each do |type|
      it "flags non productive expression last in #{type}" do
        source = <<-SOURCE
          #{type} nope {
            1
          }
          end
        SOURCE
        expect(validate(parse(source))).to have_issue(Puppet::Pops::Issues::IDEM_NOT_ALLOWED_LAST)
      end

      it "detects a resource declared without title in #{type} when it is the only declaration present" do
        source = <<-SOURCE
          #{type} nope {
            notify { message => 'Nope' }
          }
        SOURCE
        expect(validate(parse(source))).to have_issue(Puppet::Pops::Issues::RESOURCE_WITHOUT_TITLE)
      end

      it "detects a resource declared without title in #{type} when it is in between other declarations" do
        source = <<-SOURCE
        #{type} nope {
            notify { succ: message => 'Nope' }
            notify { message => 'Nope' }
            notify { pred: message => 'Nope' }
          }
        SOURCE
        expect(validate(parse(source))).to have_issue(Puppet::Pops::Issues::RESOURCE_WITHOUT_TITLE)
      end

      it "detects a resource declared without title in #{type} when it is declarated first" do
        source = <<-SOURCE
          #{type} nope {
            notify { message => 'Nope' }
            notify { pred: message => 'Nope' }
          }
        SOURCE
        expect(validate(parse(source))).to have_issue(Puppet::Pops::Issues::RESOURCE_WITHOUT_TITLE)
      end

      it "detects a resource declared without title in #{type} when it is declarated last" do
        source = <<-SOURCE
          #{type} nope {
            notify { succ: message => 'Nope' }
            notify { message => 'Nope' }
          }
        SOURCE
        expect(validate(parse(source))).to have_issue(Puppet::Pops::Issues::RESOURCE_WITHOUT_TITLE)
      end
    end
  end

  context 'for reserved words' do
    ['private', 'attr'].each do |word|
      it "produces an error for the word '#{word}'" do
        source = "$a = #{word}"
        expect(validate(parse(source))).to have_issue(Puppet::Pops::Issues::RESERVED_WORD)
      end
    end
  end

  context 'for reserved type names' do
    [# type/Type, is a reserved name but results in syntax error because it is a keyword in lower case form
    'any',
    'unit',
    'scalar',
    'boolean',
    'numeric',
    'integer',
    'float',
    'collection',
    'array',
    'hash',
    'tuple',
    'struct',
    'variant',
    'optional',
    'enum',
    'regexp',
    'pattern',
    'runtime',
    ].each do |name|

      it "produces an error for 'class #{name}'" do
        source = "class #{name} {}"
        expect(validate(parse(source))).to have_issue(Puppet::Pops::Issues::RESERVED_TYPE_NAME)
      end

      it "produces an error for 'define #{name}'" do
        source = "define #{name} {}"
        expect(validate(parse(source))).to have_issue(Puppet::Pops::Issues::RESERVED_TYPE_NAME)
      end
    end
  end

  context 'for keywords' do
    it "should allow using the 'type' as the name of a function with no parameters" do
      source = "type()"
      expect(validate(parse(source))).not_to have_any_issues
    end

    it "should allow using the keyword 'type' as the name of a function with parameters" do
      source = "type('a', 'b')"
      expect(validate(parse(source))).not_to have_any_issues
    end
    it "should allow using the 'type' as the name of a function with no parameters and a block" do
      source = "type() |$x| { $x }"
      expect(validate(parse(source))).not_to have_any_issues
    end

    it "should allow using the keyword 'type' as the name of a function with parameters and a block" do
      source = "type('a', 'b') |$x| { $x }"
      expect(validate(parse(source))).not_to have_any_issues
    end
  end

  context 'for parameter names' do
    ['class', 'define'].each do |word|
      it "should require that #{word} parameter names are unique" do
        expect(validate(parse("#{word} foo($a = 10, $a = 20) {}"))).to have_issue(Puppet::Pops::Issues::DUPLICATE_PARAMETER)
      end
    end

    it "should require that template parameter names are unique" do
      expect(validate(parse_epp("<%-| $a, $a |-%><%= $a == doh %>"))).to have_issue(Puppet::Pops::Issues::DUPLICATE_PARAMETER)
    end
  end

  context 'for parameter defaults' do
    ['class', 'define'].each do |word|
      it "should not permit assignments in #{word} parameter default expressions" do
        expect { parse("#{word} foo($a = $x = 10) {}") }.to raise_error(Puppet::ParseErrorWithIssue, /Syntax error at '='/)
      end
    end

    ['class', 'define'].each do |word|
      it "should not permit assignments in #{word} parameter default nested expressions" do
        expect(validate(parse("#{word} foo($a = [$x = 10]) {}"))).to have_issue(Puppet::Pops::Issues::ILLEGAL_ASSIGNMENT_CONTEXT)
      end

      it "should not permit assignments to subsequently declared parameters in #{word} parameter default nested expressions" do
        expect(validate(parse("#{word} foo($a = ($b = 3), $b = 5) {}"))).to have_issue(Puppet::Pops::Issues::ILLEGAL_ASSIGNMENT_CONTEXT)
      end

      it "should not permit assignments to previously declared parameters in #{word} parameter default nested expressions" do
        expect(validate(parse("#{word} foo($a = 10, $b = ($a = 10)) {}"))).to have_issue(Puppet::Pops::Issues::ILLEGAL_ASSIGNMENT_CONTEXT)
      end

      it "should permit assignments in #{word} parameter default inside nested lambda expressions" do
        expect(validate(parse(
          "#{word} foo($a = [1,2,3], $b = 0, $c = $a.map |$x| { $b = $x; $b * $a.reduce |$x, $y| {$x + $y}}) {}"))).not_to(
          have_issue(Puppet::Pops::Issues::ILLEGAL_ASSIGNMENT_CONTEXT))
      end
    end
  end

  context 'for reserved parameter names' do
    ['name', 'title'].each do |word|
      it "produces an error when $#{word} is used as a parameter in a class" do
        source = "class x ($#{word}) {}"
        expect(validate(parse(source))).to have_issue(Puppet::Pops::Issues::RESERVED_PARAMETER)
      end

      it "produces an error when $#{word} is used as a parameter in a define" do
        source = "define x ($#{word}) {}"
        expect(validate(parse(source))).to have_issue(Puppet::Pops::Issues::RESERVED_PARAMETER)
      end
    end

  end

  context 'for numeric parameter names' do
    ['1', '0x2', '03'].each do |word|
      it "produces an error when $#{word} is used as a parameter in a class" do
        source = "class x ($#{word}) {}"
        expect(validate(parse(source))).to have_issue(Puppet::Pops::Issues::ILLEGAL_NUMERIC_PARAMETER)
      end
    end
  end

  context 'for badly formed non-numeric parameter names' do
    ['Ateam', 'a::team'].each do |word|
      it "produces an error when $#{word} is used as a parameter in a class" do
        source = "class x ($#{word}) {}"
        expect(validate(parse(source))).to have_issue(Puppet::Pops::Issues::ILLEGAL_PARAM_NAME)
      end

      it "produces an error when $#{word} is used as a parameter in a define" do
        source = "define x ($#{word}) {}"
        expect(validate(parse(source))).to have_issue(Puppet::Pops::Issues::ILLEGAL_PARAM_NAME)
      end

      it "produces an error when $#{word} is used as a parameter in a lambda" do
        source = "with() |$#{word}| {}"
        expect(validate(parse(source))).to have_issue(Puppet::Pops::Issues::ILLEGAL_PARAM_NAME)
      end
    end
  end

  context 'top level constructs' do
    def issue(at_top)
      at_top ? Puppet::Pops::Issues::NOT_ABSOLUTE_TOP_LEVEL : Puppet::Pops::Issues::NOT_TOP_LEVEL
    end

    # Top level. Defines the expressions that are tested inside of other things
    {
      'a class' => ['class x{}', false],
      'a define' => ['define x{}', false],
      'a node' => ['node x{}', false],
      'a function' => ['function x() {}', true],
      'a type alias' => ['type A = Data', true],
      'a type alias for a complex type' => ['type C = Hash[String[1],Integer]', true],
      'a type definition' => ['type A {}', true]
    }.each_pair do |word, (decl, at_top)|
      # Nesting level. Defines how each of the top level expressions are nested in
      # another expression
      {
        'a define' => ["define y{ #{decl} }", at_top],
        'a function' => ["function y() { #{decl} }", at_top],
        'a type definition' => ["type A { #{decl} }", at_top],
        'an if expression' => ["if true { #{decl} }", false],
        'an if-else expression' => ["if false {} else { #{decl} }", false],
        'an unless' => ["unless false { #{decl} }", false]
      }.each_pair do |nester, (source, abs_top)|
        # Tests each top level expression in each nested expression
        it "produces an error when #{word} is nested in #{nester}" do
          expect(validate(parse(source))).to have_issue(issue(abs_top))
        end
      end

      # Test that the expression can exist anywhere in a top level block

      it "will allow #{word} as the only statement in a top level block" do
        expect(validate(parse(decl))).not_to have_issue(issue(at_top))
      end

      it "will allow #{word} as the last statement in a top level block" do
        source = "$a = 10\n#{decl}"
        expect(validate(parse(source))).not_to have_issue(issue(at_top))
      end

      it "will allow #{word} as the first statement in a top level block" do
        source = "#{decl}\n$a = 10"
        expect(validate(parse(source))).not_to have_issue(issue(at_top))
      end

      it "will allow #{word} in between other statements in a top level block" do
        source = "$a = 10\n#{decl}\n$b = 20"
        expect(validate(parse(source))).not_to have_issue(issue(at_top))
      end
    end

    context 'that are type aliases' do
      it 'raises errors when RHS is a name that is an invalid reference' do
        source = 'type MyInt = integer'
        expect { parse(source) }.to raise_error(/Syntax error at 'integer'/)
      end

      it 'raises errors when RHS is an AccessExpression with a name that is an invalid reference on LHS' do
        source = 'type IntegerArray = array[Integer]'
        expect { parse(source) }.to raise_error(/Syntax error at 'array'/)
      end
    end

    context 'that are functions' do
      it 'accepts typed parameters' do
        source = <<-CODE
          function f(Integer $a) { $a }
        CODE
        expect(validate(parse(source))).not_to have_any_issues
      end

      it 'accepts return types' do
        source = <<-CODE
          function f() >> Integer { 42 }
        CODE
        expect(validate(parse(source))).not_to have_any_issues
      end

      it 'accepts block with return types' do
        source = <<-CODE
          map([1,2]) |Integer $x| >> Integer { $x + 3 }
        CODE
        expect(validate(parse(source))).not_to have_any_issues
      end
    end

    context 'that are type mappings' do
      it 'accepts a valid type mapping expression' do
        source = <<-CODE
          type Runtime[ruby, 'MyModule::MyObject'] = MyPackage::MyObject
          notice(true)
        CODE
        expect(validate(parse(source))).not_to have_any_issues
      end

      it 'accepts a valid regexp based type mapping expression' do
        source = <<-CODE
          type Runtime[ruby, [/^MyPackage::(\w+)$/, 'MyModule::\1']] = [/^MyModule::(\w+)$/, 'MyPackage::\1']
          notice(true)
        CODE
        expect(validate(parse(source))).not_to have_any_issues
      end

      it 'raises an error when a regexp based Runtime type is paired with a Puppet Type' do
        source = <<-CODE
          type Runtime[ruby, [/^MyPackage::(\w+)$/, 'MyModule::\1']] = MyPackage::MyObject
          notice(true)
        CODE
        expect(validate(parse(source))).to have_issue(Puppet::Pops::Issues::ILLEGAL_REGEXP_TYPE_MAPPING)
      end

      it 'raises an error when a singleton Runtime type is paired with replacement pattern' do
        source = <<-CODE
          type Runtime[ruby, 'MyModule::MyObject'] = [/^MyModule::(\w+)$/, 'MyPackage::\1']
          notice(true)
        CODE
        expect(validate(parse(source))).to have_issue(Puppet::Pops::Issues::ILLEGAL_SINGLE_TYPE_MAPPING)
      end

      it 'raises errors unless LHS is Runtime type' do
        source = <<-CODE
          type Pattern[/^MyPackage::(\w+)$/, 'MyModule::\1'] = [/^MyModule::(\w+)$/, 'MyPackage::\1']
          notice(true)
        CODE
        expect(validate(parse(source))).to have_issue(Puppet::Pops::Issues::UNSUPPORTED_EXPRESSION)
      end
    end
  end

  context 'top level constructs' do
    {
      'a class' => 'class x{}',
      'a define' => 'define x{}',
      'a function' => 'function x() {}',
      'a type alias' => 'type A = Data',
      'a type alias for a complex type' => 'type C = Hash[String[1],Integer]',
      'a type definition' => 'type A {}',
    }.each_pair do |word, source|
      it "will not have an issue with #{word} at the top level in a module" do
        with_environment(environment) do
          expect(validate(parse(source, 'path/x/manifests/init.pp'))).not_to have_issue(Puppet::Pops::Issues::ILLEGAL_TOP_CONSTRUCT_LOCATION)
        end
      end
    end
  end

  context 'non-top level constructs' do
    {
      'an assignment' => '$foo = 1',
      'a resource' => 'notify { nope: }',
      'a resource default' => "Notify { message => 'yo' }",
      'a function call' => "include 'foo'",
      'a node definition' => 'node default {}',
      'an expression' => '1+1',
      'a conditional' => 'if true {42}',
      'a literal value' => '42',
      'a virtual collector' => 'User <| tag == web |>',
      'an exported collector' => 'Sshkey <<| |>>',
    }.each_pair do |word, source|
      it "will have an issue with #{word} at the top level in a module" do
        with_environment(environment) do
          expect(validate(parse(source, 'path/x/manifests/init.pp'))).to have_issue(Puppet::Pops::Issues::ILLEGAL_TOP_CONSTRUCT_LOCATION)
        end
      end

      it "will not have an issue with #{word} at top level not in a module" do
        with_environment(environment) do
          expect(validate(parse(source))).not_to have_issue(Puppet::Pops::Issues::ILLEGAL_TOP_CONSTRUCT_LOCATION)
        end
      end
    end

    it "will give multiple errors in one file with multiple issues" do
      source = <<-SOURCE
      class foo {}
      notify { nope: }
      node bar {}

      $a = 7
      SOURCE

      with_environment(environment) do
        acceptor = validate(parse(source, 'path/foo/manifests/init.pp'))
        expect(deprecation_count(acceptor)).to eql(3)
        expect(acceptor.warning_count).to eql(3)
        expect(acceptor.error_count).to eql(0)

        expect(acceptor.warnings[0].source_pos.line).to eql(2)
        expect(acceptor.warnings[1].source_pos.line).to eql(3)
        expect(acceptor.warnings[2].source_pos.line).to eql(5)
      end
    end
  end

  context "capability annotations" do
    ['produces', 'consumes'].each do |word|
      it "rejects illegal resource types in #{word} clauses" do
        expect(validate(parse("foo produces Bar {}"))).to have_issue(Puppet::Pops::Issues::ILLEGAL_CLASSREF)
      end

      it "accepts legal resource and capability types in #{word} clauses" do
        expect(validate(parse("Foo produces Bar {}"))).to_not have_issue(Puppet::Pops::Issues::ILLEGAL_CLASSREF)
        expect(validate(parse("Mod::Foo produces ::Mod2::Bar {}"))).to_not have_issue(Puppet::Pops::Issues::ILLEGAL_CLASSREF)
      end

      it "rejects illegal capability types in #{word} clauses" do
        expect(validate(parse("Foo produces bar {}"))).to have_issue(Puppet::Pops::Issues::ILLEGAL_CLASSREF)
      end
    end
  end

  context 'literal values' do
    it 'rejects a literal integer outside of max signed 64 bit range' do
      expect(validate(parse("0x8000000000000000"))).to have_issue(Puppet::Pops::Issues::NUMERIC_OVERFLOW)
    end

    it 'rejects a literal integer outside of min signed 64 bit range' do
      expect(validate(parse("-0x8000000000000001"))).to have_issue(Puppet::Pops::Issues::NUMERIC_OVERFLOW)
    end
  end

  context 'uses a var pattern that is performant' do
    it 'such that illegal VAR_NAME is not too slow' do
      t = Time.now.nsec
      result = '$hg_oais::archivematica::requirements::automation_tools::USER' =~ Puppet::Pops::Patterns::VAR_NAME
      t2 = Time.now.nsec
      expect(result).to be(nil)
      expect(t2-t).to be < 1000000 # one ms as a check for very slow operation, is in fact at ~< 10 microsecond 
    end
  end

  def parse(source, path=nil)
    Puppet::Pops::Parser::Parser.new.parse_string(source, path)
  end
end
