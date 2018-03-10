require 'spec_helper'
require 'puppet_spec/compiler'

describe "Two step scoping for variables" do
  include PuppetSpec::Compiler
  def expect_the_message_to_be(message, node = Puppet::Node.new('the node'))
    catalog = compile_to_catalog(yield, node)
    expect(catalog.resource('Notify', 'something')[:message]).to eq(message)
  end

  def expect_the_message_not_to_be(message, node = Puppet::Node.new('the node'))
    catalog = compile_to_catalog(yield, node)
    expect(catalog.resource('Notify', 'something')[:message]).to_not eq(message)
  end

  before :each do
    Puppet.expects(:deprecation_warning).never
  end

  describe "using unsupported operators" do
    it "issues an error for +=" do
      expect do
        compile_to_catalog(<<-MANIFEST)
              $var = ["top_msg"]
              node default {
                $var += ["override"]
              }
        MANIFEST
      end.to raise_error(/The operator '\+=' is no longer supported/)
    end

    it "issues an error for -=" do
      expect do
        compile_to_catalog(<<-MANIFEST)
              $var = ["top_msg"]
              node default {
                $var -= ["top_msg"]
              }
        MANIFEST
      end.to raise_error(/The operator '-=' is no longer supported/)
    end

    it "issues error about built-in variable when reassigning to name" do
        enc_node = Puppet::Node.new("the_node", { :parameters => {  } })

        expect {
          compile_to_catalog("$name = 'never in a 0xF4240 years'", enc_node)
        }.to raise_error(
          Puppet::Error,
          /Cannot reassign built in \(or already assigned\) variable '\$name' \(line: 1(, column: 7)?\) on node the_node/
        )
    end

    it "issues error about built-in variable when reassigning to title" do
        enc_node = Puppet::Node.new("the_node", { :parameters => {  } })

        expect {
          compile_to_catalog("$title = 'never in a 0xF4240 years'", enc_node)
        }.to raise_error(
          Puppet::Error,
          /Cannot reassign built in \(or already assigned\) variable '\$title' \(line: 1(, column: 8)?\) on node the_node/
        )
    end

    it "when using a template ignores the dynamic value of the var when using the @varname syntax" do
      expect_the_message_to_be('node_msg') do <<-MANIFEST
          node default {
            $var = "node_msg"
            include foo
          }
          class foo {
            $var = "foo_msg"
            include bar
          }
          class bar {
            notify { 'something': message => inline_template("<%= @var %>"), }
          }
      MANIFEST
    end
  end

  it "when using a template gets the var from an inherited class when using the @varname syntax" do
    expect_the_message_to_be('Barbamama') do <<-MANIFEST
          node default {
            $var = "node_msg"
            include bar_bamama
            include foo
          }
          class bar_bamama {
            $var = "Barbamama"
          }
          class foo {
            $var = "foo_msg"
            include bar
          }
          class bar inherits bar_bamama {
            notify { 'something': message => inline_template("<%= @var %>"), }
          }
      MANIFEST
    end
  end

  it "when using a template ignores the dynamic var when it is not present in an inherited class" do
    expect_the_message_to_be('node_msg') do <<-MANIFEST
          node default {
            $var = "node_msg"
            include bar_bamama
            include foo
          }
          class bar_bamama {
          }
          class foo {
            $var = "foo_msg"
            include bar
          }
          class bar inherits bar_bamama {
            notify { 'something': message => inline_template("<%= @var %>"), }
          }
        MANIFEST
      end
    end

    describe 'handles 3.x/4.x functions' do
      it 'can call a 3.x function via call_function' do
        expect_the_message_to_be('yes') do <<-MANIFEST
          $msg = inline_template('<%= scope().call_function("fqdn_rand", [30]).to_i <= 30 ? "yes" : "no" %>')
          notify { 'something': message => $msg }
          MANIFEST
        end
      end

      it 'it can call a 4.x function via call_function' do
        expect_the_message_to_be('yes') do <<-MANIFEST
          $msg = inline_template('<%= scope().call_function("with", ["yes"]) { |x| x } %>')
          notify { 'something': message => $msg }
          MANIFEST
        end
      end
    end
  end

  describe "fully qualified variable names" do
    it "keeps nodescope separate from topscope" do
      expect_the_message_to_be('topscope') do <<-MANIFEST
            $c = "topscope"
            node default {
              $c = "nodescope"
              notify { 'something': message => $::c }
            }
        MANIFEST
      end
    end
  end

  describe "when colliding class and variable names" do
    it "finds a topscope variable with the same name as a class" do
      expect_the_message_to_be('topscope') do <<-MANIFEST
            $c = "topscope"
            class c { }
            node default {
              include c
              notify { 'something': message => $c }
            }
        MANIFEST
      end
    end

    it "finds a node scope variable with the same name as a class" do
      expect_the_message_to_be('nodescope') do <<-MANIFEST
            class c { }
            node default {
              $c = "nodescope"
              include c
              notify { 'something': message => $c }
            }
        MANIFEST
      end
    end

    it "finds a class variable when the class collides with a nodescope variable" do
      expect_the_message_to_be('class') do <<-MANIFEST
            class c { $b = "class" }
            node default {
              $c = "nodescope"
              include c
              notify { 'something': message => $c::b }
            }
        MANIFEST
      end
    end

    it "finds a class variable when the class collides with a topscope variable" do
      expect_the_message_to_be('class') do <<-MANIFEST
            $c = "topscope"
            class c { $b = "class" }
            node default {
              include c
              notify { 'something': message => $::c::b }
            }
        MANIFEST
      end
    end
  end

  describe "when using shadowing and inheritance" do
    it "finds values in its local scope" do
      expect_the_message_to_be('local_msg') do <<-MANIFEST
            node default {
              include baz
            }
            class foo {
            }
            class bar inherits foo {
              $var = "local_msg"
              notify { 'something': message => $var, }
            }
            class baz {
              include bar
            }
        MANIFEST
      end
    end

    it "finds values in its inherited scope" do
      expect_the_message_to_be('foo_msg') do <<-MANIFEST
            node default {
              include baz
            }
            class foo {
              $var = "foo_msg"
            }
            class bar inherits foo {
              notify { 'something': message => $var, }
            }
            class baz {
              include bar
            }
        MANIFEST
      end
    end

    it "prefers values in its local scope over values in the inherited scope" do
      expect_the_message_to_be('local_msg') do <<-MANIFEST
            include bar

            class foo {
              $var = "inherited"
            }

            class bar inherits foo {
              $var = "local_msg"
              notify { 'something': message => $var, }
            }
        MANIFEST
      end
    end

    it "finds a qualified variable by following inherited scope of the specified scope" do
      expect_the_message_to_be("from parent") do <<-MANIFEST
            class c {
              notify { 'something': message => "$a::b" }
            }
            class parent {
              $b = 'from parent'
            }
            class a inherits parent { }

            node default {
              $b = "from node"
              include a
              include c
            }
        MANIFEST
      end
    end

    ['a:.b', '::a::b'].each do |ref|
      it "does not resolve a qualified name on the form #{ref} against top scope" do
        expect_the_message_not_to_be("from topscope") do <<-"MANIFEST"
              class c {
                notify { 'something': message => "$#{ref}" }
              }
              class parent {
                $not_b = 'from parent'
              }
              class a inherits parent { }

              $b = "from topscope"
              node default {
                include a
                include c
              }
          MANIFEST
        end
      end
    end

    ['a:.b', '::a::b'].each do |ref|
      it "does not resolve a qualified name on the form #{ref} against node scope" do
        expect_the_message_not_to_be("from node") do <<-MANIFEST
              class c {
                notify { 'something': message => "$a::b" }
              }
              class parent {
                $not_b = 'from parent'
              }
              class a inherits parent { }

              node default {
                $b = "from node"
                include a
                include c
              }
          MANIFEST
        end
      end
    end

    it 'resolves a qualified name in class parameter scope' do
      expect_the_message_to_be('Does it work? Yes!') do <<-PUPPET
        class a ( 
          $var1 = 'Does it work?',
          $var2 = "${a::var1} Yes!"
        ) { 
          notify { 'something': message => $var2 }
        }
        include a
        PUPPET
      end
    end

    it "finds values in its inherited scope when the inherited class is qualified to the top" do
      expect_the_message_to_be('foo_msg') do <<-MANIFEST
            node default {
              include baz
            }
            class foo {
              $var = "foo_msg"
            }
            class bar inherits ::foo {
              notify { 'something': message => $var, }
            }
            class baz {
              include bar
            }
        MANIFEST
      end
    end

    it "prefers values in its local scope over values in the inherited scope when the inherited class is fully qualified" do
      expect_the_message_to_be('local_msg') do <<-MANIFEST
            include bar

            class foo {
              $var = "inherited"
            }

            class bar inherits ::foo {
              $var = "local_msg"
              notify { 'something': message => $var, }
            }
        MANIFEST
      end
    end

    it "finds values in top scope when the inherited class is qualified to the top" do
      expect_the_message_to_be('top msg') do <<-MANIFEST
            $var = "top msg"
            class foo {
            }

            class bar inherits ::foo {
              notify { 'something': message => $var, }
            }

            include bar
        MANIFEST
      end
    end

    it "finds values in its inherited scope when the inherited class is a nested class that shadows another class at the top" do
      expect_the_message_to_be('inner baz') do <<-MANIFEST
            node default {
              include foo::bar
            }
            class baz {
              $var = "top baz"
            }
            class foo {
              class baz {
                $var = "inner baz"
              }

              class bar inherits foo::baz {
                notify { 'something': message => $var, }
              }
            }
        MANIFEST
      end
    end

    it "finds values in its inherited scope when the inherited class is qualified to a nested class and qualified to the top" do
      expect_the_message_to_be('top baz') do <<-MANIFEST
            node default {
              include foo::bar
            }
            class baz {
              $var = "top baz"
            }
            class foo {
              class baz {
                $var = "inner baz"
              }

              class bar inherits ::baz {
                notify { 'something': message => $var, }
              }
            }
        MANIFEST
      end
    end

    it "finds values in its inherited scope when the inherited class is qualified" do
      expect_the_message_to_be('foo_msg') do <<-MANIFEST
            node default {
              include bar
            }
            class foo {
              class baz {
                $var = "foo_msg"
              }
            }
            class bar inherits foo::baz {
              notify { 'something': message => $var, }
            }
        MANIFEST
      end
    end

    it "prefers values in its inherited scope over those in the node (with intermediate inclusion)" do
      expect_the_message_to_be('foo_msg') do <<-MANIFEST
            node default {
              $var = "node_msg"
              include baz
            }
            class foo {
              $var = "foo_msg"
            }
            class bar inherits foo {
              notify { 'something': message => $var, }
            }
            class baz {
              include bar
            }
        MANIFEST
      end
    end

    it "prefers values in its inherited scope over those in the node (without intermediate inclusion)" do
      expect_the_message_to_be('foo_msg') do <<-MANIFEST
            node default {
              $var = "node_msg"
              include bar
            }
            class foo {
              $var = "foo_msg"
            }
            class bar inherits foo {
              notify { 'something': message => $var, }
            }
        MANIFEST
      end
    end

    it "prefers values in its inherited scope over those from where it is included" do
      expect_the_message_to_be('foo_msg') do <<-MANIFEST
            node default {
              include baz
            }
            class foo {
              $var = "foo_msg"
            }
            class bar inherits foo {
              notify { 'something': message => $var, }
            }
            class baz {
              $var = "baz_msg"
              include bar
            }
        MANIFEST
      end
    end

    it "does not used variables from classes included in the inherited scope" do
      expect_the_message_to_be('node_msg') do <<-MANIFEST
            node default {
              $var = "node_msg"
              include bar
            }
            class quux {
              $var = "quux_msg"
            }
            class foo inherits quux {
            }
            class baz {
              include foo
            }
            class bar inherits baz {
              notify { 'something': message => $var, }
            }
        MANIFEST
      end
    end

    it "does not use a variable from a scope lexically enclosing it" do
      expect_the_message_to_be('node_msg') do <<-MANIFEST
            node default {
              $var = "node_msg"
              include other::bar
            }
            class other {
              $var = "other_msg"
              class bar {
                notify { 'something': message => $var, }
              }
            }
        MANIFEST
      end
    end

    it "finds values in its node scope" do
      expect_the_message_to_be('node_msg') do <<-MANIFEST
            node default {
              $var = "node_msg"
              include baz
            }
            class foo {
            }
            class bar inherits foo {
              notify { 'something': message => $var, }
            }
            class baz {
              include bar
            }
        MANIFEST
      end
    end

    it "finds values in its top scope" do
      expect_the_message_to_be('top_msg') do <<-MANIFEST
            $var = "top_msg"
            node default {
              include baz
            }
            class foo {
            }
            class bar inherits foo {
              notify { 'something': message => $var, }
            }
            class baz {
              include bar
            }
        MANIFEST
      end
    end

    it "prefers variables from the node over those in the top scope" do
      expect_the_message_to_be('node_msg') do <<-MANIFEST
            $var = "top_msg"
            node default {
              $var = "node_msg"
              include foo
            }
            class foo {
              notify { 'something': message => $var, }
            }
        MANIFEST
      end
    end

    it "finds top scope variables referenced inside a defined type" do
      expect_the_message_to_be('top_msg') do <<-MANIFEST
            $var = "top_msg"
            node default {
              foo { "testing": }
            }
            define foo() {
              notify { 'something': message => $var, }
            }
        MANIFEST
      end
    end

    it "finds node scope variables referenced inside a defined type" do
      expect_the_message_to_be('node_msg') do <<-MANIFEST
            $var = "top_msg"
            node default {
              $var = "node_msg"
              foo { "testing": }
            }
            define foo() {
              notify { 'something': message => $var, }
            }
        MANIFEST
      end
    end
  end

  describe "in situations that used to have dynamic lookup" do
    it "ignores the dynamic value of the var" do
      expect_the_message_to_be('node_msg') do <<-MANIFEST
            node default {
              $var = "node_msg"
              include foo
            }
            class baz {
              $var = "baz_msg"
              include bar
            }
            class foo inherits baz {
            }
            class bar {
              notify { 'something': message => $var, }
            }
        MANIFEST
      end
    end

    it "finds nil when the only set variable is in the dynamic scope" do
      expect_the_message_to_be(nil) do <<-MANIFEST
            node default {
              include baz
            }
            class foo {
            }
            class bar inherits foo {
              notify { 'something': message => $var, }
            }
            class baz {
              $var = "baz_msg"
              include bar
            }
        MANIFEST
      end
    end

    it "ignores the value in the dynamic scope for a defined type" do
      expect_the_message_to_be('node_msg') do <<-MANIFEST
            node default {
              $var = "node_msg"
              include foo
            }
            class foo {
              $var = "foo_msg"
              bar { "testing": }
            }
            define bar() {
              notify { 'something': message => $var, }
            }
        MANIFEST
      end
    end

    it "when using a template ignores the dynamic value of the var when using scope.lookupvar" do
      expect_the_message_to_be('node_msg') do <<-MANIFEST
            node default {
              $var = "node_msg"
              include foo
            }
            class foo {
              $var = "foo_msg"
              include bar
            }
            class bar {
              notify { 'something': message => inline_template("<%= scope.lookupvar('var') %>"), }
            }
        MANIFEST
      end
    end
  end

  describe "when using an enc" do
    it "places enc parameters in top scope" do
      enc_node = Puppet::Node.new("the node", { :parameters => { "var" => 'from_enc' } })

      expect_the_message_to_be('from_enc', enc_node) do <<-MANIFEST
            notify { 'something': message => $var, }
        MANIFEST
      end
    end

    it "does not allow the enc to specify an existing top scope var" do
      enc_node = Puppet::Node.new("the_node", { :parameters => { "var" => 'from_enc' } })
      expect {
        compile_to_catalog("$var = 'top scope'", enc_node)
      }.to raise_error(
        Puppet::Error,
        /Cannot reassign variable '\$var' \(line: 1(, column: 6)?\) on node the_node/
      )
    end

    it "evaluates enc classes in top scope when there is no node" do
      enc_node = Puppet::Node.new("the node", { :classes => ['foo'], :parameters => { "var" => 'from_enc' } })

      expect_the_message_to_be('from_enc', enc_node) do <<-MANIFEST
            class foo {
              notify { 'something': message => $var, }
            }
        MANIFEST
      end
    end

    it "overrides enc variables from a node scope var" do
      enc_node = Puppet::Node.new("the_node", { :classes => ['foo'], :parameters => { 'enc_var' => 'Set from ENC.' } })

      expect_the_message_to_be('ENC overridden in node', enc_node) do <<-MANIFEST
            node the_node {
              $enc_var = "ENC overridden in node"
            }

            class foo {
              notify { 'something': message => $enc_var, }
            }
        MANIFEST
      end
    end
  end
end
