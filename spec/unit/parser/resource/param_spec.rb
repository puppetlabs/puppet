require 'spec_helper'

describe Puppet::Parser::Resource::Param do
  it "has readers for all of the attributes" do
    param = Puppet::Parser::Resource::Param.new(:name => 'myparam', :value => 'foo', :file => 'foo.pp', :line => 42)

    expect(param.name).to eq(:myparam)
    expect(param.value).to eq('foo')
    expect(param.file).to eq('foo.pp')
    expect(param.line).to eq(42)
  end

  context "parameter validation" do
    it "throws an error when instantiated without a name" do
      expect {
        Puppet::Parser::Resource::Param.new(:value => 'foo')
      }.to raise_error(Puppet::Error, /name is a required option/)
    end

    it "does not require a value" do
      param = Puppet::Parser::Resource::Param.new(:name => 'myparam')

      expect(param.value).to be_nil
    end

    it "includes file/line context in errors" do
      expect {
        Puppet::Parser::Resource::Param.new(:file => 'foo.pp', :line => 42)
      }.to raise_error(Puppet::Error, /\(file: foo.pp, line: 42\)/)
    end
  end
end
