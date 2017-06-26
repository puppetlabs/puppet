require 'spec_helper'
require 'puppet/pops/types/type_acceptor'

class PuppetSpec::TestTypeAcceptor
  include Puppet::Pops::Types::TypeAcceptor
  attr_reader :visitors, :guard

  def initialize
    @visitors = []
    @guard = nil
  end

  def visit(type, guard)
    @visitors << type
    @guard = guard
  end
end

module Puppet::Pops::Types
describe 'the Puppet::Pops::Types::TypeAcceptor' do

  let!(:acceptor_class) { PuppetSpec::TestTypeAcceptor }

  let(:acceptor) { acceptor_class.new }
  let(:guard) { RecursionGuard.new }

  it "should get a visit from the type that accepts it" do
    PAnyType::DEFAULT.accept(acceptor, nil)
    expect(acceptor.visitors).to include(PAnyType::DEFAULT)
  end

  it "should receive the guard as an argument" do
    PAnyType::DEFAULT.accept(acceptor, guard)
    expect(acceptor.guard).to equal(guard)
  end

  it "should get a visit from the type of a Type that accepts it" do
    t = PTypeType.new(PAnyType::DEFAULT)
    t.accept(acceptor, nil)
    expect(acceptor.visitors).to include(t, PAnyType::DEFAULT)
  end

  [
    PTypeType,
    PNotUndefType,
    PIterableType,
    PIteratorType,
    POptionalType
  ].each do |tc|
    it "should get a visit from the contained type of an #{tc.class.name} that accepts it" do
      t = tc.new(PStringType::DEFAULT)
      t.accept(acceptor, nil)
      expect(acceptor.visitors).to include(t, PStringType::DEFAULT)
    end
  end

  it "should get a visit from the size type of String type that accepts it" do
    sz = PIntegerType.new(0,4)
    t = PStringType.new(sz)
    t.accept(acceptor, nil)
    expect(acceptor.visitors).to include(t, sz)
  end

  it "should get a visit from all contained types of an Array type that accepts it" do
    sz = PIntegerType.new(0,4)
    t = PArrayType.new(PAnyType::DEFAULT, sz)
    t.accept(acceptor, nil)
    expect(acceptor.visitors).to include(t, PAnyType::DEFAULT, sz)
  end

  it "should get a visit from all contained types of a Hash type that accepts it" do
    sz = PIntegerType.new(0,4)
    t = PHashType.new(PStringType::DEFAULT, PAnyType::DEFAULT, sz)
    t.accept(acceptor, nil)
    expect(acceptor.visitors).to include(t, PStringType::DEFAULT, PAnyType::DEFAULT, sz)
  end

  it "should get a visit from all contained types of a Tuple type that accepts it" do
    sz = PIntegerType.new(0,4)
    t = PTupleType.new([PStringType::DEFAULT, PIntegerType::DEFAULT], sz)
    t.accept(acceptor, nil)
    expect(acceptor.visitors).to include(t, PStringType::DEFAULT, PIntegerType::DEFAULT, sz)
  end

  it "should get a visit from all contained types of a Struct type that accepts it" do
    t = PStructType.new([PStructElement.new(PStringType::DEFAULT, PIntegerType::DEFAULT)])
    t.accept(acceptor, nil)
    expect(acceptor.visitors).to include(t, PStringType::DEFAULT, PIntegerType::DEFAULT)
  end

  it "should get a visit from all contained types of a Callable type that accepts it" do
    sz = PIntegerType.new(0,4)
    args = PTupleType.new([PStringType::DEFAULT, PIntegerType::DEFAULT], sz)
    block = PCallableType::DEFAULT
    t = PCallableType.new(args, block)
    t.accept(acceptor, nil)
    expect(acceptor.visitors).to include(t, PStringType::DEFAULT, PIntegerType::DEFAULT, sz, args, block)
  end

  it "should get a visit from all contained types of a Variant type that accepts it" do
    t = PVariantType.new([PStringType::DEFAULT, PIntegerType::DEFAULT])
    t.accept(acceptor, nil)
    expect(acceptor.visitors).to include(t, PStringType::DEFAULT, PIntegerType::DEFAULT)
  end
end
end
