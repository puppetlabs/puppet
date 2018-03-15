#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/network/formats'
require 'puppet/network/format_support'

class FormatsTest
  include Puppet::Network::FormatSupport

  attr_accessor :string
  def ==(other)
    string == other.string
  end

  def self.from_data_hash(data)
    new(data['string'])
  end

  def initialize(string)
    @string = string
  end

  def to_data_hash(*args)
    {
      'string' => @string
    }
  end

  def to_binary
    string
  end

  def self.from_binary(data)
    self.new(data)
  end
end

describe "Puppet Network Format" do
  it "should include a msgpack format", :if => Puppet.features.msgpack? do
    expect(Puppet::Network::FormatHandler.format(:msgpack)).not_to be_nil
  end

  describe "msgpack", :if => Puppet.features.msgpack? do
    let(:msgpack) { Puppet::Network::FormatHandler.format(:msgpack) }

    it "should have its mime type set to application/x-msgpack" do
      expect(msgpack.mime).to eq("application/x-msgpack")
    end

    it "should have a nil charset" do
      expect(msgpack.charset).to be_nil
    end

    it "should have a weight of 20" do
      expect(msgpack.weight).to eq(20)
    end

    it "should fail when one element does not have a from_data_hash" do
      expect do
        msgpack.intern_multiple(Hash, MessagePack.pack(["foo"]))
      end.to raise_error(NoMethodError)
    end

    it "should be able to serialize a catalog" do
      cat = Puppet::Resource::Catalog.new('foo', Puppet::Node::Environment.create(:testing, []))
      cat.add_resource(Puppet::Resource.new(:file, 'my_file'))
      catunpack = MessagePack.unpack(cat.to_msgpack)
      expect(catunpack).to include(
        "tags"=>[],
        "name"=>"foo",
        "version"=>nil,
        "environment"=>"testing",
        "edges"=>[],
        "classes"=>[]
      )
      expect(catunpack["resources"][0]).to include(
        "type"=>"File",
        "title"=>"my_file",
        "exported"=>false
      )
      expect(catunpack["resources"][0]["tags"]).to include(
        "file",
        "my_file"
      )
    end
  end

  describe "yaml" do
    let(:yaml) { Puppet::Network::FormatHandler.format(:yaml) }

    it "should have its mime type set to text/yaml" do
      expect(yaml.mime).to eq("text/yaml")
    end

    # we shouldn't be using yaml on the network
    it "should have a nil charset" do
      expect(yaml.charset).to be_nil
    end

    it "should be supported on Strings" do
      expect(yaml).to be_supported(String)
    end

    it "should render by calling 'to_yaml' on the instance" do
      instance = mock 'instance'
      instance.expects(:to_yaml).returns "foo"
      expect(yaml.render(instance)).to eq("foo")
    end

    it "should render multiple instances by calling 'to_yaml' on the array" do
      instances = [mock('instance')]
      instances.expects(:to_yaml).returns "foo"
      expect(yaml.render_multiple(instances)).to eq("foo")
    end

    it "should deserialize YAML" do
      expect(yaml.intern(String, YAML.dump("foo"))).to eq("foo")
    end

    it "should deserialize symbols as strings" do
      expect { yaml.intern(String, YAML.dump(:foo))}.to raise_error(Puppet::Network::FormatHandler::FormatError)
    end

    it "should skip data_to_hash if data is already an instance of the specified class" do
      # The rest terminus for the report indirected type relies on this behavior
      data = YAML.dump([1, 2])
      instance = yaml.intern(Array, data)
      expect(instance).to eq([1, 2])
    end

    it "should load from yaml when deserializing an array" do
      text = YAML.dump(["foo"])
      expect(yaml.intern_multiple(String, text)).to eq(["foo"])
    end

    it "fails intelligibly instead of calling to_json with something other than a hash" do
      expect do
        yaml.intern(Puppet::Node, '')
      end.to raise_error(Puppet::Network::FormatHandler::FormatError, /did not contain a valid instance/)
    end

    it "fails intelligibly when intern_multiple is called and yaml doesn't decode to an array" do
      expect do
        yaml.intern_multiple(Puppet::Node, '')
      end.to raise_error(Puppet::Network::FormatHandler::FormatError, /did not contain a collection/)
    end

    it "fails intelligibly instead of calling to_json with something other than a hash when interning multiple" do
      expect do
        yaml.intern_multiple(Puppet::Node, YAML.dump(["hello"]))
      end.to raise_error(Puppet::Network::FormatHandler::FormatError, /did not contain a valid instance/)
    end
  end

  describe "plaintext" do
    let(:text) { Puppet::Network::FormatHandler.format(:s) }

    it "should have its mimetype set to text/plain" do
      expect(text.mime).to eq("text/plain")
    end

    it "should use 'utf-8' charset" do
      expect(text.charset).to eq(Encoding::UTF_8)
    end

    it "should use 'txt' as its extension" do
      expect(text.extension).to eq("txt")
    end
  end

  describe "dot" do
    let(:dot) { Puppet::Network::FormatHandler.format(:dot) }

    it "should have its mimetype set to text/dot" do
      expect(dot.mime).to eq("text/dot")
    end
  end

  describe Puppet::Network::FormatHandler.format(:binary) do
    let(:binary) { Puppet::Network::FormatHandler.format(:binary) }

    it "should exist" do
      expect(binary).not_to be_nil
    end

    it "should have its mimetype set to application/octet-stream" do
      expect(binary.mime).to eq("application/octet-stream")
    end

    it "should have a nil charset" do
      expect(binary.charset).to be_nil
    end

    it "should not be supported by default" do
      expect(binary).to_not be_supported(String)
    end

    it "should render an instance as binary" do
      instance = FormatsTest.new("foo")
      expect(binary.render(instance)).to eq("foo")
    end

    it "should intern an instance from a JSON hash" do
      instance = binary.intern(FormatsTest, "foo")
      expect(instance.string).to eq("foo")
    end

    it "should fail if its multiple_render method is used" do
      expect {
        binary.render_multiple("foo")
      }.to raise_error(NotImplementedError, /can not render multiple instances to application\/octet-stream/)
    end

    it "should fail if its multiple_intern method is used" do
      expect {
        binary.intern_multiple(String, "foo")
      }.to raise_error(NotImplementedError, /can not intern multiple instances from application\/octet-stream/)
    end

    it "should have a weight of 1" do
      expect(binary.weight).to eq(1)
    end
  end

  describe "pson" do
    let(:pson) { Puppet::Network::FormatHandler.format(:pson) }

    it "should include a pson format" do
      expect(pson).not_to be_nil
    end

    it "should have its mime type set to text/pson" do
      expect(pson.mime).to eq("text/pson")
    end

    it "should have a nil charset" do
      expect(pson.charset).to be_nil
    end

    it "should require the :render_method" do
      expect(pson.required_methods).to be_include(:render_method)
    end

    it "should require the :intern_method" do
      expect(pson.required_methods).to be_include(:intern_method)
    end

    it "should have a weight of 10" do
      expect(pson.weight).to eq(10)
    end

    it "should render an instance as pson" do
      instance = FormatsTest.new("foo")
      expect(pson.render(instance)).to eq({"string" => "foo"}.to_pson)
    end

    it "should render multiple instances as pson" do
      instances = [FormatsTest.new("foo")]
      expect(pson.render_multiple(instances)).to eq([{"string" => "foo"}].to_pson)
    end

    it "should intern an instance from a pson hash" do
      text = PSON.dump({"string" => "parsed_pson"})
      instance = pson.intern(FormatsTest, text)
      expect(instance.string).to eq("parsed_pson")
    end

    it "should skip data_to_hash if data is already an instance of the specified class" do
      # The rest terminus for the report indirected type relies on this behavior
      data = PSON.dump([1, 2])
      instance = pson.intern(Array, data)
      expect(instance).to eq([1, 2])
    end

    it "should intern multiple instances from a pson array" do
      text = PSON.dump(
        [
          {
            "string" => "BAR"
          },
          {
            "string" => "BAZ"
          }
        ]
      )
      expect(pson.intern_multiple(FormatsTest, text)).to eq([FormatsTest.new('BAR'), FormatsTest.new('BAZ')])
    end

    it "should unwrap the data from legacy clients" do
      text = PSON.dump(
        {
          "type" => "FormatsTest",
          "data" => {
            "string" => "parsed_json"
          }
        }
      )
      instance = pson.intern(FormatsTest, text)
      expect(instance.string).to eq("parsed_json")
    end

    it "fails intelligibly when given invalid data" do
      expect do
        pson.intern(Puppet::Node, '')
      end.to raise_error(PSON::ParserError, /source did not contain any PSON/)
    end
  end

  describe "json" do
    let(:json) { Puppet::Network::FormatHandler.format(:json) }

    it "should include a json format" do
      expect(json).not_to be_nil
    end

    it "should have its mime type set to application/json" do
      expect(json.mime).to eq("application/json")
    end

    it "should use 'utf-8' charset" do
      expect(json.charset).to eq(Encoding::UTF_8)
    end

    it "should require the :render_method" do
      expect(json.required_methods).to be_include(:render_method)
    end

    it "should require the :intern_method" do
      expect(json.required_methods).to be_include(:intern_method)
    end

    it "should have a weight of 15" do
      expect(json.weight).to eq(15)
    end

    it "should render an instance as JSON" do
      instance = FormatsTest.new("foo")
      expect(json.render(instance)).to eq({"string" => "foo"}.to_json)
    end

    it "should render multiple instances as a JSON array of hashes" do
      instances = [FormatsTest.new("foo")]
      expect(json.render_multiple(instances)).to eq([{"string" => "foo"}].to_json)
    end

    it "should intern an instance from a JSON hash" do
      text = Puppet::Util::Json.dump({"string" => "parsed_json"})
      instance = json.intern(FormatsTest, text)
      expect(instance.string).to eq("parsed_json")
    end

    it "should skip data_to_hash if data is already an instance of the specified class" do
      # The rest terminus for the report indirected type relies on this behavior
      data = Puppet::Util::Json.dump([1, 2])
      instance = json.intern(Array, data)
      expect(instance).to eq([1, 2])
    end

    it "should intern multiple instances from a JSON array of hashes" do
      text = Puppet::Util::Json.dump(
        [
          {
            "string" => "BAR"
          },
          {
            "string" => "BAZ"
          }
        ]
      )
      expect(json.intern_multiple(FormatsTest, text)).to eq([FormatsTest.new('BAR'), FormatsTest.new('BAZ')])
    end

    it "should reject wrapped data from legacy clients as they've never supported JSON" do
      text = Puppet::Util::Json.dump(
        {
          "type" => "FormatsTest",
          "data" => {
            "string" => "parsed_json"
          }
        }
      )
      instance = json.intern(FormatsTest, text)
      expect(instance.string).to be_nil
    end

    it "fails intelligibly when given invalid data" do
      expect do
        json.intern(Puppet::Node, '')
      end.to raise_error(Puppet::Util::Json::ParseError)
    end
  end

  describe ":console format" do
    let(:console) { Puppet::Network::FormatHandler.format(:console) }

    it "should include a console format" do
      expect(console).to be_an_instance_of Puppet::Network::Format
    end

    [:intern, :intern_multiple].each do |method|
      it "should not implement #{method}" do
        expect { console.send(method, String, 'blah') }.to raise_error NotImplementedError
      end
    end

    context "when rendering ruby types" do
      ["hello", 1, 1.0].each do |input|
        it "should just return a #{input.inspect}" do
          expect(console.render(input)).to eq(input)
        end
      end

      { true  => "true",
        false => "false",
        nil   => "null",
      }.each_pair do |input, output|
        it "renders #{input.class} as '#{output}'" do
          expect(console.render(input)).to eq(output)
        end
      end

      it "renders an Object as its quoted inspect value" do
        obj = Object.new
        expect(console.render(obj)).to eq("\"#{obj.inspect}\"")
      end
    end

    context "when rendering arrays" do
      {
        []                => "",
        [1, 2]            => "1\n2\n",
        ["one"]           => "one\n",
        [{1 => 1}]        => "{1=>1}\n",
        [[1, 2], [3, 4]]  => "[1, 2]\n[3, 4]\n"
      }.each_pair do |input, output|
        it "should render #{input.inspect} as one item per line" do
          expect(console.render(input)).to eq(output)
        end
      end
    end

    context "when rendering hashes" do
      {
        {}                                   => "",
        {1 => 2}                             => "1  2\n",
        {"one" => "two"}                     => "one  \"two\"\n", # odd that two is quoted but one isn't
        {[1,2] => 3, [2,3] => 5, [3,4] => 7} => "{\n  \"[1, 2]\": 3,\n  \"[2, 3]\": 5,\n  \"[3, 4]\": 7\n}",
        {{1 => 2} => {3 => 4}}               => "{\n  \"{1=>2}\": {\n    \"3\": 4\n  }\n}"
      }.each_pair do |input, output|
        it "should render #{input.inspect}" do
          expect(console.render(input)).to eq(output)
        end
      end

      it "should render a {String,Numeric}-keyed Hash into a table" do
        json = Puppet::Network::FormatHandler.format(:json)
        object = Object.new
        hash = { "one" => 1, "two" => [], "three" => {}, "four" => object, 5 => 5,
                 6.0 => 6 }

        # Gotta love ASCII-betical sort order.  Hope your objects are better
        # structured for display than my test one is. --daniel 2011-04-18
        expect(console.render(hash)).to eq <<EOT
5      5
6.0    6
four   #{json.render(object).chomp}
one    1
three  {}
two    []
EOT
      end
    end

    context "when rendering face-related objects" do
      it "pretty prints facts" do
        tm = Time.new("2016-01-27T19:30:00")
        values = {
          "architecture" =>  "x86_64",
          "os" => {
            "release" => {
              "full" => "15.6.0"
            }
          },
          "system_uptime" => {
            "seconds" => 505532
          }
        }
        facts = Puppet::Node::Facts.new("foo", values)
        facts.timestamp = tm

        # For some reason, render omits the last newline, seems like a bug
        expect(console.render(facts)).to eq(<<EOT.chomp)
{
  "name": "foo",
  "values": {
    "architecture": "x86_64",
    "os": {
      "release": {
        "full": "15.6.0"
      }
    },
    "system_uptime": {
      "seconds": 505532
    }
  },
  "timestamp": "#{tm.iso8601(9)}"
}
EOT
      end
    end
  end
end
