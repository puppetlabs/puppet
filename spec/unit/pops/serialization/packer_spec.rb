require 'spec_helper'
require 'puppet/pops/serialization'

module Puppet::Pops::Serialization
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
      val = TimeFactory.now
      write(val)
      val2 = read
      expect(val2).to be_a(Time)
      expect(val2).to eql(val)
    end

    it 'Version' do
      val = Semantic::Version.parse('1.2.3-alpha2')
      write(val)
      val2 = read
      expect(val2).to be_a(Semantic::Version)
      expect(val2).to eql(val)
    end

    it 'VersionRange' do
      val = Semantic::VersionRange.parse('>=1.2.3-alpha2 <1.2.4')
      write(val)
      val2 = read
      expect(val2).to be_a(Semantic::VersionRange)
      expect(val2).to eql(val)
    end

    it 'will never fail write and read of Time created by TimeFactory' do
      val = Time.now
      val = TimeFactory.at(val.tv_sec, val.tv_nsec / 1000 + 0.123)
      write(val)
      val2 = read
      expect(val).to eq(val2)
    end

    # Windows doesn't seem ot have fine enough granularity to provoke the problem
    it 'will fail on Time not created by TimeFactory' do
      val = Time.now
      val = Time.at(val.tv_sec, val.tv_nsec / 1000 + 0.123)
      write(val)
      val2 = read
      expect(val).not_to eq(val2)
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
