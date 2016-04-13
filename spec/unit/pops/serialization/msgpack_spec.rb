require 'spec_helper'
require 'puppet/pops/serialization'

module Puppet::Pops::Serialization
describe 'the Puppet::Pops::Serialization when using MsgPack' do
  let(:io) { StringIO.new }
  let(:serializer) { MsgPack::Writer.new(io) }
  let(:deserializer) { MsgPack::Reader.new(io) }

  def write(val)
    serializer.write(val)
  end

  def flip
    serializer.finish
    io.rewind
    deserializer.reset
  end

  def read
    deserializer.read
  end

  context 'on scalar values' do
    it 'can write and read String' do
      val = 'the value'
      write(val)
      flip
      val2 = read
      expect(val2).to be_a(String)
      expect(val2).to eql(val)
    end

    it 'can write and read Integer' do
      val = 32
      write(val)
      flip
      val2 = read
      expect(val2).to be_a(Integer)
      expect(val2).to eql(val)
    end

    it 'can write and read Float' do
      val = 32.45
      write(val)
      flip
      val2 = read
      expect(val2).to be_a(Float)
      expect(val2).to eql(val)
    end

    it 'can write and read true' do
      val = true
      write(val)
      flip
      val2 = read
      expect(val2).to be_a(TrueClass)
      expect(val2).to eql(val)
    end

    it 'can write and read false' do
      val = false
      write(val)
      flip
      val2 = read
      expect(val2).to be_a(FalseClass)
      expect(val2).to eql(val)
    end

    it 'can write and read nil' do
      val = nil
      write(val)
      flip
      val2 = read
      expect(val2).to be_a(NilClass)
      expect(val2).to eql(val)
    end

    it 'can write and read Regexp' do
      val = /match me/
      write(val)
      flip
      val2 = read
      expect(val2).to be_a(Regexp)
      expect(val2).to eql(val)
    end

    it 'can write and read Time created by TimeFactory' do
      failed = false
      # It does succeed on rare occasions, so we need to repeat
      100.times do |n|
        val = Time.now
        val = TimeFactory.at(val.tv_sec, val.tv_nsec / 1000.0)
        flip
        write(val)
        flip
        val2 = read
        unless val == val2
          puts "Fail after #{n} iterations with #{val.tv_sec}, #{val.tv_nsec} !=  #{val2.tv_sec}, #{val2.tv_nsec}"
          failed = true
          break
        end
      end
      expect(failed).to be_falsey
    end

    # Windows doesn't seem ot have fine enough granularity to provoke the problem
    it 'will fail on Time not created by TimeFactory', :unless => Puppet.features.microsoft_windows? do
      failed = false
      # It does succeed on rare occasions, so we need to repeat
      100.times do
        val = Time.now
        val = Time.at(val.tv_sec, val.tv_nsec / 1000.0)
        flip
        write(val)
        flip
        val2 = read
        unless val == val2
          failed = true
          break
        end
      end
      expect(failed).to be_truthy
    end
  end

  it 'should be able to write and read primitives using tabulation' do
    val = 'the value'
    write(val)
    write(val)
    flip
    expect(read).to eql(val)
    expect(read).to eql(val)
    expect(deserializer.primitive_count).to eql(1)
  end
end
end
