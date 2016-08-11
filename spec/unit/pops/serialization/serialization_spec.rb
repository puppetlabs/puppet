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

  around :each do |example|
     Puppet.override(:loaders => loaders, :current_environment => env) do
      example.run
    end
  end

  def write(*values)
    io.reopen
    serializer = Serializer.new(writer_class.new(io))
    values.each { |val| serializer.write(val) }
    serializer.finish
    io.rewind
  end

  def read
    deserializer = Deserializer.new(reader_class.new(io), loaders.find_loader(nil))
    deserializer.read
  end

  def parse(string)
    parser.parse_string(string, '/home/tester/experiments/manifests/init.pp').current
  end

  context 'can write and read a Scalar' do
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

    it 'Time created by TimeFactory' do
      # It does succeed on rare occasions, so we need to repeat
      val = TimeFactory.now
      write(val)
      val2 = read
      expect(val2).to be_a(Time)
      expect(val2).to eql(val)
    end

    it 'Version' do
      # It does succeed on rare occasions, so we need to repeat
      val = Semantic::Version.parse('1.2.3-alpha2')
      write(val)
      val2 = read
      expect(val2).to be_a(Semantic::Version)
      expect(val2).to eql(val)
    end

    it 'VersionRange' do
      # It does succeed on rare occasions, so we need to repeat
      val = Semantic::VersionRange.parse('>=1.2.3-alpha2 <1.2.4')
      write(val)
      val2 = read
      expect(val2).to be_a(Semantic::VersionRange)
      expect(val2).to eql(val)
    end
  end

  context 'can write and read' do
    include_context 'types_setup'

    it 'all default types' do
      all_types.each do |t|
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
