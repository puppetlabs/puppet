# coding: utf-8
require 'spec_helper'

require 'puppet/util/yaml'

describe Puppet::Util::Yaml do
  include PuppetSpec::Files

  let(:filename) { tmpfile("yaml") }

  context "when safely loading" do
    it 'reads a YAML file from disk' do
      write_file(filename, YAML.dump({ "my" => "data" }))

      expect(Puppet::Util::Yaml.safe_load_file(filename)).to eq({ "my" => "data" })
    end

    it 'reads YAML as UTF-8' do
      write_file(filename, YAML.dump({ "my" => "𠜎" }))

      expect(Puppet::Util::Yaml.safe_load_file(filename)).to eq({ "my" => "𠜎" })
    end
    it "raises an error when the file does not exist" do
      expect {
        Puppet::Util::Yaml.safe_load_file('does/not/exist.yaml')
      }.to raise_error(Errno::ENOENT)
    end

    it 'raises if YAML contains classes not in the list' do
      expect {
        Puppet::Util::Yaml.safe_load(<<FACTS)
--- !ruby/object:Puppet::Node::Facts
name: localhost
FACTS
      }.to raise_error(Puppet::Util::Yaml::YamlLoadError, /Tried to load unspecified class/)
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
  end

  it "reads a YAML file from disk" do
    write_file(filename, YAML.dump({ "my" => "data" }))

    expect(Puppet::Util::Yaml.load_file(filename)).to eq({ "my" => "data" })
  end

  it "writes data formatted as YAML to disk" do
    Puppet::Util::Yaml.dump({ "my" => "data" }, filename)

    expect(Puppet::Util::Yaml.load_file(filename)).to eq({ "my" => "data" })
  end

  it "raises an error when the file is invalid YAML" do
    write_file(filename, "{ invalid")

    expect { Puppet::Util::Yaml.load_file(filename) }.to raise_error(Puppet::Util::Yaml::YamlLoadError)
  end

  it "raises an error when the file does not exist" do
    expect { Puppet::Util::Yaml.load_file("no") }.to raise_error(Puppet::Util::Yaml::YamlLoadError, /No such file or directory/)
  end

  it "raises an error when the filename is illegal" do
    expect { Puppet::Util::Yaml.load_file("not\0allowed") }.to raise_error(Puppet::Util::Yaml::YamlLoadError, /null byte/)
  end

  context "when the file is empty" do
    it "returns false" do
      Puppet::FileSystem.touch(filename)

      expect(Puppet::Util::Yaml.load_file(filename)).to eq(false)
    end

    it "allows return value to be overridden" do
      Puppet::FileSystem.touch(filename)

      expect(Puppet::Util::Yaml.load_file(filename, {})).to eq({})
    end
  end

  it "should allow one to strip ruby tags that would otherwise not parse" do
    write_file(filename, "---\nweirddata: !ruby/hash:Not::A::Valid::Class {}")

    expect(Puppet::Util::Yaml.load_file(filename, {}, true)).to eq({"weirddata" => {}})
  end

  it "should not strip non-ruby tags" do
    write_file(filename, "---\nweirddata: !binary |-\n          e21kNX04MTE4ZGY2NmM5MTc3OTg4ZWE4Y2JiOWEzMjMyNzFkYg==")

    expect(Puppet::Util::Yaml.load_file(filename, {}, true)).to eq({"weirddata" => "{md5}8118df66c9177988ea8cbb9a323271db"})
  end

  def write_file(name, contents)
    File.open(name, "w:UTF-8") do |fh|
      fh.write(contents)
    end
  end
end
