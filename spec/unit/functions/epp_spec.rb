require 'spec_helper'

describe "the epp function" do
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
      scope['undef_var'] = nil
      eval_template("<%= $undef_var == undef %>").should == "true"
    end

    it "gets shadowed variable if args are given" do
      scope['phantom'] = 'of the opera'
      eval_template_with_args("<%= $phantom == dragos %>", 'phantom' => 'dragos').should == "true"
    end

    it "can use values from the enclosing scope for defaults" do
      scope['phantom'] = 'of the opera'
      eval_template("<%- |$phantom = $phantom| -%><%= $phantom %>").should == "of the opera"
    end

    it "uses the default value if the given value is undef/nil" do
      eval_template_with_args("<%- |$phantom = 'inside your mind'| -%><%= $phantom %>", 'phantom' => nil).should == "inside your mind"
    end

    it "gets shadowed variable if args are given and parameters are specified" do
      scope['x'] = 'wrong one'
      eval_template_with_args("<%- |$x| -%><%= $x == correct %>", 'x' => 'correct').should == "true"
    end

    it "raises an error if required variable is not given" do
      scope['x'] = 'wrong one'
      expect do
        eval_template_with_args("<%-| $x |-%><%= $x == correct %>", 'y' => 'correct')
      end.to raise_error(/no value given for required parameters x/)
    end

    it "raises an error if too many arguments are given" do
      scope['x'] = 'wrong one'
      expect do
        eval_template_with_args("<%-| $x |-%><%= $x == correct %>", 'x' => 'correct', 'y' => 'surplus')
      end.to raise_error(/Too many arguments: 2 for 1/)
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

  context "when using typed parameters" do
    it "allows a passed value that matches the parameter's type" do
      expect(eval_template_with_args("<%-|String $x|-%><%= $x == correct %>", 'x' => 'correct')).to eq("true")
    end

    it "does not allow slurped parameters" do
      expect do
        eval_template_with_args("<%-|*$x|-%><%= $x %>", 'x' => 'incorrect')
      end.to raise_error(/'captures rest' - not supported in an Epp Template/)
    end

    it "raises an error when the passed value does not match the parameter's type" do
      expect do
        eval_template_with_args("<%-|Integer $x|-%><%= $x %>", 'x' => 'incorrect')
      end.to raise_error(/expected.*Integer.*actual.*String/m)
    end

    it "raises an error when the default value does not match the parameter's type" do
      expect do
        eval_template("<%-|Integer $x = 'nope'|-%><%= $x %>")
      end.to raise_error(/expected.*Integer.*actual.*String/m)
    end

    it "allows an parameter to default to undef" do
      expect(eval_template("<%-|Optional[Integer] $x = undef|-%><%= $x == undef %>")).to eq("true")
    end
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

  describe 'when loading from modules' do
    include PuppetSpec::Files
    it 'an epp template is found' do
      modules_dir = dir_containing('modules', {
        'testmodule'  => {
            'templates' => {
              'the_x.epp' => 'The x is <%= $x %>'
            }
        }})
      Puppet.override({:current_environment => (env = Puppet::Node::Environment.create(:testload, [ modules_dir ]))}, "test") do
        node.environment = env
        expect(epp_function.call(scope, 'testmodule/the_x.epp', { 'x' => '3'} )).to eql("The x is 3")
      end
    end
  end

  def eval_template_with_args(content, args_hash)
    file_path = tmpdir('epp_spec_content')
    filename = File.join(file_path, "template.epp")
    File.open(filename, "w+") { |f| f.write(content) }

    Puppet::Parser::Files.stubs(:find_template).returns(filename)
    epp_function.call(scope, 'template', args_hash)
  end

  def eval_template(content)
    file_path = tmpdir('epp_spec_content')
    filename = File.join(file_path, "template.epp")
    File.open(filename, "w+") { |f| f.write(content) }

    Puppet::Parser::Files.stubs(:find_template).returns(filename)
    epp_function.call(scope, 'template')
  end

  def epp_function()
    epp_func = scope.compiler.loaders.public_environment_loader.load(:function, 'epp')
  end
end
