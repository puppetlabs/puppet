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

    it "fails intelligibly instead of calling to_pson with something other than a hash when interning multiple" do
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

    it "should always be supported" do
      expect(binary).to be_supported(String)
    end

    it "should fail if its multiple_render method is used" do
      expect { binary.render_multiple("foo") }.to raise_error(NotImplementedError)
    end

    it "should fail if its multiple_intern method is used" do
      expect { binary.intern_multiple(String, "foo") }.to raise_error(NotImplementedError)
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

    ["hello", 1, 1.0].each do |input|
      it "should just return a #{input.inspect}" do
        expect(console.render(input)).to eq(input)
      end
    end

    [true, false, nil, Object.new].each do |input|
      it "renders #{input.class} using PSON" do
        expect(console.render(input)).to eq(input.to_pson)
      end
    end

    [[1, 2], ["one"], [{ 1 => 1 }]].each do |input|
      it "should render #{input.inspect} as one item per line" do
        expect(console.render(input)).to eq(input.collect { |item| item.to_s + "\n" }.join(''))
      end
    end

    it "should render empty hashes as empty strings" do
      expect(console.render({})).to eq('')
    end

    it "should render a non-trivially-keyed Hash as pretty printed PSON" do
      hash = { [1,2] => 3, [2,3] => 5, [3,4] => 7 }
      expect(console.render(hash)).to eq(PSON.pretty_generate(hash).chomp)
    end

    it "should render a {String,Numeric}-keyed Hash into a table" do
      pson = Puppet::Network::FormatHandler.format(:pson)
      object = Object.new
      hash = { "one" => 1, "two" => [], "three" => {}, "four" => object,
        5 => 5, 6.0 => 6 }

      # Gotta love ASCII-betical sort order.  Hope your objects are better
      # structured for display than my test one is. --daniel 2011-04-18
      expect(console.render(hash)).to eq <<EOT
5      5
6.0    6
four   #{pson.render(object).chomp}
one    1
three  {}
two    []
EOT
    end

    it "should render a hash nicely with a multi-line value" do
      pending "Moving to PSON rather than PP makes this unsupportable."
      hash = {
        "number" => { "1" => '1' * 40, "2" => '2' * 40, '3' => '3' * 40 },
        "text"   => { "a" => 'a' * 40, 'b' => 'b' * 40, 'c' => 'c' * 40 }
      }
      expect(console.render(hash)).to eq <<EOT
number  {"1"=>"1111111111111111111111111111111111111111",
         "2"=>"2222222222222222222222222222222222222222",
         "3"=>"3333333333333333333333333333333333333333"}
text    {"a"=>"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
         "b"=>"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
         "c"=>"cccccccccccccccccccccccccccccccccccccccc"}
EOT
    end
  end
end
