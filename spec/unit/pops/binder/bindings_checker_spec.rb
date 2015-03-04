require 'spec_helper'
require 'puppet/pops'
require 'puppet_spec/pops'

describe 'The bindings checker' do

  include PuppetSpec::Pops

  Issues = Puppet::Pops::Binder::BinderIssues
  Bindings = Puppet::Pops::Binder::Bindings
  TypeFactory = Puppet::Pops::Types::TypeFactory
  let (:acceptor) {  Puppet::Pops::Validation::Acceptor.new() }

  let (:binding) { Bindings::Binding.new() }

  let (:ok_binding) {
    b = Bindings::Binding.new()
    b.producer = Bindings::ConstantProducerDescriptor.new()
    b.producer.value = 'some value'
    b.type = TypeFactory.string()
    b
  }

  def validate(binding)
    Puppet::Pops::Binder::BindingsValidatorFactory.new().validator(acceptor).validate(binding)
  end

  def bindings(*args)
    b = Bindings::Bindings.new()
    b.bindings = args
    b
  end

  def named_bindings(name, *args)
    b = Bindings::NamedBindings.new()
    b.name = name
    b.bindings = args
    b
  end

  def layer(name, *bindings)
    l = Bindings::NamedLayer.new()
    l.name = name
    l.bindings = bindings
    l
  end

  def layered_bindings(*layers)
    b = Bindings::LayeredBindings.new()
    b.layers = layers
    b
  end

  def array_multibinding()
    b = Bindings::Multibinding.new()
    b.producer = Bindings::ArrayMultibindProducerDescriptor.new()
    b.type = TypeFactory.array_of_data()
    b
  end

  def bad_array_multibinding()
    b = array_multibinding()
    b.type = TypeFactory.hash_of_data() # intentionally wrong!
    b
  end

  def hash_multibinding()
    b = Bindings::Multibinding.new()
    b.producer = Bindings::HashMultibindProducerDescriptor.new()
    b.type = TypeFactory.hash_of_data()
    b
  end

  def bad_hash_multibinding()
    b = hash_multibinding()
    b.type = TypeFactory.array_of_data() # intentionally wrong!
    b
  end

  it 'should complain about missing producer and type' do
    validate(binding())
    expect(acceptor).to have_issue(Issues::MISSING_PRODUCER)
    expect(acceptor).to have_issue(Issues::MISSING_TYPE)
  end

  context 'when checking array multibinding' do
    it 'should complain about non array producers' do
      validate(bad_array_multibinding())
      expect(acceptor).to have_issue(Issues::MULTIBIND_INCOMPATIBLE_TYPE)
    end
  end

  context 'when checking hash multibinding' do
    it 'should complain about non hash producers' do
      validate(bad_hash_multibinding())
      expect(acceptor).to have_issue(Issues::MULTIBIND_INCOMPATIBLE_TYPE)
    end
  end

  context 'when checking bindings' do
    it 'should not accept zero bindings' do
      validate(bindings())
      expect(acceptor).to have_issue(Issues::MISSING_BINDINGS)
    end

    it 'should accept non-zero bindings' do
      validate(bindings(ok_binding))
      expect(acceptor.errors_or_warnings?).to eq(false)
    end

    it 'should check contained bindings' do
      validate(bindings(bad_array_multibinding()))
      expect(acceptor).to have_issue(Issues::MULTIBIND_INCOMPATIBLE_TYPE)
    end
  end

  context 'when checking named bindings' do
    it 'should accept named bindings' do
      validate(named_bindings('garfield', ok_binding))
      expect(acceptor.errors_or_warnings?).to eq(false)
    end

    it 'should not accept unnamed bindings' do
      validate(named_bindings(nil, ok_binding))
      expect(acceptor).to have_issue(Issues::MISSING_BINDINGS_NAME)
    end

    it 'should do generic bindings check' do
      validate(named_bindings('garfield'))
      expect(acceptor).to have_issue(Issues::MISSING_BINDINGS)
    end
  end

  context 'when checking layered bindings' do
    it 'should not accept zero layers' do
      validate(layered_bindings())
      expect(acceptor).to have_issue(Issues::MISSING_LAYERS)
    end

    it 'should accept non-zero layers' do
      validate(layered_bindings(layer('foo', named_bindings('bar', ok_binding))))
      expect(acceptor.errors_or_warnings?).to eq(false)
    end

    it 'should not accept unnamed layers' do
      validate(layered_bindings(layer(nil, named_bindings('bar', ok_binding))))
      expect(acceptor).to have_issue(Issues::MISSING_LAYER_NAME)
    end

    it 'should accept layers without bindings' do
      validate(layered_bindings(layer('foo')))
      expect(acceptor).not_to have_issue(Issues::MISSING_BINDINGS_IN_LAYER)
    end
  end
end
