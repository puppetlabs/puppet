# coding: utf-8
require 'spec_helper'

require 'puppet/util/yaml'

describe Puppet::Util::Yaml do
  include PuppetSpec::Files

  let(:filename) { tmpfile("yaml") }

  shared_examples_for 'yaml file loader' do |load_method|
    it 'returns false when the file is empty' do
      Puppet::FileSystem.touch(filename)

      expect(load_method.call(filename)).to eq(false)
    end

    it 'reads a YAML file from disk' do
      write_file(filename, YAML.dump({ "my" => "data" }))

      expect(load_method.call(filename)).to eq({ "my" => "data" })
    end

    it 'reads YAML as UTF-8' do
      write_file(filename, YAML.dump({ "my" => "𠜎" }))

      expect(load_method.call(filename)).to eq({ "my" => "𠜎" })
    end
  end

  context "#safe_load" do
    it 'raises an error if YAML is invalid' do
      expect {
        Puppet::Util::Yaml.safe_load('{ invalid')
      }.to raise_error(Puppet::Util::Yaml::YamlLoadError, %r[\(<unknown>\): .* at line \d+ column \d+])
    end

    it 'raises if YAML contains classes not in the list' do
      expect {
        Puppet::Util::Yaml.safe_load(<<FACTS, [])
--- !ruby/object:Puppet::Node::Facts
name: localhost
FACTS
      }.to raise_error(Puppet::Util::Yaml::YamlLoadError, "(<unknown>): Tried to load unspecified class: Puppet::Node::Facts")
    end

    it 'includes the filename if YAML contains classes not in the list' do
      expect {
        Puppet::Util::Yaml.safe_load(<<FACTS, [], 'foo.yaml')
--- !ruby/object:Puppet::Node::Facts
name: localhost
FACTS
      }.to raise_error(Puppet::Util::Yaml::YamlLoadError, "(foo.yaml): Tried to load unspecified class: Puppet::Node::Facts")
    end

    it 'allows classes to be loaded' do
      facts = Puppet::Util::Yaml.safe_load(<<FACTS, [Puppet::Node::Facts])
--- !ruby/object:Puppet::Node::Facts
name: localhost
values:
  puppetversion: 6.0.0
FACTS
      expect(facts.name).to eq('localhost')
    end

    it 'returns false if the content is empty' do
      expect(Puppet::Util::Yaml.safe_load('')).to eq(false)
    end

    it 'loads true' do
      expect(Puppet::Util::Yaml.safe_load('true')).to eq(true)
    end

    it 'loads false' do
      expect(Puppet::Util::Yaml.safe_load('false')).to eq(false)
    end

    it 'loads nil' do
      expect(Puppet::Util::Yaml.safe_load(<<~YAML)).to eq('a' => nil)
        ---
        a: null
      YAML
    end

    it 'loads a numeric' do
      expect(Puppet::Util::Yaml.safe_load('42')).to eq(42)
    end

    it 'loads a string' do
      expect(Puppet::Util::Yaml.safe_load('puppet')).to eq('puppet')
    end

    it 'loads an array' do
      expect(Puppet::Util::Yaml.safe_load(<<~YAML)).to eq([1, 2])
        ---
        - 1
        - 2
      YAML
    end

    it 'loads a hash' do
      expect(Puppet::Util::Yaml.safe_load(<<~YAML)).to eq('a' => 1, 'b' => 2)
        ---
        a: 1
        b: 2
      YAML
    end

    it 'loads an alias' do
      expect(Puppet::Util::Yaml.safe_load(<<~YAML)).to eq('a' => [], 'b' => [])
        ---
        a: &1 []
        b: *1
      YAML
    end
  end

  context "#safe_load_file" do
    it_should_behave_like 'yaml file loader', Puppet::Util::Yaml.method(:safe_load_file)

    it 'raises an error when the file is invalid YAML' do
      write_file(filename, '{ invalid')

      expect {
        Puppet::Util::Yaml.safe_load_file(filename)
      }.to raise_error(Puppet::Util::Yaml::YamlLoadError, %r[\(#{filename}\): .* at line \d+ column \d+])
    end

    it 'raises an error when the filename is illegal' do
      expect {
        Puppet::Util::Yaml.safe_load_file("not\0allowed")
      }.to raise_error(ArgumentError, /pathname contains null byte/)
    end

    it 'raises an error when the file does not exist' do
      expect {
        Puppet::Util::Yaml.safe_load_file('does/not/exist.yaml')
      }.to raise_error(Errno::ENOENT, /No such file or directory/)
    end
  end

  def write_file(name, contents)
    File.open(name, "w:UTF-8") do |fh|
      fh.write(contents)
    end
  end
end
