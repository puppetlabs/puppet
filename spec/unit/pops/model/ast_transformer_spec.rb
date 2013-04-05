require 'spec_helper'

require File.join(File.dirname(__FILE__), '/../factory_rspec_helper')
require 'puppet/pops'

describe Puppet::Pops::Model::AstTransformer do
  include FactoryRspecHelper

  let(:filename) { "the-file.pp" }
  let(:transformer) { Puppet::Pops::Model::AstTransformer.new(filename) }

  context "literal numbers" do
    it "converts a decimal number to a string Name" do
      ast = transform(QNAME_OR_NUMBER("10"))

      ast.should be_kind_of Puppet::Parser::AST::Name
      ast.value.should == "10"
    end

    it "converts an octal number to a string Name" do
      ast = transform(QNAME_OR_NUMBER("020"))

      ast.should be_kind_of Puppet::Parser::AST::Name
      ast.value.should == "020"
    end

    it "converts a hex number to a string Name" do
      ast = transform(QNAME_OR_NUMBER("0x20"))

      ast.should be_kind_of Puppet::Parser::AST::Name
      ast.value.should == "0x20"
    end

    it "converts an unknown radix to an error string" do
      ast = transform(Puppet::Pops::Model::Factory.new(Puppet::Pops::Model::LiteralNumber, 3, 2))

      ast.should be_kind_of Puppet::Parser::AST::Name
      ast.value.should == "bad radix:3"
    end
  end

  it "preserves the file location" do
    model = literal(1)
    model.record_position(location(3, 1, 10), location(3, 2, 11))

    ast = transform(model)

    ast.file.should == filename
    ast.line.should == 3
    ast.pos.should == 1
  end

  def transform(model)
    transformer.transform(model)
  end

  def location(line, column, offset)
    position = Puppet::Pops::Adapters::SourcePosAdapter.new
    position.line = line
    position.pos = column
    position.offset = offset

    position
  end
end
