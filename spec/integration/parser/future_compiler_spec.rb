require 'spec_helper'
require 'puppet/pops'
require 'puppet/parser/parser_factory'
require 'puppet_spec/compiler'
require 'puppet_spec/pops'
require 'puppet_spec/scope'
require 'matchers/resource'
require 'rgen/metamodel_builder'

# Test compilation using the future evaluator
describe "Puppet::Parser::Compiler" do
  include PuppetSpec::Compiler
  include Matchers::Resource

  before :each do
    Puppet[:parser] = 'future'
  end

  describe "the compiler when using future parser and evaluator" do
    it "should be able to determine the configuration version from a local version control repository" do
      pending("Bug #14071 about semantics of Puppet::Util::Execute on Windows", :if => Puppet.features.microsoft_windows?) do
        # This should always work, because we should always be
        # in the puppet repo when we run this.
        version = %x{git rev-parse HEAD}.chomp

        Puppet.settings[:config_version] = 'git rev-parse HEAD'

        compiler = Puppet::Parser::Compiler.new(Puppet::Node.new("testnode"))
        compiler.catalog.version.should == version
      end
    end

    it "should not create duplicate resources when a class is referenced both directly and indirectly by the node classifier (4792)" do
      node = Puppet::Node.new("testnodex")
      node.classes = ['foo', 'bar']
      catalog = compile_to_catalog(<<-PP, node)
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

      catalog = Puppet::Parser::Compiler.compile(node)

      expect(catalog).to have_resource("Notify[foo_notify]")
      expect(catalog).to have_resource("Notify[bar_notify]")
    end

    it 'applies defaults for defines with qualified names (PUP-2302)' do
      catalog = compile_to_catalog(<<-CODE)
        define my::thing($msg = 'foo') { notify {'check_me': message => $msg } }
        My::Thing { msg => 'evoe' }
        my::thing { 'name': }
      CODE

      expect(catalog).to have_resource("Notify[check_me]").with_parameter(:message, "evoe")
    end

    describe "when resolving class references" do
      it "should favor local scope, even if there's an included class in topscope" do
        catalog = compile_to_catalog(<<-PP)
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

        expect(catalog).to have_resource("Notify[x]").with_parameter(:require, be_resource("Class[Experiment::Baz]"))
      end

      it "should favor local scope, even if there's an unincluded class in topscope" do
        catalog = compile_to_catalog(<<-PP)
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

        expect(catalog).to have_resource("Notify[x]").with_parameter(:require, be_resource("Class[Experiment::Baz]"))
      end
    end

    describe "(ticket #13349) when explicitly specifying top scope" do
      ["class {'::bar::baz':}", "include ::bar::baz"].each do |include|
        describe "with #{include}" do
          it "should find the top level class" do
            catalog = compile_to_catalog(<<-MANIFEST)
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

            expect(catalog).to have_resource("Class[Bar::Baz]")
            expect(catalog).to have_resource("Notify[good!]")
            expect(catalog).to_not have_resource("Class[Foo::Bar::Baz]")
            expect(catalog).to_not have_resource("Notify[bad!]")
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
        expect do
          compile_to_catalog(<<-PP)
            if true {
              #{thing} foo {
              }
              notify { decoy: }
            }
          PP
        end.to raise_error(Puppet::Error, /Classes, definitions, and nodes may only appear at toplevel/)
      end

      it "'#{thing}' is not allowed inside un-evaluated conditional constructs" do
        expect do
          compile_to_catalog(<<-PP)
            if false {
              #{thing} foo {
              }
              notify { decoy: }
            }
          PP
        end.to raise_error(Puppet::Error, /Classes, definitions, and nodes may only appear at toplevel/)
      end
    end

    describe "relationships can be formed" do
      def extract_name(ref)
        ref.sub(/File\[(\w+)\]/, '\1')
      end

      def assert_creates_relationships(relationship_code, expectations)
        base_manifest = <<-MANIFEST
          file { [a,b,c]:
            mode => 0644,
          }
          file { [d,e]:
            mode => 0755,
          }
        MANIFEST
        catalog = compile_to_catalog(base_manifest + relationship_code)

        resources = catalog.resources.select { |res| res.type == 'File' }

        actual_relationships, actual_subscriptions = [:before, :notify].map do |relation|
          resources.map do |res|
            dependents = Array(res[relation])
            dependents.map { |ref| [res.title, extract_name(ref)] }
          end.inject(&:concat)
        end

        actual_relationships.should =~ (expectations[:relationships] || [])
        actual_subscriptions.should =~ (expectations[:subscriptions] || [])
      end

      it "of regular type" do
        assert_creates_relationships("File[a] -> File[b]",
                                     :relationships => [['a','b']])
      end

      it "of subscription type" do
        assert_creates_relationships("File[a] ~> File[b]",
                                     :subscriptions => [['a', 'b']])
      end

      it "between multiple resources expressed as resource with multiple titles" do
        assert_creates_relationships("File[a,b] -> File[c,d]",
                                     :relationships => [['a', 'c'],
                                                        ['b', 'c'],
                                                        ['a', 'd'],
                                                        ['b', 'd']])
      end

      it "between collection expressions" do
        assert_creates_relationships("File <| mode == 0644 |> -> File <| mode == 0755 |>",
                                     :relationships => [['a', 'd'],
                                                        ['b', 'd'],
                                                        ['c', 'd'],
                                                        ['a', 'e'],
                                                        ['b', 'e'],
                                                        ['c', 'e']])
      end

      it "between resources expressed as Strings" do
        assert_creates_relationships("'File[a]' -> 'File[b]'",
                                     :relationships => [['a', 'b']])
      end

      it "between resources expressed as variables" do
        assert_creates_relationships(<<-MANIFEST, :relationships => [['a', 'b']])
          $var = File[a]
          $var -> File[b]
        MANIFEST

      end

      it "between resources expressed as case statements" do
        assert_creates_relationships(<<-MANIFEST, :relationships => [['s1', 't2']])
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
      end

      it "using deep access in array" do
        assert_creates_relationships(<<-MANIFEST, :relationships => [['a', 'b']])
          $var = [ [ [ File[a], File[b] ] ] ]
          $var[0][0][0] -> $var[0][0][1]
        MANIFEST

      end

      it "using deep access in hash" do
        assert_creates_relationships(<<-MANIFEST, :relationships => [['a', 'b']])
          $var = {'foo' => {'bar' => {'source' => File[a], 'target' => File[b]}}}
          $var[foo][bar][source] -> $var[foo][bar][target]
        MANIFEST

      end

      it "using resource declarations" do
        assert_creates_relationships("file { l: } -> file { r: }", :relationships => [['l', 'r']])
      end

      it "between entries in a chain of relationships" do
        assert_creates_relationships("File[a] -> File[b] ~> File[c] <- File[d] <~ File[e]",
                                     :relationships => [['a', 'b'], ['d', 'c']],
                                     :subscriptions => [['b', 'c'], ['e', 'd']])
      end
    end

    context "when dealing with variable references" do
      it 'an initial underscore in a variable name is ok' do
        catalog = compile_to_catalog(<<-MANIFEST)
          class a { $_a = 10}
          include a
          notify { 'test': message => $a::_a }
        MANIFEST

        expect(catalog).to have_resource("Notify[test]").with_parameter(:message, 10)
      end

      it 'an initial underscore in not ok if elsewhere than last segment' do
        expect do
          catalog = compile_to_catalog(<<-MANIFEST)
            class a { $_a = 10}
            include a
            notify { 'test': message => $_a::_a }
          MANIFEST
        end.to raise_error(/Illegal variable name/)
      end

      it 'a missing variable as default value becomes undef' do
        catalog = compile_to_catalog(<<-MANIFEST)
          class a ($b=$x) { notify {$b: message=>'meh'} }
          include a
        MANIFEST

        expect(catalog).to have_resource("Notify[undef]").with_parameter(:message, "meh")
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

          expect(catalog).to have_resource("Notify[test]").with_parameter(:message, "value")
        end

        it 'should not allow assignment to $trusted' do
          node = Puppet::Node.new("testing")
          node.trusted_data = { "data" => "value" }

          expect do
            compile_to_catalog(<<-MANIFEST, node)
              $trusted = 'changed'
              notify { 'test': message => $trusted == 'changed' }
            MANIFEST
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

          expect(catalog).to have_resource("Notify[test]").with_parameter(:message, true)
        end

        it 'should allow assignment to $trusted' do
          catalog = compile_to_catalog(<<-MANIFEST)
            $trusted = 'changed'
            notify { 'test': message => $trusted == 'changed' }
          MANIFEST

          expect(catalog).to have_resource("Notify[test]").with_parameter(:message, true)
        end
      end
    end
  end
end
