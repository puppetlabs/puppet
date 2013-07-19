require 'spec_helper'
require 'puppet/pops'

describe "lookup function" do
  it "looks up a value that exists" do
    scope = scope_with_injections_from(bound("a_value", "something"))

    expect(scope.function_lookup(['a_value'])).to eq('something')
  end

  it "returns nil when the requested value is not bound" do
    scope = scope_with_injections_from(bound("a_value", "something"))

    expect(scope.function_lookup(['not_bound_value'])).to be_nil
  end

  def scope_with_injections_from(binder)
    injector = Puppet::Pops::Binder::Injector.new(binder)
    scope = Puppet::Parser::Scope.new_for_test_harness('testing')
    scope.compiler.injector = injector

    scope
  end

  def bound(name, value)
    bindings = Puppet::Pops::Binder::BindingsFactory.named_bindings("testing")
    bindings.bind().name(name).to(value)

    binder = Puppet::Pops::Binder::Binder.new
    binder.define_categories(Puppet::Pops::Binder::BindingsFactory.categories([]))
    binder.define_layers(Puppet::Pops::Binder::BindingsFactory.layered_bindings(Puppet::Pops::Binder::BindingsFactory.named_layer('test layer', bindings.model)))

    binder
  end
end
