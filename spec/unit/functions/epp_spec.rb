require 'spec_helper'

describe "the epp function" do
  include PuppetSpec::Files

  let :node     do Puppet::Node.new('localhost') end
  let :compiler do Puppet::Parser::Compiler.new(node) end
  let :scope    do compiler.topscope end

  context "when accessing scope variables as $ variables" do
    it "looks up the value from the scope" do
      scope["what"] = "are belong"
      expect(eval_template("all your base <%= $what %> to us")).to eq("all your base are belong to us")
    end

    it "looks up a fully qualified value from the scope" do
      scope["what::is"] = "are belong"
      expect(eval_template("all your base <%= $what::is %> to us")).to eq("all your base are belong to us")
    end

    it "get nil accessing a variable that does not exist" do
      expect(eval_template("<%= $kryptonite == undef %>")).to eq("true")
    end

    it "gets error accessing a variable that is malformed" do
      expect { eval_template("<%= $kryptonite::bbbbbbbbbbbb::cccccccc::ddd::USER %>")}.to raise_error(
        /Illegal variable name, The given name 'kryptonite::bbbbbbbbbbbb::cccccccc::ddd::USER' does not conform to the naming rule/)
    end

    it "gets error accessing a variable that is malformed as reported in PUP-7848" do
      expect { eval_template("USER='<%= $hg_oais::archivematica::requirements::automation_tools::USER %>'")}.to raise_error(
        /Illegal variable name, The given name 'hg_oais::archivematica::requirements::automation_tools::USER' does not conform to the naming rule/)
    end

    it "get nil accessing a variable that is undef" do
      scope['undef_var'] = nil
      expect(eval_template("<%= $undef_var == undef %>")).to eq("true")
    end

    it "gets shadowed variable if args are given" do
      scope['phantom'] = 'of the opera'
      expect(eval_template_with_args("<%= $phantom == dragos %>", 'phantom' => 'dragos')).to eq("true")
    end

    it "can use values from the global scope for defaults" do
      scope['phantom'] = 'of the opera'
      expect(eval_template("<%- |$phantom = $::phantom| -%><%= $phantom %>")).to eq("of the opera")
    end

    it "will not use values from the enclosing scope for defaults" do
      scope['the_phantom'] = 'of the state opera'
      scope.new_ephemeral(true)
      scope['the_phantom'] = 'of the local opera'
      expect(scope['the_phantom']).to eq('of the local opera')
      expect(eval_template("<%- |$phantom = $the_phantom| -%><%= $phantom %>")).to eq("of the state opera")
     end

    it "uses the default value if the given value is undef/nil" do
      expect(eval_template_with_args("<%- |$phantom = 'inside your mind'| -%><%= $phantom %>", 'phantom' => nil)).to eq("inside your mind")
    end

    it "gets shadowed variable if args are given and parameters are specified" do
      scope['x'] = 'wrong one'
      expect(eval_template_with_args("<%- |$x| -%><%= $x == correct %>", 'x' => 'correct')).to eq("true")
    end

    it "raises an error if required variable is not given" do
      scope['x'] = 'wrong one'
      expect do
        eval_template("<%-| $x |-%><%= $x == correct %>")
      end.to raise_error(/expects a value for parameter 'x'/)
    end

    it 'raises an error if invalid arguments are given' do
      scope['x'] = 'wrong one'
      expect do
        eval_template_with_args("<%-| $x |-%><%= $x == correct %>", 'x' => 'correct', 'y' => 'surplus')
      end.to raise_error(/has no parameter named 'y'/)
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
      end.to raise_error(/parameter 'x' expects an Integer value, got String/)
    end

    it "raises an error when the default value does not match the parameter's type" do
      expect do
        eval_template("<%-|Integer $x = 'nope'|-%><%= $x %>")
      end.to raise_error(/parameter 'x' expects an Integer value, got String/)
    end

    it "allows an parameter to default to undef" do
      expect(eval_template("<%-|Optional[Integer] $x = undef|-%><%= $x == undef %>")).to eq("true")
    end
  end

  it "preserves CRLF when reading the template" do
    expect(eval_template("some text that\r\nis static with CRLF")).to eq("some text that\r\nis static with CRLF")
  end

  # although never a problem with epp
  it "is not interfered with by having a variable named 'string' (#14093)" do
    scope['string'] = "this output should not be seen"
    expect(eval_template("some text that is static")).to eq("some text that is static")
  end

  it "has access to a variable named 'string' (#14093)" do
    scope['string'] = "the string value"
    expect(eval_template("string was: <%= $string %>")).to eq("string was: the string value")
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
    File.open(filename, "wb+") { |f| f.write(content) }

    Puppet::Parser::Files.stubs(:find_template).returns(filename)
    epp_function.call(scope, 'template', args_hash)
  end

  def eval_template(content)
    file_path = tmpdir('epp_spec_content')
    filename = File.join(file_path, "template.epp")
    File.open(filename, "wb+") { |f| f.write(content) }

    Puppet::Parser::Files.stubs(:find_template).returns(filename)
    epp_function.call(scope, 'template')
  end

  def epp_function()
    scope.compiler.loaders.public_environment_loader.load(:function, 'epp')
  end
end
