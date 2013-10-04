#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/parser/parser_factory'

describe "Puppet::Parser::Compiler" do
  before :each do
    @node = Puppet::Node.new "testnode"

    @scope_resource = stub 'scope_resource', :builtin? => true, :finish => nil, :ref => 'Class[main]'
    @scope = stub 'scope', :resource => @scope_resource, :source => mock("source")
  end

  after do
    Puppet.settings.clear
  end

  # shared because tests are invoked both for classic and future parser
  #
  shared_examples_for "the compiler" do
    it "should be able to determine the configuration version from a local version control repository" do
      pending("Bug #14071 about semantics of Puppet::Util::Execute on Windows", :if => Puppet.features.microsoft_windows?) do
        # This should always work, because we should always be
        # in the puppet repo when we run this.
        version = %x{git rev-parse HEAD}.chomp

        Puppet.settings[:config_version] = 'git rev-parse HEAD'

        @parser = Puppet::Parser::ParserFactory.parser "development"
        @compiler = Puppet::Parser::Compiler.new(@node)

        @compiler.catalog.version.should == version
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

      @node.stubs(:classes).returns(['foo', 'bar'])

      catalog = Puppet::Parser::Compiler.compile(@node)

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

    ['class', 'define', 'node'].each do |thing|
      it "should not allow #{thing} inside evaluated conditional constructs" do
        Puppet[:code] = <<-PP
          if true {
            #{thing} foo {
            }
            notify { decoy: }
          }
        PP

        begin
          Puppet::Parser::Compiler.compile(Puppet::Node.new("mynode"))
          raise "compilation should have raised Puppet::Error"
        rescue Puppet::Error => e
          e.message.should =~ /at line 2/
        end
      end
    end

    it "should not allow classes inside unevaluated conditional constructs" do
      Puppet[:code] = <<-PP
        if false {
          class foo {
          }
        }
      PP

      lambda { Puppet::Parser::Compiler.compile(Puppet::Node.new("mynode")) }.should raise_error(Puppet::Error)
    end

    describe "when defining relationships" do
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

      it "should create a relationship" do
        code << "File[a] -> File[b]"

        expected_relationships << ['a','b']
      end

      it "should create a subscription" do
        code << "File[a] ~> File[b]"

        expected_subscriptions << ['a', 'b']
      end

      it "should create relationships using title arrays" do
        code << "File[a,b] -> File[c,d]"

        expected_relationships.concat [
          ['a', 'c'],
          ['b', 'c'],
          ['a', 'd'],
          ['b', 'd'],
        ]
      end

      it "should create relationships using collection expressions" do
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

      it "should create relationships using resource names" do
        code << "'File[a]' -> 'File[b]'"

        expected_relationships << ['a', 'b']
      end

      it "should create relationships using variables" do
        code << <<-MANIFEST
          $var = File[a]
          $var -> File[b]
        MANIFEST

        expected_relationships << ['a', 'b']
      end

      it "should create relationships using case statements" do
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

      it "should create relationships using array members" do
        code << <<-MANIFEST
          $var = [ [ [ File[a], File[b] ] ] ]
          $var[0][0][0] -> $var[0][0][1]
        MANIFEST

        expected_relationships << ['a', 'b']
      end

      it "should create relationships using hash members" do
        code << <<-MANIFEST
          $var = {'foo' => {'bar' => {'source' => File[a], 'target' => File[b]}}}
          $var[foo][bar][source] -> $var[foo][bar][target]
        MANIFEST

        expected_relationships << ['a', 'b']
      end

      it "should create relationships using resource declarations" do
        code << "file { l: } -> file { r: }"

        expected_relationships << ['l', 'r']
      end

      it "should chain relationships" do
        code << "File[a] -> File[b] ~> File[c] <- File[d] <~ File[e]"

        expected_relationships << ['a', 'b'] << ['d', 'c']
        expected_subscriptions << ['b', 'c'] << ['e', 'd']
      end
    end
  end

  describe 'using classic parser' do
    before :each do
      Puppet[:parser] = 'current'
    end
    it_behaves_like 'the compiler' do
    end
  end

  describe 'using future parser' do
    # have absolutely no clue to why this is needed - if not required here (even if required by used classes)
    # the tests will fail with error that rgen/ecore/ruby_to_ecore cannot be found...
    # TODO: Solve this mystery !
    require 'rgen/metamodel_builder'

    before :each do
      Puppet[:parser] = 'future'
    end
    it_behaves_like 'the compiler'
  end
end
