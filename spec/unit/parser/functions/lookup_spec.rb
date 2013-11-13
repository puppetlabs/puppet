require 'spec_helper'
require 'puppet/pops'
require 'stringio'

describe "lookup function" do
  before(:each) do
    Puppet[:binder] = true
  end

  it "must be called with at least a name to lookup" do
    scope = scope_with_injections_from(bound(bindings))

    expect do
      scope.function_lookup([])
    end.to raise_error(ArgumentError, /Wrong number of arguments/)
  end

  it "looks up a value that exists" do
    scope = scope_with_injections_from(bound(bind_single("a_value", "something")))
    expect(scope.function_lookup(['a_value'])).to eq('something')
  end

  it "returns :undef when the requested value is not bound and undef is accepted" do
    scope = scope_with_injections_from(bound(bind_single("a_value", "something")))
    expect(scope.function_lookup(['not_bound_value',{'accept_undef' => true}])).to eq(:undef)
  end

  it "fails if the requested value is not bound and undef is not allowed" do
    scope = scope_with_injections_from(bound(bind_single("a_value", "something")))
    expect do
      scope.function_lookup(['not_bound_value'])
    end.to raise_error(/did not find a value for the name 'not_bound_value'/)
  end

  it "returns the given default value when the requested value is not bound" do
    scope = scope_with_injections_from(bound(bind_single("a_value", "something")))
    expect(scope.function_lookup(['not_bound_value','String', 'cigar'])).to eq('cigar')
  end

  it "accepts values given in a hash of options" do
    scope = scope_with_injections_from(bound(bind_single("a_value", "something")))
    expect(scope.function_lookup(['not_bound_value',{'type' => 'String', 'default' => 'cigar'}])).to eq('cigar')
  end

  it "raises an error when the bound type is not assignable to the requested type" do
    scope = scope_with_injections_from(bound(bind_single("a_value", "something")))
    expect do
      scope.function_lookup(['a_value', 'Integer'])
    end.to raise_error(ArgumentError, /incompatible type, expected: Integer, got: String/)
  end

  it "returns the value if the bound type is assignable to the requested type" do
    typed_bindings = bindings
    typed_bindings.bind().string().name("a_value").to("something")
    scope = scope_with_injections_from(bound(typed_bindings))
    expect(scope.function_lookup(['a_value', 'Data'])).to eq("something")
  end

  it "yields to a given lambda and returns the result" do
    scope = scope_with_injections_from(bound(bind_single("a_value", "something")))
    expect(scope.function_lookup(['a_value', ast_lambda('|$x|{something_else}')])).to eq('something_else')
  end

  it "fails if given lambda produces undef" do
    scope = scope_with_injections_from(bound(bind_single("a_value", "something")))
    expect do
      scope.function_lookup(['a_value', ast_lambda('|$x|{undef}')])
    end.to raise_error(/did not find a value for the name 'a_value'/)
  end

  it "yields name and result to a given lambda" do
    scope = scope_with_injections_from(bound(bind_single("a_value", "something")))
    expect(scope.function_lookup(['a_value', ast_lambda('|$name, $result|{[$name, $result]}')])).to eq(['a_value', 'something'])
  end

  it "yields name and result and default to a given lambda" do
    scope = scope_with_injections_from(bound(bind_single("a_value", "something")))
    expect(scope.function_lookup(['a_value', {'default' => 'cigar'}, 
      ast_lambda('|$name, $result, $d|{[$name, $result, $d]}')])).to eq(['a_value', 'something', 'cigar'])
  end

  it "yields to a given lambda and returns the result when giving name and type" do
    scope = scope_with_injections_from(bound(bind_single("a_value", "something")))
    expect(scope.function_lookup(['a_value', 'String', ast_lambda('|$x|{something_else}')])).to eq('something_else')
  end

  it "yields :undef when value is not found and using a lambda" do
    scope = scope_with_injections_from(bound(bind_single("a_value", "something")))
    expect(scope.function_lookup(['not_bound_value', ast_lambda('|$x|{ if $x == undef {good} else {bad}}')])).to eq('good')
  end

  def scope_with_injections_from(binder)
    injector = Puppet::Pops::Binder::Injector.new(binder)
    scope = Puppet::Parser::Scope.new_for_test_harness('testing')
    scope.compiler.injector = injector
    scope
  end

  def bindings
    Puppet::Pops::Binder::BindingsFactory.named_bindings("testing")
  end

  def bind_single(name, value)
    local_bindings = Puppet::Pops::Binder::BindingsFactory.named_bindings("testing")
    local_bindings.bind().name(name).to(value)
    local_bindings
  end

  def bound(local_bindings)
    binder = Puppet::Pops::Binder::Binder.new
    binder.define_categories(Puppet::Pops::Binder::BindingsFactory.categories([]))
    binder.define_layers(Puppet::Pops::Binder::BindingsFactory.layered_bindings(Puppet::Pops::Binder::BindingsFactory.named_layer('test layer', local_bindings.model)))
    binder
  end

  def ast_lambda(puppet_source)
    puppet_source = "fake_func() " + puppet_source
    model = Puppet::Pops::Parser::EvaluatingParser.new().parse_string(puppet_source, __FILE__).current
    model = model.lambda
    Puppet::Pops::Model::AstTransformer.new(@file_source, nil).transform(model)
  end
end
