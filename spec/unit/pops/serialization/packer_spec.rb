require 'spec_helper'
require 'puppet/pops/serialization'

module Puppet::Pops
module Serialization
[JSON].each do |packer_module|
describe "the Puppet::Pops::Serialization when using #{packer_module.name}" do
  let(:io) { StringIO.new }
  let(:reader_class) { packer_module::Reader }
  let(:writer_class) { packer_module::Writer }

  def write(*values)
    io.reopen
    serializer = writer_class.new(io)
    values.each { |val| serializer.write(val) }
    serializer.finish
    io.rewind
  end

  def read(count = nil)
    @deserializer = reader_class.new(io)
    count.nil? ? @deserializer.read : Array.new(count) { @deserializer.read }
  end

  context 'can write and read a' do
    it 'String' do
      val = 'the value'
      write(val)
      val2 = read
      expect(val2).to be_a(String)
      expect(val2).to eql(val)
    end

    it 'positive Integer' do
      val = 2**63-1
      write(val)
      val2 = read
      expect(val2).to be_a(Integer)
      expect(val2).to eql(val)
    end

    it 'negative Integer' do
      val = -2**63
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
      val = SemanticPuppet::Version.parse('1.2.3-alpha2')
      write(val)
      val2 = read
      expect(val2).to be_a(SemanticPuppet::Version)
      expect(val2).to eql(val)
    end

    it 'VersionRange' do
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
  end

  context 'will fail on attempts to write' do
    it 'Integer larger than 2**63-1' do
      expect { write(2**63) }.to raise_error(SerializationError, 'Integer out of bounds')
    end

    it 'Integer smaller than -2**63' do
      expect { write(-2**63-1) }.to raise_error(SerializationError, 'Integer out of bounds')
    end

    it 'objects unknown to Puppet serialization' do
      expect { write("".class) }.to raise_error(SerializationError, 'Unable to serialize a Class')
    end
  end

  it 'should be able to write and read primitives using tabulation' do
    val = 'the value'
    write(val, val)
    expect(read(2)).to eql([val, val])
    expect(@deserializer.primitive_count).to eql(1)
  end
end
end
end
end
