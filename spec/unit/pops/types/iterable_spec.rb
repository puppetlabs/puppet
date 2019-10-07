require 'spec_helper'
require 'puppet/pops'

module Puppet::Pops::Types
describe 'The iterable support' do

  [
    0,
    5,
    (3..10),
    %w(a b c),
    {'a'=>2},
    'hello',
    PIntegerType.new(1, 4),
    PEnumType.new(%w(yes no))
  ].each do |obj|
    it "should consider instances of #{obj.class.name} to be Iterable" do
      expect(PIterableType::DEFAULT.instance?(obj)).to eq(true)
    end

    it "should yield an Iterable instance when Iterable.on is called with a #{obj.class.name}" do
      expect(Iterable.on(obj)).to be_a(Iterable)
    end
  end

  {
    -1 => 'a negative Integer',
    5.times => 'an Enumerable',
    PIntegerType.new(nil, nil) => 'an unbounded Integer type'
  }.each_pair do |obj, desc|
    it "does not consider #{desc} to be Iterable" do
      expect(PIterableType::DEFAULT.instance?(obj)).to eq(false)
    end

    it "does not yield an Iterable when Iterable.on is called with #{desc}" do
      expect(Iterable.on(obj)).to be_nil
    end
  end

  context 'when testing assignability' do
    iterable_types = [
      PIntegerType::DEFAULT,
      PStringType::DEFAULT,
      PIterableType::DEFAULT,
      PIteratorType::DEFAULT,
      PCollectionType::DEFAULT,
      PArrayType::DEFAULT,
      PHashType::DEFAULT,
      PTupleType::DEFAULT,
      PStructType::DEFAULT,
      PUnitType::DEFAULT
    ]
    iterable_types << PTypeType.new(PIntegerType.new(0, 10))
    iterable_types << PTypeType.new(PEnumType.new(%w(yes no)))
    iterable_types << PRuntimeType.new(:ruby, 'Puppet::Pops::Types::Iterator')
    iterable_types << PVariantType.new(iterable_types.clone)

    not_iterable_types = [
      PAnyType::DEFAULT,
      PBooleanType::DEFAULT,
      PCallableType::DEFAULT,
      PCatalogEntryType::DEFAULT,
      PDefaultType::DEFAULT,
      PFloatType::DEFAULT,
      PClassType::DEFAULT,
      PNotUndefType::DEFAULT,
      PNumericType::DEFAULT,
      POptionalType::DEFAULT,
      PPatternType::DEFAULT,
      PRegexpType::DEFAULT,
      PResourceType::DEFAULT,
      PRuntimeType::DEFAULT,
      PScalarType::DEFAULT,
      PScalarDataType::DEFAULT,
      PTypeType::DEFAULT,
      PUndefType::DEFAULT
    ]
    not_iterable_types << PTypeType.new(PIntegerType::DEFAULT)
    not_iterable_types << PVariantType.new([iterable_types[0], not_iterable_types[0]])

    iterable_types.each do |type|
      it "should consider #{type} to be assignable to Iterable type" do
        expect(PIterableType::DEFAULT.assignable?(type)).to eq(true)
      end
    end

    not_iterable_types.each do |type|
      it "should not consider #{type} to be assignable to Iterable type" do
        expect(PIterableType::DEFAULT.assignable?(type)).to eq(false)
      end
    end

    it "should consider Type[Integer[0,5]] to be assignable to Iterable[Integer[0,5]]" do
      expect(PIterableType.new(PIntegerType.new(0,5)).assignable?(PTypeType.new(PIntegerType.new(0,5)))).to eq(true)
    end

    it "should consider Type[Enum[yes,no]] to be assignable to Iterable[Enum[yes,no]]" do
      expect(PIterableType.new(PEnumType.new(%w(yes no))).assignable?(PTypeType.new(PEnumType.new(%w(yes no))))).to eq(true)
    end

    it "should not consider Type[Enum[ok,fail]] to be assignable to Iterable[Enum[yes,no]]" do
      expect(PIterableType.new(PEnumType.new(%w(ok fail))).assignable?(PTypeType.new(PEnumType.new(%w(yes no))))).to eq(false)
    end

    it "should not consider Type[String] to be assignable to Iterable[String]" do
      expect(PIterableType.new(PStringType::DEFAULT).assignable?(PTypeType.new(PStringType::DEFAULT))).to eq(false)
    end
  end

  it 'does not wrap an Iterable in another Iterable' do
    x = Iterable.on(5)
    expect(Iterable.on(x)).to equal(x)
  end

  it 'produces a "times" iterable on integer' do
    expect{ |b| Iterable.on(3).each(&b) }.to yield_successive_args(0,1,2)
  end

  it 'produces an iterable with element type Integer[0,X-1] for an iterable on an integer X' do
    expect(Iterable.on(3).element_type).to eq(PIntegerType.new(0,2))
  end

  it 'produces a step iterable on an integer' do
    expect{ |b| Iterable.on(8).step(3, &b) }.to yield_successive_args(0, 3, 6)
  end

  it 'produces a reverse iterable on an integer' do
    expect{ |b| Iterable.on(5).reverse_each(&b) }.to yield_successive_args(4,3,2,1,0)
  end

  it 'produces an iterable on a integer range' do
    expect{ |b| Iterable.on(2..7).each(&b) }.to yield_successive_args(2,3,4,5,6,7)
  end

  it 'produces an iterable with element type Integer[X,Y] for an iterable on an integer range (X..Y)' do
    expect(Iterable.on(2..7).element_type).to eq(PIntegerType.new(2,7))
  end

  it 'produces an iterable on a character range' do
    expect{ |b| Iterable.on('a'..'f').each(&b) }.to yield_successive_args('a', 'b', 'c', 'd', 'e', 'f')
  end

  it 'produces a step iterable on a range' do
    expect{ |b| Iterable.on(1..5).step(2, &b) }.to yield_successive_args(1,3,5)
  end

  it 'produces a reverse iterable on a range' do
    expect{ |b| Iterable.on(2..7).reverse_each(&b) }.to yield_successive_args(7,6,5,4,3,2)
  end

  it 'produces an iterable with element type String with a size constraint for an iterable on a character range' do
    expect(Iterable.on('a'..'fe').element_type).to eq(PStringType.new(PIntegerType.new(1,2)))
  end

  it 'produces an iterable on a bounded Integer type' do
    expect{ |b| Iterable.on(PIntegerType.new(2,7)).each(&b) }.to yield_successive_args(2,3,4,5,6,7)
  end

  it 'produces an iterable with element type Integer[X,Y] for an iterable on Integer[X,Y]' do
    expect(Iterable.on(PIntegerType.new(2,7)).element_type).to eq(PIntegerType.new(2,7))
  end

  it 'produces an iterable on String' do
    expect{ |b| Iterable.on('eat this').each(&b) }.to yield_successive_args('e', 'a', 't', ' ', 't', 'h', 'i', 's')
  end

  it 'produces an iterable with element type String[1,1] for an iterable created on a String' do
    expect(Iterable.on('eat this').element_type).to eq(PStringType.new(PIntegerType.new(1,1)))
 end

  it 'produces an iterable on Array' do
    expect{ |b| Iterable.on([1,5,9]).each(&b) }.to yield_successive_args(1,5,9)
  end

  it 'produces an iterable with element type inferred from the array elements for an iterable on Array' do
    expect(Iterable.on([1,5,5,9,9,9]).element_type).to eq(PVariantType.new([PIntegerType.new(1,1), PIntegerType.new(5,5), PIntegerType.new(9,9)]))
  end

  it 'can chain reverse_each after step on Iterable' do
    expect{ |b| Iterable.on(6).step(2).reverse_each(&b) }.to yield_successive_args(4,2,0)
  end

  it 'can chain reverse_each after step on Integer range' do
    expect{ |b| Iterable.on(PIntegerType.new(0, 5)).step(2).reverse_each(&b) }.to yield_successive_args(4,2,0)
  end

  it 'can chain step after reverse_each on Iterable' do
    expect{ |b| Iterable.on(6).reverse_each.step(2, &b) }.to yield_successive_args(5,3,1)
  end

  it 'can chain step after reverse_each on Integer range' do
    expect{ |b| Iterable.on(PIntegerType.new(0, 5)).reverse_each.step(2, &b) }.to yield_successive_args(5,3,1)
  end

  it 'will produce the same result for each as for reverse_each.reverse_each' do
    x1 = Iterable.on(5)
    x2 = Iterable.on(5)
    expect(x1.reduce([]) { |a,i| a << i; a}).to eq(x2.reverse_each.reverse_each.reduce([]) { |a,i| a << i; a})
  end

  it 'can chain many nested step/reverse_each calls' do
    # x = Iterable.on(18).step(3) (0, 3, 6, 9, 12, 15)
    # x = x.reverse_each (15, 12, 9, 6, 3, 0)
    # x = x.step(2) (15, 9, 3)
    # x = x.reverse_each(3, 9, 15)
    expect{ |b| Iterable.on(18).step(3).reverse_each.step(2).reverse_each(&b) }.to yield_successive_args(3, 9, 15)
  end

  it 'can chain many nested step/reverse_each calls on Array iterable' do
    expect{ |b| Iterable.on(18.times.to_a).step(3).reverse_each.step(2).reverse_each(&b) }.to yield_successive_args(3, 9, 15)
  end

  it 'produces an steppable iterable for Array' do
    expect{ |b| Iterable.on(%w(a b c d e f g h i)).step(3, &b) }.to yield_successive_args('a', 'd', 'g')
  end

  it 'produces an reverse steppable iterable for Array' do
    expect{ |b| Iterable.on(%w(a b c d e f g h i)).reverse_each.step(3, &b) }.to yield_successive_args('i', 'f', 'c')
  end

  it 'responds false when a bounded Iterable is passed to Iterable.unbounded?' do
    expect(Iterable.unbounded?(Iterable.on(%w(a b c d e f g h i)))).to eq(false)
  end

  it 'can create an Array from a bounded Iterable' do
    expect(Iterable.on(%w(a b c d e f g h i)).to_a).to eq(%w(a b c d e f g h i))
  end

  class TestUnboundedIterator
    include Enumerable
    include Iterable

    def step(step_size)
      if block_given?
        begin
          current = 0
          loop do
            yield(@current)
            current = current + step_size
          end
        rescue StopIteration
        end
      end
      self
    end
  end

  it 'responds true when an unbounded Iterable is passed to Iterable.unbounded?' do
    ubi = TestUnboundedIterator.new
    expect(Iterable.unbounded?(Iterable.on(ubi))).to eq(true)
  end

  it 'can not create an Array from an unbounded Iterable' do
    ubi = TestUnboundedIterator.new
    expect{ Iterable.on(ubi).to_a }.to raise_error(Puppet::Error, /Attempt to create an Array from an unbounded Iterable/)
  end

  it 'will produce the string Iterator[T] on to_s on an iterator instance with element type T' do
    expect(Iterable.on(18).to_s).to eq('Iterator[Integer]-Value')
  end
end
end
