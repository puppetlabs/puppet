require 'spec_helper'
require 'puppet/pops'
require 'puppet/parser/parser_factory'
require 'puppet_spec/compiler'
require 'puppet_spec/pops'
require 'puppet_spec/scope'
require 'matchers/resource'
require 'rgen/metamodel_builder'

# These tests are in a separate file since othr compiler related tests have
# been dramatically changed between 3.x and 4.x and it is a pain to merge
# them.
#
describe "Puppet::Parser::Compiler when dealing with relative naming" do
  include PuppetSpec::Compiler
  include Matchers::Resource

  describe "the compiler when using 4.x parser and evaluator" do
    it "should use absolute references even if references are not anchored" do
      node = Puppet::Node.new("testnodex")
      catalog = compile_to_catalog(<<-PP, node)
      class foo::thing {
        notify {"from foo::thing":}
      }

      class thing {
        notify {"from ::thing":}
      }

      class foo {
      #  include thing
        class {'thing':}
      }

      include foo
      PP

      catalog = Puppet::Parser::Compiler.compile(node)

      expect(catalog).to have_resource("Notify[from ::thing]")
    end

    it "should use absolute references when references are absolute" do
      node = Puppet::Node.new("testnodex")
      catalog = compile_to_catalog(<<-PP, node)
      class foo::thing {
        notify {"from foo::thing":}
      }

      class thing {
        notify {"from ::thing":}
      }

      class foo {
      #  include thing
        class {'::thing':}
      }

      include foo
      PP

      catalog = Puppet::Parser::Compiler.compile(node)

      expect(catalog).to have_resource("Notify[from ::thing]")
    end
  end
end
