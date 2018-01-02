require 'spec_helper'
require 'puppet/pops'

module Puppet::Pops
module Serialization
[JSON].each do |packer_module|
  describe "the Puppet::Pops::Serialization over #{packer_module.name}" do
  let!(:dumper) { Model::ModelTreeDumper.new }
  let(:io) { StringIO.new }
  let(:parser) { Parser::EvaluatingParser.new }
  let(:env) { Puppet::Node::Environment.create(:testing, []) }
  let(:loaders) { Puppet::Pops::Loaders.new(env) }
  let(:loader) { loaders.find_loader(nil) }
  let(:reader_class) { packer_module::Reader }
  let(:writer_class) { packer_module::Writer }
  let(:serializer) { Serializer.new(writer_class.new(io)) }
  let(:deserializer) { Deserializer.new(reader_class.new(io), loaders.find_loader(nil)) }

  around :each do |example|
     Puppet.override(:loaders => loaders, :current_environment => env) do
      example.run
    end
  end

  def write(*values)
    io.reopen
    values.each { |val| serializer.write(val) }
    serializer.finish
    io.rewind
  end

  def read
    deserializer.read
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
    let(:serializer) { Serializer.new(writer_class.new(io), :type_by_reference => true) }
    let(:type) do
      Types::PObjectType.new({
        'name' => 'MyType',
        'attributes' => {
          'x' => Types::PIntegerType::DEFAULT
        }
      })
    end

    it 'fails when deserializer is unaware of the referenced type' do
      write(type.create(32))

      # Should fail since no loader knows about 'MyType'
      expect{ read }.to raise_error(Puppet::Error, 'No implementation mapping found for Puppet Type MyType')
    end

    it 'succeeds when deserializer is aware of the referenced type' do
      obj = type.create(32)
      write(obj)
      loaders.find_loader(nil).expects(:load).with(:type, 'mytype').returns(type)
      expect(read).to eql(obj)
    end
  end

  context 'When debugging' do
    let(:debug_io) { StringIO.new }
    let(:writer) { reader_class.new(io, { :debug_io => debug_io, :tabulate => false, :verbose => true }) }

    it 'can write and read an AST expression' do
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
end
end
end
end
