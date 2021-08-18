require 'spec_helper'
require 'puppet_spec/compiler'

describe 'ToStringifiedConverter' do
  include PuppetSpec::Compiler

  after(:all) { Puppet::Pops::Loaders.clear }

  let(:env) { Puppet::Node::Environment.create(:testing, []) }
  let(:loaders) { Puppet::Pops::Loaders.new(env) }
  let(:node) { Puppet::Node.new(env, environment: env) }

  def transform(v)
    Puppet::Pops::Serialization::ToStringifiedConverter.convert(v)
  end

  def eval_transform(source)
    Puppet.override(:current_environment => env, :loaders => loaders) do
      transform(evaluate(source: source, node: node))
    end
  end

  it 'converts undef to to nil' do
    expect(transform(nil)).to be_nil
    expect(eval_transform('undef')).to be_nil
  end

  it "converts literal default to the string 'default'" do
    expect(transform(:default)).to eq('default')
    expect(eval_transform('default')).to eq('default')
  end

  it "does not convert an integer" do
    expect(transform(42)).to eq(42)
  end

  it "does not convert a float" do
    expect(transform(3.14)).to eq(3.14)
  end

  it "does not convert a boolean" do
    expect(transform(true)).to be(true)
    expect(transform(false)).to be(false)
  end

  it "does not convert a string (that is free from encoding issues)" do
    expect(transform("hello")).to eq("hello")
  end

  it "converts a regexp to a string" do
    expect(transform(/this|that.*/)).to eq("/this|that.*/")
    expect(eval_transform('/this|that.*/')).to eq("/this|that.*/")
  end

  it 'handles a string with an embedded single quote' do
    expect(transform("ta'phoenix")).to eq("ta'phoenix")
  end

  it 'handles a string with embedded double quotes' do
    expect(transform('he said "hi"')).to eq("he said \"hi\"")
  end

  it 'converts a user defined object to its string representation including attributes' do
    result = evaluate(code: "type Car = Object[attributes=>{regnbr => String}]", source: "Car(abc123)")
    expect(transform(result)).to eq("Car({'regnbr' => 'abc123'})")
  end

  it 'converts a Deferred object to its string representation including attributes' do
    expect(eval_transform("Deferred(func, [1,2,3])")).to eq("Deferred({'name' => 'func', 'arguments' => [1, 2, 3]})")
  end

  it 'converts a Sensitive to type + redacted plus id' do
    sensitive = evaluate(source: "Sensitive('hush')")
    id = sensitive.object_id
    expect(transform(sensitive)).to eq("#<Sensitive [value redacted]:#{id}>")
  end

  it 'converts a Timestamp to String' do
    expect(eval_transform("Timestamp('2018-09-03T19:45:33.697066000 UTC')")).to eq("2018-09-03T19:45:33.697066000 UTC")
  end

  it 'does not convert an array' do
    expect(transform([1,2,3])).to eq([1,2,3])
  end

  it 'converts the content of an array - for example a Sensitive value' do
    sensitive = evaluate(source: "Sensitive('hush')")
    id = sensitive.object_id
    expect(transform([sensitive])).to eq(["#<Sensitive [value redacted]:#{id}>"])
  end

  it 'converts the content of a hash - for example a Sensitive value' do
    sensitive = evaluate(source: "Sensitive('hush')")
    id = sensitive.object_id
    expect(transform({'x' => sensitive})).to eq({'x' => "#<Sensitive [value redacted]:#{id}>"})
  end

  it 'does not convert a hash' do
    expect(transform({'a' => 10, 'b' => 20})).to eq({'a' => 10, 'b' => 20})
  end

  it 'converts non Data compliant hash key to string' do
    expect(transform({['funky', 'key'] => 10})).to eq({'["funky", "key"]' => 10})
  end

  it 'converts reserved __ptype hash key to different string' do
    expect(transform({'__ptype' => 10})).to eq({'reserved key: __ptype' => 10})
  end

  it 'converts reserved __pvalue hash key to different string' do
    expect(transform({'__pvalue' => 10})).to eq({'reserved key: __pvalue' => 10})
  end

  it 'converts a Binary to Base64 string' do
    expect(eval_transform("Binary('hello', '%s')")).to eq("aGVsbG8=")
  end

  it 'converts an ASCII-8BIT String to Base64 String' do
    binary_string = "\x02\x03\x04hello".force_encoding('ascii-8bit')
    expect(transform(binary_string)).to eq("AgMEaGVsbG8=")
  end

  it 'converts Runtime (alien) object to its to_s' do
    class Alien
    end
    an_alien = Alien.new
    expect(transform(an_alien)).to eq(an_alien.to_s)
  end

  it 'converts a runtime Symbol to String' do
    expect(transform(:symbolic)).to eq("symbolic")
  end

  it 'converts a datatype (such as Integer[0,10]) to its puppet source string form' do
    expect(eval_transform("Integer[0,100]")).to eq("Integer[0, 100]")
  end

  it 'converts a user defined datatype (such as Car) to its puppet source string form' do
    result = evaluate(code: "type Car = Object[attributes=>{regnbr => String}]", source: "Car")
    expect(transform(result)).to eq("Car")
  end

  it 'converts a self referencing user defined datatype by using named references for cyclic entries' do
    result = evaluate(code: "type Tree = Array[Variant[String, Tree]]", source: "Tree")
    expect(transform(result)).to eq("Tree = Array[Variant[String, Tree]]")
  end

  it 'converts illegal char sequence in an encoding to Unicode Illegal' do
    invalid_sequence = [0xc2, 0xc2].pack("c*").force_encoding(Encoding::UTF_8)
    expect(transform(invalid_sequence)).to eq("��")
  end

  it 'does not convert unassigned char - glyph is same for all unassigned' do
    unassigned = [243, 176, 128, 128].pack("C*").force_encoding(Encoding::UTF_8) 
    expect(transform(unassigned)).to eq("󰀀")
  end

  it 'converts ProcessOutput objects to string' do
    object = Puppet::Util::Execution::ProcessOutput.new('object', 0)
    expect(transform(object)).to be_instance_of(String)
  end
end
