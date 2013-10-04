require 'spec_helper'
require 'puppet/pops'
require 'puppet_spec/pops'

describe 'The hiera2 bindings provider' do

  include PuppetSpec::Pops

  def config_dir(config_name)
    File.dirname(my_fixture("#{config_name}/hiera.yaml"))
  end

  before(:each) do
    Puppet[:binder] = true
  end

  context 'when loading ok bindings' do

    let(:node) { 'node.example.com' }
    let(:acceptor) {  Puppet::Pops::Validation::Acceptor.new() }
    let(:scope) { s = Puppet::Parser::Scope.new_for_test_harness(node); s['a'] = '42'; s['node'] = node; s }
    let(:module_dir) { config_dir('ok') }
    let(:node_binder) {  b = Puppet::Pops::Binder::Binder.new(); b.define_categories(Puppet::Pops::Binder::BindingsFactory.categories(['node', node])); b }
    let(:bindings) { Puppet::Pops::Binder::Hiera2::BindingsProvider.new('test', module_dir, acceptor).load_bindings(scope) }
    let(:test_layer_with_bindings) { bindings }

    it 'should load and validate OK bindings' do
      Puppet::Pops::Binder::BindingsValidatorFactory.new().validator(acceptor).validate(bindings)
      acceptor.errors_or_warnings?.should() == false
    end

    it 'should contain the expected effective categories' do
      bindings.effective_categories.categories.collect {|c| [c.categorization, c.value] }.should == [['node', 'node.example.com']]
    end

    it 'should produce the expected bindings model' do
      bindings.class.should() == Puppet::Pops::Binder::Bindings::ContributedBindings
      bindings.bindings.bindings.each do |cat|
        cat.class.should() == Puppet::Pops::Binder::Bindings::CategorizedBindings
        cat.predicates.length.should() == 1
        cat.predicates[0].categorization.should() == 'node'
        cat.predicates[0].value.should() == node
        cat.bindings.each do |b|
          b.class.should() == Puppet::Pops::Binder::Bindings::Binding
          ['a_number', 'a_string', 'an_eval', 'an_eval2', 'a_json_number', 'a_json_string', 'a_json_eval',
            'a_json_eval2', 'a_json_hash', 'a_json_array'].index(b.name).should() >= 0
          b.producer.class.should() == Puppet::Pops::Binder::Bindings::EvaluatingProducerDescriptor if b.name == 'an_eval'
        end
      end
    end

    it 'should make the injector lookup expected constants' do
      node_binder.define_layers(Puppet::Pops::Binder::BindingsFactory.layered_bindings(test_layer_with_bindings))
      injector = Puppet::Pops::Binder::Injector.new(node_binder)

      injector.lookup(scope, 'a_number').should == 42
      injector.lookup(scope, 'a_string').should == 'forty two'
      injector.lookup(scope, 'a_json_number').should == 142
      injector.lookup(scope, 'a_json_string').should == 'one hundred and forty two'
      expect(injector.lookup(scope, "a_json_array")).to be == ["a", "b", 100]
      expect(injector.lookup(scope, "a_json_hash")).to be == {"a"  => 1, "b" => 2}
    end

    it 'should make the injector lookup and evaluate expressions' do
      node_binder.define_layers(Puppet::Pops::Binder::BindingsFactory.layered_bindings(test_layer_with_bindings))
      injector = Puppet::Pops::Binder::Injector.new(node_binder)

      injector.lookup(scope, 'an_eval').should == 'the answer from "yaml" is 42.'
      injector.lookup(scope, 'an_eval2').should == "the answer\nfrom \\\"yaml\\\" is 42 and $a"
      injector.lookup(scope, 'a_json_eval').should == 'the answer from "json" is 42 and ${a}.'
      injector.lookup(scope, 'a_json_eval2').should == "the answer\nfrom \\\"json\\\" is 42 and $a"
    end
  end
end
