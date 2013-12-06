#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'
require 'puppet/parser/parser_factory'
require 'puppet_spec/compiler'
require 'puppet_spec/pops'
require 'puppet_spec/scope'
require 'rgen/metamodel_builder'

# Test compilation using the future evaluator
#
describe "Puppet::Parser::Compiler" do
  include PuppetSpec::Compiler

  before :each do
    Puppet[:parser] = 'future'

    # This is in the original test - what is this for? Does not seem to make a difference at all
    @scope_resource = stub 'scope_resource', :builtin? => true, :finish => nil, :ref => 'Class[main]'
    @scope = stub 'scope', :resource => @scope_resource, :source => mock("source")
  end


  after do
    Puppet.settings.clear
  end

  describe "the compiler when using future parser and evaluator" do
    it "should be able to determine the configuration version from a local version control repository" do
      pending("Bug #14071 about semantics of Puppet::Util::Execute on Windows", :if => Puppet.features.microsoft_windows?) do
        # This should always work, because we should always be
        # in the puppet repo when we run this.
        version = %x{git rev-parse HEAD}.chomp

        Puppet.settings[:config_version] = 'git rev-parse HEAD'

        parser = Puppet::Parser::ParserFactory.parser "development"
        compiler = Puppet::Parser::Compiler.new(Puppet::Node.new("testnode"))
        compiler.catalog.version.should == version
      end
    end

    it "should not create duplicate resources when a class is referenced both directly and indirectly by the node classifier (4792)" do
      Puppet[:code] = <<-PP
        class foo
        {
          notify { foo_notify: }
          include bar
        }
        class bar
        {
          notify { bar_notify: }
        }
      PP

      node = Puppet::Node.new("testnodex")
      node.classes = ['foo', 'bar']
      catalog = Puppet::Parser::Compiler.compile(node)
      node.classes = nil
      catalog.resource("Notify[foo_notify]").should_not be_nil
      catalog.resource("Notify[bar_notify]").should_not be_nil
    end

    describe "when resolving class references" do
      it "should favor local scope, even if there's an included class in topscope" do
        Puppet[:code] = <<-PP
          class experiment {
            class baz {
            }
            notify {"x" : require => Class[Baz] }
          }
          class baz {
          }
          include baz
          include experiment
          include experiment::baz
        PP

        catalog = Puppet::Parser::Compiler.compile(Puppet::Node.new("mynode"))

        notify_resource = catalog.resource( "Notify[x]" )

        notify_resource[:require].title.should == "Experiment::Baz"
      end

      it "should favor local scope, even if there's an unincluded class in topscope" do
        Puppet[:code] = <<-PP
          class experiment {
            class baz {
            }
            notify {"x" : require => Class[Baz] }
          }
          class baz {
          }
          include experiment
          include experiment::baz
        PP

        catalog = Puppet::Parser::Compiler.compile(Puppet::Node.new("mynode"))

        notify_resource = catalog.resource( "Notify[x]" )

        notify_resource[:require].title.should == "Experiment::Baz"
      end
    end
    describe "(ticket #13349) when explicitly specifying top scope" do
      ["class {'::bar::baz':}", "include ::bar::baz"].each do |include|
        describe "with #{include}" do
          it "should find the top level class" do
            Puppet[:code] = <<-MANIFEST
              class { 'foo::test': }
              class foo::test {
              	#{include}
              }
              class bar::baz {
              	notify { 'good!': }
              }
              class foo::bar::baz {
              	notify { 'bad!': }
              }
            MANIFEST

            catalog = Puppet::Parser::Compiler.compile(Puppet::Node.new("mynode"))

            catalog.resource("Class[Bar::Baz]").should_not be_nil
            catalog.resource("Notify[good!]").should_not be_nil
            catalog.resource("Class[Foo::Bar::Baz]").should be_nil
            catalog.resource("Notify[bad!]").should be_nil
          end
        end
      end
    end

    it "should recompute the version after input files are re-parsed" do
      Puppet[:code] = 'class foo { }'
      Time.stubs(:now).returns(1)
      node = Puppet::Node.new('mynode')
      Puppet::Parser::Compiler.compile(node).version.should == 1
      Time.stubs(:now).returns(2)
      Puppet::Parser::Compiler.compile(node).version.should == 1 # no change because files didn't change
      Puppet::Resource::TypeCollection.any_instance.stubs(:stale?).returns(true).then.returns(false) # pretend change
      Puppet::Parser::Compiler.compile(node).version.should == 2
    end

    ['define', 'class', 'node'].each do |thing|
      it "'#{thing}' is not allowed inside evaluated conditional constructs" do
        Puppet[:code] = <<-PP
          if true {
            #{thing} foo {
            }
            notify { decoy: }
          }
        PP

        begin
          catalog = Puppet::Parser::Compiler.compile(Puppet::Node.new("mynode"))
          raise "compilation should have raised Puppet::Error"
        rescue Puppet::Error => e
          e.message.should =~ /Classes, definitions, and nodes may only appear at toplevel/
        end
      end
    end

    ['define', 'class', 'node'].each do |thing|
      it "'#{thing}' is not allowed inside un-evaluated conditional constructs" do
        Puppet[:code] = <<-PP
          if false {
            #{thing} foo {
            }
            notify { decoy: }
          }
        PP

        begin
          catalog = Puppet::Parser::Compiler.compile(Puppet::Node.new("mynode"))
          raise "compilation should have raised Puppet::Error"
        rescue Puppet::Error => e
          e.message.should =~ /Classes, definitions, and nodes may only appear at toplevel/
        end
      end
    end

    describe "relationships can be formed" do
      def extract_name(ref)
        ref.sub(/File\[(\w+)\]/, '\1')
      end

      let(:node) { Puppet::Node.new('mynode') }
      let(:code) do
        <<-MANIFEST
          file { [a,b,c]:
            mode => 0644,
          }
          file { [d,e]:
            mode => 0755,
          }
        MANIFEST
      end
      let(:expected_relationships) { [] }
      let(:expected_subscriptions) { [] }

      before :each do
        Puppet[:parser] = 'future'
        Puppet[:code] = code
      end

      after :each do
        catalog = Puppet::Parser::Compiler.compile(node)

        resources = catalog.resources.select { |res| res.type == 'File' }

        actual_relationships, actual_subscriptions = [:before, :notify].map do |relation|
          resources.map do |res|
            dependents = Array(res[relation])
            dependents.map { |ref| [res.title, extract_name(ref)] }
          end.inject(&:concat)
        end

        actual_relationships.should =~ expected_relationships
        actual_subscriptions.should =~ expected_subscriptions
      end

      it "of regular type" do
        code << "File[a] -> File[b]"

        expected_relationships << ['a','b']
      end

      it "of subscription type" do
        code << "File[a] ~> File[b]"

        expected_subscriptions << ['a', 'b']
      end

      it "between multiple resources expressed as resource with multiple titles" do
        code << "File[a,b] -> File[c,d]"

        expected_relationships.concat [
          ['a', 'c'],
          ['b', 'c'],
          ['a', 'd'],
          ['b', 'd'],
        ]
      end

      it "between collection expressions" do
        code << "File <| mode == 0644 |> -> File <| mode == 0755 |>"

        expected_relationships.concat [
          ['a', 'd'],
          ['b', 'd'],
          ['c', 'd'],
          ['a', 'e'],
          ['b', 'e'],
          ['c', 'e'],
        ]
      end

      it "between resources expressed as Strings" do
        code << "'File[a]' -> 'File[b]'"

        expected_relationships << ['a', 'b']
      end

      it "between resources expressed as variables" do
        code << <<-MANIFEST
          $var = File[a]
          $var -> File[b]
        MANIFEST

        expected_relationships << ['a', 'b']
      end

      it "between resources expressed as case statements" do
        code << <<-MANIFEST
          $var = 10
          case $var {
            10: {
              file { s1: }
            }
            12: {
              file { s2: }
            }
          }
          ->
          case $var + 2 {
            10: {
              file { t1: }
            }
            12: {
              file { t2: }
            }
          }
        MANIFEST

        expected_relationships << ['s1', 't2']
      end

      it "using deep access in array" do
        code << <<-MANIFEST
          $var = [ [ [ File[a], File[b] ] ] ]
          $var[0][0][0] -> $var[0][0][1]
        MANIFEST

        expected_relationships << ['a', 'b']
      end

      it "using deep access in hash" do
        code << <<-MANIFEST
          $var = {'foo' => {'bar' => {'source' => File[a], 'target' => File[b]}}}
          $var[foo][bar][source] -> $var[foo][bar][target]
        MANIFEST

        expected_relationships << ['a', 'b']
      end

      it "using resource declarations" do
        code << "file { l: } -> file { r: }"

        expected_relationships << ['l', 'r']
      end

      it "between entries in a chain of relationships" do
        code << "File[a] -> File[b] ~> File[c] <- File[d] <~ File[e]"

        expected_relationships << ['a', 'b'] << ['d', 'c']
        expected_subscriptions << ['b', 'c'] << ['e', 'd']
      end
    end

    context 'when working with the trusted data hash' do
      context 'and have opted in to hashed_node_data' do
        before :each do
          Puppet[:trusted_node_data] = true
        end

        it 'should make $trusted available' do
          node = Puppet::Node.new("testing")
          node.trusted_data = { "data" => "value" }

          catalog = compile_to_catalog(<<-MANIFEST, node)
            notify { 'test': message => $trusted[data] }
          MANIFEST

          catalog.resource("Notify[test]")[:message].should == "value"
        end

        it 'should not allow assignment to $trusted' do
          node = Puppet::Node.new("testing")
          node.trusted_data = { "data" => "value" }

          expect do
            catalog = compile_to_catalog(<<-MANIFEST, node)
              $trusted = 'changed'
              notify { 'test': message => $trusted == 'changed' }
            MANIFEST
            catalog.resource("Notify[test]")[:message].should == true
          end.to raise_error(Puppet::Error, /Attempt to assign to a reserved variable name: 'trusted'/)
        end
      end

      context 'and have not opted in to hashed_node_data' do
        before :each do
          Puppet[:trusted_node_data] = false
        end

        it 'should not make $trusted available' do
          node = Puppet::Node.new("testing")
          node.trusted_data = { "data" => "value" }

          catalog = compile_to_catalog(<<-MANIFEST, node)
            notify { 'test': message => ($trusted == undef) }
          MANIFEST

          catalog.resource("Notify[test]")[:message].should == true
        end

        it 'should allow assignment to $trusted' do
          node = Puppet::Node.new("testing")

          catalog = compile_to_catalog(<<-MANIFEST, node)
            $trusted = 'changed'
            notify { 'test': message => $trusted == 'changed' }
          MANIFEST

          catalog.resource("Notify[test]")[:message].should == true
        end
      end
    end
  end

end
