#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/parser/parser_factory'
require 'puppet_spec/compiler'
require 'matchers/resource'

describe "Puppet::Parser::Compiler" do
  include PuppetSpec::Compiler
  include Matchers::Resource

  before :each do
    @node = Puppet::Node.new "testnode"

    @scope_resource = stub 'scope_resource', :builtin? => true, :finish => nil, :ref => 'Class[main]'
    @scope = stub 'scope', :resource => @scope_resource, :source => mock("source")
  end

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
    it "should not allow '#{thing}' inside evaluated conditional constructs" do
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
          mode => '0644',
        }
        file { [d,e]:
          mode => '0755',
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

  context 'when working with immutable node data' do
    context 'and have opted in to immutable_node_data' do
      before :each do
        Puppet[:immutable_node_data] = true
      end

      def node_with_facts(facts)
        Puppet[:facts_terminus] = :memory
        Puppet::Node::Facts.indirection.save(Puppet::Node::Facts.new("testing", facts))
        node = Puppet::Node.new("testing")
        node.fact_merge
        node
      end

      matcher :fail_compile_with do |node, message_regex|
        match do |manifest|
          @error = nil
          begin
            PuppetSpec::Compiler.compile_to_catalog(manifest, node)
            false
          rescue Puppet::Error => e
            @error = e
            message_regex.match(e.message)
          end
        end

        failure_message_for_should do
          if @error
            "failed with #{@error}\n#{@error.backtrace}"
          else
            "did not fail"
          end
        end
      end

      it 'should make $facts available' do
        node = node_with_facts('the_facts' => 'straight')

        catalog = compile_to_catalog(<<-MANIFEST, node)
         notify { 'test': message => $facts[the_facts] }
        MANIFEST

        catalog.resource("Notify[test]")[:message].should == "straight"
      end

      it 'should make $facts reserved' do
        node = node_with_facts('the_facts' => 'straight')

        expect('$facts = {}').to fail_compile_with(node, /assign to a reserved variable name: 'facts'/)
        expect('class a { $facts = {} } include a').to fail_compile_with(node, /assign to a reserved variable name: 'facts'/)
      end

      it 'should make $facts immutable' do
        node = node_with_facts('string' => 'value', 'array' => ['string'], 'hash' => { 'a' => 'string' }, 'number' => 1, 'boolean' => true)

        expect('$i=inline_template("<% @facts[%q{new}] = 2 %>")').to fail_compile_with(node, /frozen Hash/i)
        expect('$i=inline_template("<% @facts[%q{string}].chop! %>")').to fail_compile_with(node, /frozen String/i)

        expect('$i=inline_template("<% @facts[%q{array}][0].chop! %>")').to fail_compile_with(node, /frozen String/i)
        expect('$i=inline_template("<% @facts[%q{array}][1] = 2 %>")').to fail_compile_with(node, /frozen Array/i)

        expect('$i=inline_template("<% @facts[%q{hash}][%q{a}].chop! %>")').to fail_compile_with(node, /frozen String/i)
        expect('$i=inline_template("<% @facts[%q{hash}][%q{b}] = 2 %>")').to fail_compile_with(node, /frozen Hash/i)
      end

      it 'should make $facts available even if there are no facts' do
        Puppet[:facts_terminus] = :memory
        node = Puppet::Node.new("testing2")
        node.fact_merge

        catalog = compile_to_catalog(<<-MANIFEST, node)
          notify { 'test': message => $facts }
        MANIFEST

        expect(catalog).to have_resource("Notify[test]").with_parameter(:message, {})
      end
    end

    context 'and have not opted in to immutable_node_data' do
      before :each do
        Puppet[:immutable_node_data] = false
      end

      it 'should not make $facts available' do
       Puppet[:facts_terminus] = :memory
       facts = Puppet::Node::Facts.new("testing", 'the_facts' => 'straight')
       Puppet::Node::Facts.indirection.save(facts)
       node = Puppet::Node.new("testing")
       node.fact_merge

        catalog = compile_to_catalog(<<-MANIFEST, node)
          notify { 'test': message => "An $facts space" }
        MANIFEST

        catalog.resource("Notify[test]")[:message].should == "An  space"
      end
    end
  end

  context 'when working with the trusted data hash' do
    context 'and have opted in to trusted_node_data' do
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

      it 'should not allow addition to $trusted hash' do
        node = Puppet::Node.new("testing")
        node.trusted_data = { "data" => "value" }

        expect do
          catalog = compile_to_catalog(<<-MANIFEST, node)
            $trusted['extra'] = 'added'
            notify { 'test': message => $trusted['extra'] == 'added' }
          MANIFEST
          catalog.resource("Notify[test]")[:message].should == true
          # different errors depending on regular or future parser
        end.to raise_error(Puppet::Error, /(can't modify frozen [hH]ash)|(Illegal attempt to assign)/)
      end

      it 'should not allow addition to $trusted hash via Ruby inline template' do
        node = Puppet::Node.new("testing")
        node.trusted_data = { "data" => "value" }

        expect do
          catalog = compile_to_catalog(<<-MANIFEST, node)
          $dummy = inline_template("<% @trusted['extra'] = 'added' %> lol")
            notify { 'test': message => $trusted['extra'] == 'added' }
          MANIFEST
          catalog.resource("Notify[test]")[:message].should == true
        end.to raise_error(Puppet::Error, /can't modify frozen [hH]ash/)
      end
    end

    context 'and have not opted in to trusted_node_data' do
      before :each do
        Puppet[:trusted_node_data] = false
      end

      it 'should not make $trusted available' do
        node = Puppet::Node.new("testing")
        node.trusted_data = { "data" => "value" }

        catalog = compile_to_catalog(<<-MANIFEST, node)
          notify { 'test': message => $trusted == undef }
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

  context 'when evaluating collection' do
    it 'matches on container inherited tags' do
      Puppet[:code] = <<-MANIFEST
      class xport_test {
        tag 'foo_bar'
        @notify { 'nbr1':
          message => 'explicitly tagged',
          tag => 'foo_bar'
        }

        @notify { 'nbr2':
          message => 'implicitly tagged'
        }

        Notify <| tag == 'foo_bar' |> {
          message => 'overridden'
        }
      }
      include xport_test
      MANIFEST

      catalog = Puppet::Parser::Compiler.compile(Puppet::Node.new("mynode"))

      expect(catalog).to have_resource("Notify[nbr1]").with_parameter(:message, 'overridden')
      expect(catalog).to have_resource("Notify[nbr2]").with_parameter(:message, 'overridden')
    end
  end


  context "when converting catalog to resource" do
    it "the same environment is used for compilation as for transformation to resource form" do
        Puppet[:code] = <<-MANIFEST
          notify { 'dummy':
          }
        MANIFEST

      Puppet::Parser::Resource::Catalog.any_instance.expects(:to_resource).with do |catalog|
        Puppet.lookup(:current_environment).name == :production
      end

      Puppet::Parser::Compiler.compile(Puppet::Node.new("mynode"))
    end
  end
end
