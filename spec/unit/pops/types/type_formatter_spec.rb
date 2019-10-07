require 'spec_helper'
require 'puppet/pops'

module Puppet::Pops::Types
describe 'The type formatter' do
  let(:s) { TypeFormatter.new }
  let(:f) { TypeFactory }

  def drop_indent(str)
    ld = str.index("\n")
    if ld.nil?
      str
    else
      str.gsub(Regexp.compile("^ {#{ld - 1}}"), '')
    end
  end

  context 'when representing a literal as a string' do
    {
      'true' => true,
      'false' => false,
      'undef' => nil,
      '23.4' => 23.4,
      '145' => 145,
      "'string'" => 'string',
      '/expr/' => /expr/,
      '[1, 2, 3]' => [1, 2, 3],
      "{'a' => 32, 'b' => [1, 2, 3]}" => {'a' => 32,'b' => [1, 2, 3]}
    }.each_pair do |str, value|
      it "should yield '#{str}' for a value of #{str}" do
        expect(s.string(value)).to eq(str)
      end
    end
  end

  context 'when using indent' do
    it 'should put hash entries on new indented lines' do
      expect(s.indented_string({'a' => 32,'b' => [1, 2, {'c' => 'd'}]})).to eq(<<-FORMATTED)
{
  'a' => 32,
  'b' => [
    1,
    2,
    {
      'c' => 'd'
    }
  ]
}
FORMATTED
    end

    it 'should start on given indent level' do
      expect(s.indented_string({'a' => 32,'b' => [1, 2, {'c' => 'd'}]}, 3)).to eq(<<-FORMATTED)
      {
        'a' => 32,
        'b' => [
          1,
          2,
          {
            'c' => 'd'
          }
        ]
      }
FORMATTED
    end

    it 'should use given indent width' do
      expect(s.indented_string({'a' => 32,'b' => [1, 2, {'c' => 'd'}]}, 2, 4)).to eq(<<-FORMATTED)
        {
            'a' => 32,
            'b' => [
                1,
                2,
                {
                    'c' => 'd'
                }
            ]
        }
