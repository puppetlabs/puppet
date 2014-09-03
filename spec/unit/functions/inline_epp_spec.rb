
require 'spec_helper'

describe "the inline_epp function" do
  include PuppetSpec::Files

  before :all do
    Puppet::Parser::Functions.autoloader.loadall
  end

  before :each do
    Puppet[:parser] = 'future'
  end

  let :node     do Puppet::Node.new('localhost') end
  let :compiler do Puppet::Parser::Compiler.new(node) end
  let :scope    do Puppet::Parser::Scope.new(compiler) end

  context "when accessing scope variables as $ variables" do
    it "looks up the value from the scope" do
      scope["what"] = "are belong"
      eval_template("all your base <%= $what %> to us").should == "all your base are belong to us"
    end

    it "get nil accessing a variable that does not exist" do
      eval_template("<%= $kryptonite == undef %>").should == "true"
    end

    it "get nil accessing a variable that is undef" do
      scope['undef_var'] = :undef
      eval_template("<%= $undef_var == undef %>").should == "true"
    end

    it "gets shadowed variable if args are given" do
      scope['phantom'] = 'of the opera'
      eval_template_with_args("<%= $phantom == dragos %>", 'phantom' => 'dragos').should == "true"
    end

    it "gets shadowed variable if args are given and parameters are specified" do
      scope['x'] = 'wrong one'
      eval_template_with_args("<%-| $x |-%><%= $x == correct %>", 'x' => 'correct').should == "true"
    end

    it "raises an error if required variable is not given" do
      scope['x'] = 'wrong one'
      expect {
        eval_template_with_args("<%-| $x |-%><%= $x == correct %>", 'y' => 'correct')
      }.to raise_error(/no value given for required parameters x/)
    end

    it "raises an error if too many arguments are given" do
      scope['x'] = 'wrong one'
      expect {
        eval_template_with_args("<%-| $x |-%><%= $x == correct %>", 'x' => 'correct', 'y' => 'surplus')
      }.to raise_error(/Too many arguments: 2 for 1/)
    end
  end

  context "when given an empty template" do
     it "allows the template file to be empty" do
       expect(eval_template("")).to eq("")
     end

    it "allows the template to have empty body after parameters" do
      expect(eval_template_with_args("<%-|$x|%>", 'x'=>1)).to eq("")
    end
  end

  it "renders a block expression" do
    eval_template_with_args("<%= { $y = $x $x + 1} %>", 'x' => 2).should == "3"
  end

  # although never a problem with epp
  it "is not interfered with by having a variable named 'string' (#14093)" do
    scope['string'] = "this output should not be seen"
    eval_template("some text that is static").should == "some text that is static"
  end

  it "has access to a variable named 'string' (#14093)" do
    scope['string'] = "the string value"
    eval_template("string was: <%= $string %>").should == "string was: the string value"
  end


  def eval_template_with_args(content, args_hash)
    epp_function.call(scope, content, args_hash)
  end

  def eval_template(content)
    epp_function.call(scope, content)
  end

  def epp_function()
    epp_func = scope.compiler.loaders.public_environment_loader.load(:function, 'inline_epp')
  end

end
