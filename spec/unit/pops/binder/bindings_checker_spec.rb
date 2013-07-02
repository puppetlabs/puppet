require 'spec_helper'
require 'puppet/pops'

module BindingsChecker_Test

  describe 'The bindings checker' do

    # Checks if an Acceptor has a specific issue in its list of diagnostics
    matcher :have_issue do |expected|
      match do |actual|
        actual.diagnostics.index { |i| i.issue == expected } != nil
      end
      failure_message_for_should do |actual|
        "expected Acceptor[#{actual.diagnostics.collect { |i| i.issue.issue_code }.join(',')}] to contain issue #{expected.issue_code}"
      end
    end

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

    def category(name, value)
      b = Bindings::Category.new()
      b.categorization = name
      b.value = value
      b
    end

    def categorized_bindings(bindings, *predicates)
      b = Bindings::CategorizedBindings.new()
      b.bindings = bindings
      b.predicates = predicates
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
      acceptor.should have_issue(Issues::MISSING_PRODUCER)
      acceptor.should have_issue(Issues::MISSING_TYPE)
    end

    context 'when checking array multibinding' do
      it 'should complain about non array producers' do
        validate(bad_array_multibinding())
        acceptor.should have_issue(Issues::MULTIBIND_INCOMPATIBLE_TYPE)
      end
    end

    context 'when checking hash multibinding' do
      it 'should complain about non hash producers' do
        validate(bad_hash_multibinding())
        acceptor.should have_issue(Issues::MULTIBIND_INCOMPATIBLE_TYPE)
      end
    end

    context 'when checking bindings' do
      it 'should not accept zero bindings' do
        validate(bindings())
        acceptor.should have_issue(Issues::MISSING_BINDINGS)
      end

      it 'should accept non-zero bindings' do
        validate(bindings(ok_binding))
        acceptor.errors_or_warnings?.should() == false
      end

      it 'should check contained bindings' do
        validate(bindings(bad_array_multibinding()))
        acceptor.should have_issue(Issues::MULTIBIND_INCOMPATIBLE_TYPE)
      end
    end

    context 'when checking named bindings' do
      it 'should accept named bindings' do
        validate(named_bindings('garfield', ok_binding))
        acceptor.errors_or_warnings?.should() == false
      end

      it 'should not accept unnamed bindings' do
        validate(named_bindings(nil, ok_binding))
        acceptor.should have_issue(Issues::MISSING_BINDINGS_NAME)
      end

      it 'should do generic bindings check' do
        validate(named_bindings('garfield'))
        acceptor.should have_issue(Issues::MISSING_BINDINGS)
      end
    end

    context 'when checking categorized bindings' do
      it 'should accept non-zero predicates' do
        validate(categorized_bindings([ok_binding], category('foo', 'bar')))
        acceptor.errors_or_warnings?.should() == false
      end

      it 'should not accept zero predicates' do
        validate(categorized_bindings([ok_binding]))
        acceptor.should have_issue(Issues::MISSING_PREDICATES)
      end

      it 'should not accept predicates that has no categorization' do
        validate(categorized_bindings([ok_binding], category(nil, 'bar')))
        acceptor.should have_issue(Issues::MISSING_CATEGORIZATION)
      end

      it 'should not accept predicates that has no value' do
        validate(categorized_bindings([ok_binding], category('foo', nil)))
        acceptor.should have_issue(Issues::MISSING_CATEGORY_VALUE)
      end

      it 'should do generic bindings check' do
        validate(categorized_bindings([], category('foo', 'bar')))
        acceptor.should have_issue(Issues::MISSING_BINDINGS)
      end
    end

    context 'when checking layered bindings' do
      it 'should not accept zero layers' do
        validate(layered_bindings())
        acceptor.should have_issue(Issues::MISSING_LAYERS)
      end

      it 'should accept non-zero layers' do
        validate(layered_bindings(layer('foo', named_bindings('bar', ok_binding))))
        acceptor.errors_or_warnings?.should() == false
      end

      it 'should not accept unnamed layers' do
        validate(layered_bindings(layer(nil, named_bindings('bar', ok_binding))))
        acceptor.should have_issue(Issues::MISSING_LAYER_NAME)
      end

      it 'should not accept layers without bindings' do
        validate(layered_bindings(layer('foo')))
        acceptor.should have_issue(Issues::MISSING_BINDINGS_IN_LAYER)
      end
    end
  end
end