FORMATTED
    end
  end

  context 'when representing the type as string' do
    include_context 'types_setup'

    it "should yield 'Type' for PTypeType" do
      expect(s.string(f.type_type)).to eq('Type')
    end

    it "should yield 'Any' for PAnyType" do
      expect(s.string(f.any)).to eq('Any')
    end

    it "should yield 'Scalar' for PScalarType" do
      expect(s.string(f.scalar)).to eq('Scalar')
    end

    it "should yield 'Boolean' for PBooleanType" do
      expect(s.string(f.boolean)).to eq('Boolean')
    end

    it "should yield 'Boolean[true]' for PBooleanType parameterized with true" do
      expect(s.string(f.boolean(true))).to eq('Boolean[true]')
    end

    it "should yield 'Boolean[false]' for PBooleanType parameterized with false" do
      expect(s.string(f.boolean(false))).to eq('Boolean[false]')
    end

    it "should yield 'Data' for the Data type" do
      expect(s.string(f.data)).to eq('Data')
    end

    it "should yield 'Numeric' for PNumericType" do
      expect(s.string(f.numeric)).to eq('Numeric')
    end

    it "should yield 'Integer' and from/to for PIntegerType" do
      expect(s.string(f.integer)).to eq('Integer')
      expect(s.string(f.range(1,1))).to eq('Integer[1, 1]')
      expect(s.string(f.range(1,2))).to eq('Integer[1, 2]')
      expect(s.string(f.range(:default, 2))).to eq('Integer[default, 2]')
      expect(s.string(f.range(2, :default))).to eq('Integer[2]')
    end

    it "should yield 'Float' for PFloatType" do
      expect(s.string(f.float)).to eq('Float')
    end

    it "should yield 'Regexp' for PRegexpType" do
      expect(s.string(f.regexp)).to eq('Regexp')
    end

    it "should yield 'Regexp[/pat/]' for parameterized PRegexpType" do
      expect(s.string(f.regexp('a/b'))).to eq('Regexp[/a\/b/]')
    end

    it "should yield 'String' for PStringType" do
      expect(s.string(f.string)).to eq('String')
    end

    it "should yield 'String' for PStringType with value" do
      expect(s.string(f.string('a'))).to eq('String')
    end

    it "should yield 'String['a']' for PStringType with value if printed with debug_string" do
      expect(s.debug_string(f.string('a'))).to eq("String['a']")
    end

    it "should yield 'String' and from/to for PStringType" do
      expect(s.string(f.string(f.range(1,1)))).to eq('String[1, 1]')
      expect(s.string(f.string(f.range(1,2)))).to eq('String[1, 2]')
      expect(s.string(f.string(f.range(:default, 2)))).to eq('String[0, 2]')
      expect(s.string(f.string(f.range(2, :default)))).to eq('String[2]')
    end

    it "should yield 'Array[Integer]' for PArrayType[PIntegerType]" do
      expect(s.string(f.array_of(f.integer))).to eq('Array[Integer]')
    end

    it "should yield 'Array' for PArrayType::DEFAULT" do
      expect(s.string(f.array_of_any)).to eq('Array')
    end

    it "should yield 'Array[0, 0]' for an empty array" do
      t = f.array_of(PUnitType::DEFAULT, f.range(0,0))
      expect(s.string(t)).to eq('Array[0, 0]')
    end

    it "should yield 'Hash[0, 0]' for an empty hash" do
      t = f.hash_of(PUnitType::DEFAULT, PUnitType::DEFAULT, f.range(0,0))
      expect(s.string(t)).to eq('Hash[0, 0]')
    end

    it "should yield 'Collection' and from/to for PCollectionType" do
      expect(s.string(f.collection(f.range(1,1)))).to eq('Collection[1, 1]')
      expect(s.string(f.collection(f.range(1,2)))).to eq('Collection[1, 2]')
      expect(s.string(f.collection(f.range(:default, 2)))).to eq('Collection[0, 2]')
      expect(s.string(f.collection(f.range(2, :default)))).to eq('Collection[2]')
    end

    it "should yield 'Array' and from/to for PArrayType" do
      expect(s.string(f.array_of(f.string, f.range(1,1)))).to eq('Array[String, 1, 1]')
      expect(s.string(f.array_of(f.string, f.range(1,2)))).to eq('Array[String, 1, 2]')
      expect(s.string(f.array_of(f.string, f.range(:default, 2)))).to eq('Array[String, 0, 2]')
      expect(s.string(f.array_of(f.string, f.range(2, :default)))).to eq('Array[String, 2]')
    end

    it "should yield 'Iterable' for PIterableType" do
      expect(s.string(f.iterable)).to eq('Iterable')
    end

    it "should yield 'Iterable[Integer]' for PIterableType[PIntegerType]" do
      expect(s.string(f.iterable(f.integer))).to eq('Iterable[Integer]')
    end

    it "should yield 'Iterator' for PIteratorType" do
      expect(s.string(f.iterator)).to eq('Iterator')
    end

    it "should yield 'Iterator[Integer]' for PIteratorType[PIntegerType]" do
      expect(s.string(f.iterator(f.integer))).to eq('Iterator[Integer]')
    end

    it "should yield 'Timespan' for PTimespanType" do
      expect(s.string(f.timespan())).to eq('Timespan')
    end

    it "should yield 'Timespan[{hours => 1}] for PTimespanType[Timespan]" do
      expect(s.string(f.timespan({'hours' => 1}))).to eq("Timespan['0-01:00:00.0']")
    end

    it "should yield 'Timespan[default, {hours => 2}] for PTimespanType[nil, Timespan]" do
      expect(s.string(f.timespan(nil, {'hours' => 2}))).to eq("Timespan[default, '0-02:00:00.0']")
    end

    it "should yield 'Timespan[{hours => 1}, {hours => 2}] for PTimespanType[Timespan, Timespan]" do
      expect(s.string(f.timespan({'hours' => 1}, {'hours' => 2}))).to eq("Timespan['0-01:00:00.0', '0-02:00:00.0']")
    end

    it "should yield 'Timestamp' for PTimestampType" do
      expect(s.string(f.timestamp())).to eq('Timestamp')
    end

    it "should yield 'Timestamp['2016-09-05T13:00:00.000 UTC'] for PTimestampType[Timestamp]" do
      expect(s.string(f.timestamp('2016-09-05T13:00:00.000 UTC'))).to eq("Timestamp['2016-09-05T13:00:00.000000000 UTC']")
    end

    it "should yield 'Timestamp[default, '2016-09-05T13:00:00.000 UTC'] for PTimestampType[nil, Timestamp]" do
      expect(s.string(f.timestamp(nil, '2016-09-05T13:00:00.000 UTC'))).to eq("Timestamp[default, '2016-09-05T13:00:00.000000000 UTC']")
    end

    it "should yield 'Timestamp['2016-09-05T13:00:00.000 UTC', '2016-12-01T00:00:00.000 UTC'] for PTimestampType[Timestamp, Timestamp]" do
      expect(s.string(f.timestamp('2016-09-05T13:00:00.000 UTC', '2016-12-01T00:00:00.000 UTC'))).to(
        eq("Timestamp['2016-09-05T13:00:00.000000000 UTC', '2016-12-01T00:00:00.000000000 UTC']"))
    end

    it "should yield 'Tuple[Integer]' for PTupleType[PIntegerType]" do
      expect(s.string(f.tuple([f.integer]))).to eq('Tuple[Integer]')
    end

    it "should yield 'Tuple[T, T,..]' for PTupleType[T, T, ...]" do
      expect(s.string(f.tuple([f.integer, f.integer, f.string]))).to eq('Tuple[Integer, Integer, String]')
    end

    it "should yield 'Tuple' and from/to for PTupleType" do
      types = [f.string]
      expect(s.string(f.tuple(types, f.range(1,1)))).to eq('Tuple[String, 1, 1]')
      expect(s.string(f.tuple(types, f.range(1,2)))).to eq('Tuple[String, 1, 2]')
      expect(s.string(f.tuple(types, f.range(:default, 2)))).to eq('Tuple[String, 0, 2]')
      expect(s.string(f.tuple(types, f.range(2, :default)))).to eq('Tuple[String, 2]')
    end

    it "should yield 'Struct' and details for PStructType" do
      struct_t = f.struct({'a'=>Integer, 'b'=>String})
      expect(s.string(struct_t)).to eq("Struct[{'a' => Integer, 'b' => String}]")
      struct_t = f.struct({})
      expect(s.string(struct_t)).to eq('Struct')
    end

    it "should yield 'Hash[String, Integer]' for PHashType[PStringType, PIntegerType]" do
      expect(s.string(f.hash_of(f.integer, f.string))).to eq('Hash[String, Integer]')
    end

    it "should yield 'Hash' and from/to for PHashType" do
      expect(s.string(f.hash_of(f.string, f.string, f.range(1,1)))).to eq('Hash[String, String, 1, 1]')
      expect(s.string(f.hash_of(f.string, f.string, f.range(1,2)))).to eq('Hash[String, String, 1, 2]')
      expect(s.string(f.hash_of(f.string, f.string, f.range(:default, 2)))).to eq('Hash[String, String, 0, 2]')
      expect(s.string(f.hash_of(f.string, f.string, f.range(2, :default)))).to eq('Hash[String, String, 2]')
    end

    it "should yield 'Hash' for PHashType::DEFAULT" do
      expect(s.string(f.hash_of_any)).to eq('Hash')
    end

    it "should yield 'Class' for a PClassType" do
      expect(s.string(f.host_class)).to eq('Class')
    end

    it "should yield 'Class[x]' for a PClassType[x]" do
      expect(s.string(f.host_class('x'))).to eq('Class[x]')
    end

    it "should yield 'Resource' for a PResourceType" do
      expect(s.string(f.resource)).to eq('Resource')
    end

    it "should yield 'File' for a PResourceType['File']" do
      expect(s.string(f.resource('File'))).to eq('File')
    end

    it "should yield 'File['/tmp/foo']' for a PResourceType['File', '/tmp/foo']" do
      expect(s.string(f.resource('File', '/tmp/foo'))).to eq("File['/tmp/foo']")
    end

    it "should yield 'Enum[s,...]' for a PEnumType[s,...]" do
      t = f.enum('a', 'b', 'c')
      expect(s.string(t)).to eq("Enum['a', 'b', 'c']")
    end

    it "should yield 'Enum[s,...]' for a PEnumType[s,...,false]" do
      t = f.enum('a', 'b', 'c', false)
      expect(s.string(t)).to eq("Enum['a', 'b', 'c']")
    end

    it "should yield 'Enum[s,...,true]' for a PEnumType[s,...,true]" do
      t = f.enum('a', 'b', 'c', true)
      expect(s.string(t)).to eq("Enum['a', 'b', 'c', true]")
    end

    it "should yield 'Pattern[/pat/,...]' for a PPatternType['pat',...]" do
      t = f.pattern('a')
      t2 = f.pattern('a', 'b', 'c')
      expect(s.string(t)).to eq('Pattern[/a/]')
      expect(s.string(t2)).to eq('Pattern[/a/, /b/, /c/]')
    end

    it "should escape special characters in the string for a PPatternType['pat',...]" do
      t = f.pattern('a/b')
      expect(s.string(t)).to eq("Pattern[/a\\/b/]")
    end

    it "should yield 'Variant[t1,t2,...]' for a PVariantType[t1, t2,...]" do
      t1 = f.string
      t2 = f.integer
      t3 = f.pattern('a')
      t = f.variant(t1, t2, t3)
      expect(s.string(t)).to eq('Variant[String, Integer, Pattern[/a/]]')
    end

    it "should yield 'Callable' for generic callable" do
      expect(s.string(f.all_callables)).to eql('Callable')
    end

    it "should yield 'Callable[0,0]' for callable without params" do
      expect(s.string(f.callable)).to eql('Callable[0, 0]')
    end

    it "should yield 'Callable[[0,0],rt]' for callable without params but with return type" do
      expect(s.string(f.callable([], Float))).to eql('Callable[[0, 0], Float]')
    end

    it "should yield 'Callable[t,t]' for callable with typed parameters" do
      expect(s.string(f.callable(String, Integer))).to eql('Callable[String, Integer]')
    end

    it "should yield 'Callable[[t,t],rt]' for callable with typed parameters and return type" do
      expect(s.string(f.callable([String, Integer], Float))).to eql('Callable[[String, Integer], Float]')
    end

    it "should yield 'Callable[t,min,max]' for callable with size constraint (infinite max)" do
      expect(s.string(f.callable(String, 0))).to eql('Callable[String, 0]')
    end

    it "should yield 'Callable[t,min,max]' for callable with size constraint (capped max)" do
      expect(s.string(f.callable(String, 0, 3))).to eql('Callable[String, 0, 3]')
    end

    it "should yield 'Callable[min,max]' callable with size > 0" do
      expect(s.string(f.callable(0, 0))).to eql('Callable[0, 0]')
      expect(s.string(f.callable(0, 1))).to eql('Callable[0, 1]')
      expect(s.string(f.callable(0, :default))).to eql('Callable[0]')
    end

    it "should yield 'Callable[Callable]' for callable with block" do
      expect(s.string(f.callable(f.all_callables))).to eql('Callable[0, 0, Callable]')
      expect(s.string(f.callable(f.string, f.all_callables))).to eql('Callable[String, Callable]')
      expect(s.string(f.callable(f.string, 1,1, f.all_callables))).to eql('Callable[String, 1, 1, Callable]')
    end

    it 'should yield Unit for a Unit type' do
      expect(s.string(PUnitType::DEFAULT)).to eql('Unit')
    end

    it "should yield 'NotUndef' for a PNotUndefType" do
      t = f.not_undef
      expect(s.string(t)).to eq('NotUndef')
    end

    it "should yield 'NotUndef[T]' for a PNotUndefType[T]" do
      t = f.not_undef(f.data)
      expect(s.string(t)).to eq('NotUndef[Data]')
    end

    it "should yield 'NotUndef['string']' for a PNotUndefType['string']" do
      t = f.not_undef('hey')
      expect(s.string(t)).to eq("NotUndef['hey']")
    end

    it "should yield the name of an unparameterized type reference" do
      t = f.type_reference('What')
      expect(s.string(t)).to eq("TypeReference['What']")
    end

    it "should yield the name and arguments of an parameterized type reference" do
      t = f.type_reference('What[Undef, String]')
      expect(s.string(t)).to eq("TypeReference['What[Undef, String]']")
    end

    it "should yield the name of a type alias" do
      t = f.type_alias('Alias', 'Integer')
      expect(s.string(t)).to eq('Alias')
    end

    it "should yield 'Type[Runtime[ruby, Puppet]]' for the Puppet module" do
      expect(s.string(Puppet)).to eq("Runtime[ruby, 'Puppet']")
    end

    it "should yield 'Type[Runtime[ruby, Puppet::Pops]]' for the Puppet::Resource class" do
      expect(s.string(Puppet::Resource)).to eq("Runtime[ruby, 'Puppet::Resource']")
    end

    it "should yield \"SemVer['1.x', '3.x']\" for the PSemVerType['1.x', '3.x']" do
      expect(s.string(PSemVerType.new(['1.x', '3.x']))).to eq("SemVer['1.x', '3.x']")
    end

    it 'should present a valid simple name' do
      (all_types - [PTypeType, PClassType]).each do |t|
        name = t::DEFAULT.simple_name
        expect(t.name).to match("^Puppet::Pops::Types::P#{name}Type$")
      end
      expect(PTypeType::DEFAULT.simple_name).to eql('Type')
      expect(PClassType::DEFAULT.simple_name).to eql('Class')
    end
  end
end
end
