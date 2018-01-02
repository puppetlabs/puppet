require 'spec_helper'
require 'puppet/pops'

module Puppet::Pops
module Serialization
  describe 'Passing values through ToDataConverter/FromDataConverter' do
  let(:dumper) { Model::ModelTreeDumper.new }
  let(:io) { StringIO.new }
  let(:parser) { Parser::EvaluatingParser.new }
  let(:env) { Puppet::Node::Environment.create(:testing, []) }
  let(:loaders) { Puppet::Pops::Loaders.new(env) }
  let(:loader) { loaders.find_loader(nil) }
  let(:to_converter) { ToDataConverter.new(:rich_data => true) }
  let(:from_converter) { FromDataConverter.new(:loader => loader) }

  before(:each) do
    Puppet.lookup(:environments).clear_all
    Puppet.push_context(:loaders => loaders, :current_environment => env)
  end

  after(:each) do
    Puppet.pop_context
  end

  def write(value)
    io.reopen
    value = to_converter.convert(value)
    expect(Types::TypeFactory.data).to be_instance(value)
    io << [value].to_json
    io.rewind
  end

  def read
    from_converter.convert(::JSON.parse(io.read)[0])
  end

  def parse(string)
    parser.parse_string(string, '/home/tester/experiments/manifests/init.pp')
  end

  context 'can write and read a' do
    it 'String' do
      val = 'the value'
      write(val)
      val2 = read
      expect(val2).to be_a(String)
      expect(val2).to eql(val)
    end

    it 'Integer' do
      val = 32
      write(val)
      val2 = read
      expect(val2).to be_a(Integer)
      expect(val2).to eql(val)
    end

    it 'Float' do
      val = 32.45
      write(val)
      val2 = read
      expect(val2).to be_a(Float)
      expect(val2).to eql(val)
    end

    it 'true' do
      val = true
      write(val)
      val2 = read
      expect(val2).to be_a(TrueClass)
      expect(val2).to eql(val)
    end

    it 'false' do
      val = false
      write(val)
      val2 = read
      expect(val2).to be_a(FalseClass)
      expect(val2).to eql(val)
    end

    it 'nil' do
      val = nil
      write(val)
      val2 = read
      expect(val2).to be_a(NilClass)
      expect(val2).to eql(val)
    end

    it 'Regexp' do
      val = /match me/
      write(val)
      val2 = read
      expect(val2).to be_a(Regexp)
      expect(val2).to eql(val)
    end

    it 'Sensitive' do
      sval = 'the sensitive value'
      val = Types::PSensitiveType::Sensitive.new(sval)
      write(val)
      val2 = read
      expect(val2).to be_a(Types::PSensitiveType::Sensitive)
      expect(val2.unwrap).to eql(sval)
    end

    it 'Timespan' do
      val = Time::Timespan.from_fields(false, 3, 12, 40, 31, 123)
      write(val)
      val2 = read
      expect(val2).to be_a(Time::Timespan)
      expect(val2).to eql(val)
    end

    it 'Timestamp' do
      val = Time::Timestamp.now
      write(val)
      val2 = read
      expect(val2).to be_a(Time::Timestamp)
      expect(val2).to eql(val)
    end

    it 'Version' do
      # It does succeed on rare occasions, so we need to repeat
      val = SemanticPuppet::Version.parse('1.2.3-alpha2')
      write(val)
      val2 = read
      expect(val2).to be_a(SemanticPuppet::Version)
      expect(val2).to eql(val)
    end

    it 'VersionRange' do
      # It does succeed on rare occasions, so we need to repeat
      val = SemanticPuppet::VersionRange.parse('>=1.2.3-alpha2 <1.2.4')
      write(val)
      val2 = read
      expect(val2).to be_a(SemanticPuppet::VersionRange)
      expect(val2).to eql(val)
    end

    it 'Binary' do
      val = Types::PBinaryType::Binary.from_base64('w5ZzdGVuIG1lZCByw7ZzdGVuCg==')
      write(val)
      val2 = read
      expect(val2).to be_a(Types::PBinaryType::Binary)
      expect(val2).to eql(val)
    end

    it 'URI' do
      val = URI('http://bob:ewing@dallas.example.com:8080/oil/baron?crude=cash#leftovers')
      write(val)
      val2 = read
      expect(val2).to be_a(URI)
      expect(val2).to eql(val)
    end

    it 'Sensitive with rich data' do
      sval = Time::Timestamp.now
      val = Types::PSensitiveType::Sensitive.new(sval)
      write(val)
      val2 = read
      expect(val2).to be_a(Types::PSensitiveType::Sensitive)
      expect(val2.unwrap).to be_a(Time::Timestamp)
      expect(val2.unwrap).to eql(sval)
    end

    it 'Hash with Symbol keys' do
      val = { :one => 'one', :two => 'two' }
      write(val)
      val2 = read
      expect(val2).to be_a(Hash)
      expect(val2).to eql(val)
    end

    it 'Hash with Integer keys' do
      val = { 1 => 'one', 2 => 'two' }
      write(val)
      val2 = read
      expect(val2).to be_a(Hash)
      expect(val2).to eql(val)
    end

    it 'A Hash that references itself' do
      val = {}
      val['myself'] = val
      write(val)
      val2 = read
      expect(val2).to be_a(Hash)
      expect(val2['myself']).to equal(val2)
    end
  end

  context 'can write and read' do
    include_context 'types_setup'

    all_types.each do |t|
      it "the default for type #{t.name}" do
        val = t::DEFAULT
        write(val)
        val2 = read
        expect(val2).to be_a(t)
        expect(val2).to eql(val)
      end
    end

    context 'a parameterized' do
      it 'String' do
        val = Types::TypeFactory.string(Types::TypeFactory.range(1, :default))
        write(val)
        val2 = read
        expect(val2).to be_a(Types::PStringType)
        expect(val2).to eql(val)
      end

      it 'Regex' do
        val = Types::TypeFactory.regexp(/foo/)
        write(val)
        val2 = read
        expect(val2).to be_a(Types::PRegexpType)
        expect(val2).to eql(val)
      end

      it 'Collection' do
        val = Types::TypeFactory.collection(Types::TypeFactory.range(0, 20))
        write(val)
        val2 = read
        expect(val2).to be_a(Types::PCollectionType)
        expect(val2).to eql(val)
      end

      it 'Array' do
        val = Types::TypeFactory.array_of(Types::TypeFactory.integer, Types::TypeFactory.range(0, 20))
        write(val)
        val2 = read
        expect(val2).to be_a(Types::PArrayType)
        expect(val2).to eql(val)
      end

      it 'Hash' do
        val = Types::TypeFactory.hash_kv(Types::TypeFactory.string, Types::TypeFactory.integer, Types::TypeFactory.range(0, 20))
        write(val)
        val2 = read
        expect(val2).to be_a(Types::PHashType)
        expect(val2).to eql(val)
      end

      it 'Variant' do
        val = Types::TypeFactory.variant(Types::TypeFactory.string, Types::TypeFactory.range(1, :default))
        write(val)
        val2 = read
        expect(val2).to be_a(Types::PVariantType)
        expect(val2).to eql(val)
      end

      it 'Object' do
        val = Types::TypeParser.singleton.parse('Pcore::StringType', loader)
        write(val)
        val2 = read
        expect(val2).to be_a(Types::PObjectType)
        expect(val2).to eql(val)
      end

      context 'ObjectType' do
        let(:type) do
          Types::PObjectType.new({
            'name' => 'MyType',
            'type_parameters' => {
              'x' => Types::PIntegerType::DEFAULT
            },
            'attributes' => {
              'x' => Types::PIntegerType::DEFAULT
            }
          })
        end

        it 'with preserved parameters' do
          val = type.create(34)._pcore_type
          write(val)
          val2 = read
          expect(val2).to be_a(Types::PObjectTypeExtension)
          expect(val2).to eql(val)
        end
      end
    end


    it 'Array of rich data' do
      # Sensitive omitted because it doesn't respond to ==
      val = [
        Time::Timespan.from_fields(false, 3, 12, 40, 31, 123),
        Time::Timestamp.now,
        SemanticPuppet::Version.parse('1.2.3-alpha2'),
        SemanticPuppet::VersionRange.parse('>=1.2.3-alpha2 <1.2.4'),
        Types::PBinaryType::Binary.from_base64('w5ZzdGVuIG1lZCByw7ZzdGVuCg==')
      ]
      write(val)
      val2 = read
      expect(val2).to eql(val)
    end

    it 'Hash of rich data' do
      # Sensitive omitted because it doesn't respond to ==
      val = {
        'duration' => Time::Timespan.from_fields(false, 3, 12, 40, 31, 123),
        'time' => Time::Timestamp.now,
        'version' => SemanticPuppet::Version.parse('1.2.3-alpha2'),
        'range' => SemanticPuppet::VersionRange.parse('>=1.2.3-alpha2 <1.2.4'),
        'binary' => Types::PBinaryType::Binary.from_base64('w5ZzdGVuIG1lZCByw7ZzdGVuCg==')
      }
      write(val)
      val2 = read
      expect(val2).to eql(val)
    end

    context 'an AST model' do
      it "Locator" do
        val = Parser::Locator::Locator19.new('here is some text', '/tmp/foo', [5])
        write(val)
        val2 = read
        expect(val2).to be_a(Parser::Locator::Locator19)
        expect(val2).to eql(val)
      end

      it 'nested Expression' do
        expr = parse(<<-CODE)
          $rootgroup = $osfamily ? {
              'Solaris'          => 'wheel',
              /(Darwin|FreeBSD)/ => 'wheel',
              default            => 'root',
          }

          file { '/etc/passwd':
            ensure => file,
            owner  => 'root',
            group  => $rootgroup,
          }
        CODE
        write(expr)
        expr2 = read
        expect(dumper.dump(expr)).to eq(dumper.dump(expr2))
      end
    end

    context 'PuppetObject' do
      before(:each) do
        class DerivedArray < Array
          include Types::PuppetObject

          def self._pcore_type
            @type
          end

          def self.register_ptype(loader, ir)
            @type = Pcore.create_object_type(loader, ir, DerivedArray, 'DerivedArray', nil, 'values' => Types::PArrayType::DEFAULT)
              .resolve(loader)
          end

          def initialize(values)
            concat(values)
          end

          def values
            Array.new(self)
          end
        end

        class DerivedHash < Hash
          include Types::PuppetObject

          def self._pcore_type
            @type
          end

          def self.register_ptype(loader, ir)
            @type = Pcore.create_object_type(loader, ir, DerivedHash, 'DerivedHash', nil, '_pcore_init_hash' => Types::PHashType::DEFAULT)
              .resolve(loader)
          end

          def initialize(_pcore_init_hash)
            merge!(_pcore_init_hash)
          end

          def _pcore_init_hash
            result = {}
            result.merge!(self)
            result
          end
        end
      end

      after(:each) do
        x = Puppet::Pops::Serialization
        x.send(:remove_const, :DerivedArray) if x.const_defined?(:DerivedArray)
        x.send(:remove_const, :DerivedHash) if x.const_defined?(:DerivedHash)
      end

      it 'derived from Array' do
        DerivedArray.register_ptype(loader, loaders.implementation_registry)

        # Sensitive omitted because it doesn't respond to ==
        val = DerivedArray.new([
          Time::Timespan.from_fields(false, 3, 12, 40, 31, 123),
          Time::Timestamp.now,
          SemanticPuppet::Version.parse('1.2.3-alpha2'),
          SemanticPuppet::VersionRange.parse('>=1.2.3-alpha2 <1.2.4'),
          Types::PBinaryType::Binary.from_base64('w5ZzdGVuIG1lZCByw7ZzdGVuCg==')
        ])
        write(val)
        val2 = read
        expect(val2).to eql(val)
      end

      it 'derived from Hash' do
        DerivedHash.register_ptype(loader, loaders.implementation_registry)

        # Sensitive omitted because it doesn't respond to ==
        val = DerivedHash.new({
          'duration' => Time::Timespan.from_fields(false, 3, 12, 40, 31, 123),
          'time' => Time::Timestamp.now,
          'version' => SemanticPuppet::Version.parse('1.2.3-alpha2'),
          'range' => SemanticPuppet::VersionRange.parse('>=1.2.3-alpha2 <1.2.4'),
          'binary' => Types::PBinaryType::Binary.from_base64('w5ZzdGVuIG1lZCByw7ZzdGVuCg==')
        })
        write(val)
        val2 = read
        expect(val2).to eql(val)
      end
    end
  end

  context 'deserializing an instance whose Object type was serialized by reference' do
    let(:to_converter) { ToDataConverter.new(:type_by_reference => true, :rich_data => true) }
    let(:type) do
      Types::PObjectType.new({
        'name' => 'MyType',
        'attributes' => {
          'x' => Types::PIntegerType::DEFAULT
        }
      })
    end

    context 'fails when deserializer is unaware of the referenced type' do
      it 'fails by default' do
        write(type.create(32))

        # Should fail since no loader knows about 'MyType'
        expect{ read }.to raise_error(Puppet::Error, 'No implementation mapping found for Puppet Type MyType')
      end

      context "succeds but produces an rich_type hash when deserializer has 'allow_unresolved' set to true" do
        let(:from_converter) { FromDataConverter.new(:allow_unresolved => true) }
        it do
          write(type.create(32))
          expect(read).to eql({'__pcore_type__'=>'MyType', 'x'=>32})
        end
      end
    end

    it 'succeeds when deserializer is aware of the referenced type' do
      obj = type.create(32)
      write(obj)
      loaders.find_loader(nil).expects(:load).with(:type, 'mytype').returns(type)
      expect(read).to eql(obj)
    end
  end

  context 'with rich_data set to false' do
    let(:to_converter) { ToDataConverter.new(:message_prefix => 'Test Hash', :rich_data => false) }
    let(:logs) { [] }
    let(:warnings) { logs.select { |log| log.level == :warning }.map { |log| log.message } }

    it 'A Hash with Symbol keys is converted to hash with String keys with warning' do
      val = { :one => 'one', :two => 'two' }
      Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
        write(val)
        val2 = read
        expect(val2).to be_a(Hash)
        expect(val2).to eql({ 'one' => 'one', 'two' => 'two' })
      end
      expect(warnings).to eql([
        "Test Hash contains a hash with a Symbol key. It will be converted to the String 'one'",
        "Test Hash contains a hash with a Symbol key. It will be converted to the String 'two'"])
    end

    it 'A Hash with Version keys is converted to hash with String keys with warning' do
      val = { SemanticPuppet::Version.parse('1.0.0') => 'one', SemanticPuppet::Version.parse('2.0.0') => 'two' }
      Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
        write(val)
        val2 = read
        expect(val2).to be_a(Hash)
        expect(val2).to eql({ '1.0.0' => 'one', '2.0.0' => 'two' })
      end
      expect(warnings).to eql([
        "Test Hash contains a hash with a SemanticPuppet::Version key. It will be converted to the String '1.0.0'",
        "Test Hash contains a hash with a SemanticPuppet::Version key. It will be converted to the String '2.0.0'"])
    end

    context 'and symbol_as_string is set to true' do
      let(:to_converter) { ToDataConverter.new(:rich_data => false, :symbol_as_string => true) }

      it 'A Hash with Symbol keys is silently converted to hash with String keys' do
        val = { :one => 'one', :two => 'two' }
        Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
          write(val)
          val2 = read
          expect(val2).to be_a(Hash)
          expect(val2).to eql({ 'one' => 'one', 'two' => 'two' })
        end
        expect(warnings).to be_empty
      end

      it 'A Hash with Symbol values is silently converted to hash with String values' do
        val = { 'one' => :one, 'two' => :two  }
        Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
          write(val)
          val2 = read
          expect(val2).to be_a(Hash)
          expect(val2).to eql({ 'one' => 'one', 'two' => 'two' })
        end
        expect(warnings).to be_empty
      end

      it 'A Hash with default values will have the values converted to string with a warning' do
        val = { 'key' => :default  }
        Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
          write(val)
          val2 = read
          expect(val2).to be_a(Hash)
          expect(val2).to eql({ 'key' => 'default' })
        end
        expect(warnings).to eql(["['key'] contains the special value default. It will be converted to the String 'default'"])
      end
    end
  end

  context 'with rich_data is set to true' do
    let(:to_converter) { ToDataConverter.new(:message_prefix => 'Test Hash', :rich_data => true) }
    let(:logs) { [] }
    let(:warnings) { logs.select { |log| log.level == :warning }.map { |log| log.message } }

    context 'and symbol_as_string is set to true' do
      let(:to_converter) { ToDataConverter.new(:rich_data => true, :symbol_as_string => true) }

      it 'A Hash with Symbol keys is silently converted to hash with String keys' do
        val = { :one => 'one', :two => 'two' }
        Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
          write(val)
          val2 = read
          expect(val2).to be_a(Hash)
          expect(val2).to eql({ 'one' => 'one', 'two' => 'two' })
        end
        expect(warnings).to be_empty
      end

      it 'A Hash with Symbol values is silently converted to hash with String values' do
        val = { 'one' => :one, 'two' => :two  }
        Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
          write(val)
          val2 = read
          expect(val2).to be_a(Hash)
          expect(val2).to eql({ 'one' => 'one', 'two' => 'two' })
        end
        expect(warnings).to be_empty
      end

      it 'A Hash with default values will not loose type information' do
        val = { 'key' => :default  }
        Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
          write(val)
          val2 = read
          expect(val2).to be_a(Hash)
          expect(val2).to eql({ 'key' => :default })
        end
        expect(warnings).to be_empty
      end
    end
  end

  context 'with local_reference set to false' do
    let(:to_converter) { ToDataConverter.new(:local_reference => false) }

    it 'A self referencing value will trigger an endless recursion error' do
      val = {}
      val['myself'] = val
      expect { write(val) }.to raise_error(/Endless recursion detected when attempting to serialize value of class Hash/)
    end
  end

  context 'will fail when' do
    it 'the value of a type description is something other than a String or a Hash' do
      expect do
        from_converter.convert({ '__pcore_type__' => { '__pcore_type__' => 'Pcore::TimestampType', '__pcore_value__' => 12345 }})
      end.to raise_error(/Cannot create a Pcore::TimestampType from a (Fixnum|Integer)/)
    end
  end
end
end
end
