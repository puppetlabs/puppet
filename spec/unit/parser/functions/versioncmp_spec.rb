require 'spec_helper'

describe "the versioncmp function" do
  before :each do
    node     = Puppet::Node.new('localhost')
    compiler = Puppet::Parser::Compiler.new(node)
    @scope   = Puppet::Parser::Scope.new(compiler)
  end

  it "should exist" do
    expect(Puppet::Parser::Functions.function("versioncmp")).to eq("function_versioncmp")
  end

  it "should raise an ArgumentError if there is less than 2 arguments" do
    expect { @scope.function_versioncmp(["1.2"]) }.to raise_error(ArgumentError)
  end

  it "should raise an ArgumentError if there is more than 2 arguments" do
    expect { @scope.function_versioncmp(["1.2", "2.4.5", "3.5.6"]) }.to raise_error(ArgumentError)
  end

  it "should call Puppet::Util::Package.versioncmp (included in scope)" do
    expect(Puppet::Util::Package).to receive(:versioncmp).with("1.2", "1.3").and_return(-1)

    @scope.function_versioncmp(["1.2", "1.3"])
  end

end
