require 'spec_helper'

require 'puppet_spec/compiler'

describe "the inline_epp function" do
  include PuppetSpec::Files
  include PuppetSpec::Compiler

  let :node     do Puppet::Node.new('localhost') end
  let :compiler do Puppet::Parser::Compiler.new(node) end
  let :scope    do Puppet::Parser::Scope.new(compiler) end

  context "when accessing scope variables as $ variables" do
    it "looks up the value from the scope" do
      scope["what"] = "are belong"
      expect(eval_template("all your base <%= $what %> to us")).to eq("all your base are belong to us")
    end

    it "gets error accessing a variable that does not exist" do
      expect { eval_template("<%= $kryptonite == undef %>")}.to raise_error(/Evaluation Error: Unknown variable: 'kryptonite'./)
    end

    it "get nil accessing a variable that does not exist when strict mode is off" do
      Puppet[:strict_variables] = false
      Puppet[:strict] = :warning
      expect(eval_template("<%= $kryptonite == undef %>")).to eq("true")
    end

    it "get nil accessing a variable that is undef" do
      scope['undef_var'] = :undef
      expect(eval_template("<%= $undef_var == undef %>")).to eq("true")
    end

    it "gets shadowed variable if args are given" do
      scope['phantom'] = 'of the opera'
      expect(eval_template_with_args("<%= $phantom == dragos %>", 'phantom' => 'dragos')).to eq("true")
    end

    it "gets shadowed variable if args are given and parameters are specified" do
      scope['x'] = 'wrong one'
      expect(eval_template_with_args("<%-| $x |-%><%= $x == correct %>", 'x' => 'correct')).to eq("true")
    end

    it "raises an error if required variable is not given" do
      scope['x'] = 'wrong one'
      expect {
        eval_template_with_args("<%-| $x |-%><%= $x == correct %>", {})
      }.to raise_error(/expects a value for parameter 'x'/)
    end

    it 'raises an error if unexpected arguments are given' do
      scope['x'] = 'wrong one'
      expect {
        eval_template_with_args("<%-| $x |-%><%= $x == correct %>", 'x' => 'correct', 'y' => 'surplus')
      }.to raise_error(/has no parameter named 'y'/)
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
    expect(eval_template_with_args("<%= { $y = $x $x + 1} %>", 'x' => 2)).to eq("3")
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

  context "when using Sensitive" do
    it "returns an unwrapped sensitive value as a String" do
      expect(eval_and_collect_notices(<<~END)).to eq(["opensesame"])
        notice(inline_epp("<%= Sensitive('opensesame').unwrap %>"))
      END
    end

    it "rewraps a sensitive value" do
      # note entire result is redacted, not just sensitive part
      expect(eval_and_collect_notices(<<~END)).to eq(["Sensitive [value redacted]"])
        notice(inline_epp("This is sensitive <%= Sensitive('opensesame') %>"))
      END
    end

    it "can be double wrapped" do
      catalog = compile_to_catalog(<<~END)
        notify { 'title':
          message => Sensitive(inline_epp("<%= Sensitive('opensesame') %>"))
        }
      END
      expect(catalog.resource(:notify, 'title')['message']).to eq('opensesame')
    end
  end

  def eval_template_with_args(content, args_hash)
    epp_function.call(scope, content, args_hash)
  end

  def eval_template(content)
    epp_function.call(scope, content)
  end

  def epp_function()
    scope.compiler.loaders.public_environment_loader.load(:function, 'inline_epp')
  end

end
