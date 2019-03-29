require 'spec_helper'

describe "the template function" do
  let :node     do Puppet::Node.new('localhost') end
  let :compiler do Puppet::Parser::Compiler.new(node) end
  let :scope    do Puppet::Parser::Scope.new(compiler) end

  it "concatenates outputs for multiple templates" do
    tw1 = double("template_wrapper1")
    tw2 = double("template_wrapper2")
    allow(Puppet::Parser::TemplateWrapper).to receive(:new).and_return(tw1,tw2)
    allow(tw1).to receive(:file=).with("1")
    allow(tw2).to receive(:file=).with("2")
    allow(tw1).to receive(:result).and_return("result1")
    allow(tw2).to receive(:result).and_return("result2")

    expect(scope.function_template(["1","2"])).to eq("result1result2")
  end

  it "raises an error if the template raises an error" do
    tw = double('template_wrapper')
    allow(tw).to receive(:file=).with("1")
    allow(Puppet::Parser::TemplateWrapper).to receive(:new).and_return(tw)
    allow(tw).to receive(:result).and_raise

    expect {
      scope.function_template(["1"])
    }.to raise_error(Puppet::ParseError, /Failed to parse template/)
  end

  context "when accessing scope variables via method calls (deprecated)" do
    it "raises an error when accessing an undefined variable" do
      expect {
        eval_template("template <%= deprecated %>")
      }.to raise_error(Puppet::ParseError, /undefined local variable or method `deprecated'/)
    end

    it "looks up the value from the scope" do
      scope["deprecated"] = "deprecated value"
      expect { eval_template("template <%= deprecated %>")}.to raise_error(/undefined local variable or method `deprecated'/)
    end

    it "still has access to Kernel methods" do
      expect { eval_template("<%= binding %>") }.to_not raise_error
    end
  end

  context "when accessing scope variables as instance variables" do
    it "has access to values" do
      scope['scope_var'] = "value"
      expect(eval_template("<%= @scope_var %>")).to eq("value")
    end

    it "get nil accessing a variable that does not exist" do
      expect(eval_template("<%= @not_defined.nil? %>")).to eq("true")
    end

    it "get nil accessing a variable that is undef" do
      scope['undef_var'] = :undef
      expect(eval_template("<%= @undef_var.nil? %>")).to eq("true")
    end
  end

  it "is not interfered with by having a variable named 'string' (#14093)" do
    scope['string'] = "this output should not be seen"
    expect(eval_template("some text that is static")).to eq("some text that is static")
  end

  it "has access to a variable named 'string' (#14093)" do
    scope['string'] = "the string value"
    expect(eval_template("string was: <%= @string %>")).to eq("string was: the string value")
  end

  it "does not have direct access to Scope#lookupvar" do
    expect {
      eval_template("<%= lookupvar('myvar') %>")
    }.to raise_error(Puppet::ParseError, /undefined method `lookupvar'/)
  end

  it 'is not available when --tasks is on' do
    Puppet[:tasks] = true
    expect {
      eval_template("<%= lookupvar('myvar') %>")
    }.to raise_error(Puppet::ParseError, /is only available when compiling a catalog/)

  end

  def eval_template(content)
    allow(Puppet::FileSystem).to receive(:read_preserve_line_endings).with("template").and_return(content)
    allow(Puppet::Parser::Files).to receive(:find_template).and_return("template")
    scope.function_template(['template'])
  end
end
