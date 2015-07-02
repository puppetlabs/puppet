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

    it 'Applies defaults from dynamic scopes (3x and future with reverted PUP-867)' do
      catalog = compile_to_catalog(<<-CODE)
      class a {
        Notify { message => "defaulted" }
        include b
        notify { bye: }
      }
      class b { notify { hi: } }

      include a
      CODE
      expect(catalog).to have_resource("Notify[hi]").with_parameter(:message, "defaulted")
      expect(catalog).to have_resource("Notify[bye]").with_parameter(:message, "defaulted")
    end

    it 'gets default from inherited class (PUP-867)' do
      catalog = compile_to_catalog(<<-CODE)
      class a {
        Notify { message => "defaulted" }
        include c
        notify { bye: }
      }
      class b { Notify { message => "inherited" } }
      class c inherits b { notify { hi: } }

      include a
      CODE

      expect(catalog).to have_resource("Notify[hi]").with_parameter(:message, "inherited")
      expect(catalog).to have_resource("Notify[bye]").with_parameter(:message, "defaulted")
    end

    it 'looks up default parameter values from inherited class (PUP-2532)' do
      catalog = compile_to_catalog(<<-CODE)
      class a {
        Notify { message => "defaulted" }
        include c
        notify { bye: }
      }
      class b { Notify { message => "inherited" } }
      class c inherits b { notify { hi: } }

      include a
      notify {hi_test: message => Notify[hi][message] }
      notify {bye_test: message => Notify[bye][message] }
      CODE

      expect(catalog).to have_resource("Notify[hi_test]").with_parameter(:message, "inherited")
      expect(catalog).to have_resource("Notify[bye_test]").with_parameter(:message, "defaulted")
    end

    it 'does not allow override of class parameters using a resource override expression' do
      expect do
        compile_to_catalog(<<-CODE)
          Class[a] { x => 2}
        CODE
      end.to raise_error(/Resource Override can only.*got: Class\[a\].*/)
    end

    describe "when resolving class references" do
      it "should not favor local scope (with class included in topscope)" do
        catalog = compile_to_catalog(<<-PP)
          class experiment {
            class baz {
            }
            notify {"x" : require => Class[Baz] }
            notify {"y" : require => Class[Experiment::Baz] }
          }
          class baz {
          }
          include baz
          include experiment
          include experiment::baz
        PP

        expect(catalog).to have_resource("Notify[x]").with_parameter(:require, be_resource("Class[Baz]"))
        expect(catalog).to have_resource("Notify[y]").with_parameter(:require, be_resource("Class[Experiment::Baz]"))
      end

      it "should not favor local scope, (with class not included in topscope)" do
        catalog = compile_to_catalog(<<-PP)
          class experiment {
            class baz {
            }
            notify {"x" : require => Class[Baz] }
            notify {"y" : require => Class[Experiment::Baz] }
          }
          class baz {
          }
          include experiment
          include experiment::baz
        PP

        expect(catalog).to have_resource("Notify[x]").with_parameter(:require, be_resource("Class[Baz]"))
        expect(catalog).to have_resource("Notify[y]").with_parameter(:require, be_resource("Class[Experiment::Baz]"))
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

    it 'should recompute the version after input files are re-parsed' do
      Puppet[:code] = 'class foo { }'
      first_time = Time.at(1)
      second_time = Time.at(200)
      Time.stubs(:now).returns(first_time)
      node = Puppet::Node.new('mynode')
      expect(Puppet::Parser::Compiler.compile(node).version).to eq(first_time.to_i)
      Time.stubs(:now).returns(second_time)
      expect(Puppet::Parser::Compiler.compile(node).version).to eq(first_time.to_i) # no change because files didn't change
      Puppet[:code] = nil
      expect(Puppet::Parser::Compiler.compile(node).version).to eq(second_time.to_i)
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
            mode => '0644',
          }
          file { [d,e]:
            mode => '0755',
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
        assert_creates_relationships("File <| mode == '0644' |> -> File <| mode == '0755' |>",
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
        # strict variables not on
        catalog = compile_to_catalog(<<-MANIFEST)
        class a ($b=$x) { notify {test: message=>"yes ${undef == $b}" } }
          include a
        MANIFEST

        expect(catalog).to have_resource("Notify[test]").with_parameter(:message, "yes true")
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

    context 'when using typed parameters in definition' do
      it 'accepts type compliant arguments' do
        catalog = compile_to_catalog(<<-MANIFEST)
          define foo(String $x) { }
          foo { 'test': x =>'say friend' }
        MANIFEST
        expect(catalog).to have_resource("Foo[test]").with_parameter(:x, 'say friend')
      end

      it 'accepts undef as the default for an Optional argument' do
        catalog = compile_to_catalog(<<-MANIFEST)
          define foo(Optional[String] $x = undef) {
            notify { "expected": message => $x == undef }
          }
          foo { 'test': }
        MANIFEST
        expect(catalog).to have_resource("Notify[expected]").with_parameter(:message, true)
      end

      it 'accepts anything when parameters are untyped' do
        expect do
          catalog = compile_to_catalog(<<-MANIFEST)
          define foo($a, $b, $c) { }
          foo { 'test': a => String, b=>10, c=>undef }
        MANIFEST
        end.to_not raise_error()
      end

      it 'denies non type compliant arguments' do
        expect do
          catalog = compile_to_catalog(<<-MANIFEST)
            define foo(Integer $x) { }
            foo { 'test': x =>'say friend' }
          MANIFEST
        end.to raise_error(/type Integer, got String/)
      end

      it 'denies undef for a non-optional type' do
        expect do
          catalog = compile_to_catalog(<<-MANIFEST)
            define foo(Integer $x) { }
            foo { 'test': x => undef }
          MANIFEST
        end.to raise_error(/type Integer, got Undef/)
      end

      it 'denies non type compliant default argument' do
        expect do
          catalog = compile_to_catalog(<<-MANIFEST)
            define foo(Integer $x = 'pow') { }
            foo { 'test':  }
          MANIFEST
        end.to raise_error(/type Integer, got String/)
      end

      it 'denies undef as the default for a non-optional type' do
        expect do
          catalog = compile_to_catalog(<<-MANIFEST)
            define foo(Integer $x = undef) { }
            foo { 'test':  }
          MANIFEST
        end.to raise_error(/type Integer, got Undef/)
      end

      it 'accepts a Resource as a Type' do
        catalog = compile_to_catalog(<<-MANIFEST)
          define foo(Type[Bar] $x) {
            notify { 'test': message => $x[text] }
          }
          define bar($text) { }
          bar { 'joke': text => 'knock knock' }
          foo { 'test': x => Bar[joke] }
        MANIFEST
        expect(catalog).to have_resource("Notify[test]").with_parameter(:message, 'knock knock')
      end

      it 'uses infer_set when reporting type mismatch' do
        expect do
          catalog = compile_to_catalog(<<-MANIFEST)
            define foo(Struct[{b => Integer, d=>String}] $a) { }
            foo{ bar: a => {b => 5, c => 'stuff'}}
          MANIFEST
        end.to raise_error(/got Struct\[\{'b'=>Integer, 'c'=>String\}\]/)
      end
    end

    context 'when using typed parameters in class' do
      it 'accepts type compliant arguments' do
        catalog = compile_to_catalog(<<-MANIFEST)
          class foo(String $x) { }
          class { 'foo': x =>'say friend' }
        MANIFEST
        expect(catalog).to have_resource("Class[Foo]").with_parameter(:x, 'say friend')
      end

      it 'accepts undef as the default for an Optional argument' do
        catalog = compile_to_catalog(<<-MANIFEST)
          class foo(Optional[String] $x = undef) {
            notify { "expected": message => $x == undef }
          }
          class { 'foo': }
        MANIFEST
        expect(catalog).to have_resource("Notify[expected]").with_parameter(:message, true)
      end

      it 'accepts anything when parameters are untyped' do
        expect do
          catalog = compile_to_catalog(<<-MANIFEST)
            class foo($a, $b, $c) { }
            class { 'foo': a => String, b=>10, c=>undef }
          MANIFEST
        end.to_not raise_error()
      end

      it 'denies non type compliant arguments' do
        expect do
          catalog = compile_to_catalog(<<-MANIFEST)
            class foo(Integer $x) { }
            class { 'foo': x =>'say friend' }
          MANIFEST
        end.to raise_error(/type Integer, got String/)
      end

      it 'denies undef for a non-optional type' do
        expect do
          catalog = compile_to_catalog(<<-MANIFEST)
            class foo(Integer $x) { }
            class { 'foo': x => undef }
          MANIFEST
        end.to raise_error(/type Integer, got Undef/)
      end

      it 'denies non type compliant default argument' do
        expect do
          catalog = compile_to_catalog(<<-MANIFEST)
            class foo(Integer $x = 'pow') { }
            class { 'foo':  }
          MANIFEST
        end.to raise_error(/type Integer, got String/)
      end

      it 'denies undef as the default for a non-optional type' do
        expect do
          catalog = compile_to_catalog(<<-MANIFEST)
            class foo(Integer $x = undef) { }
            class { 'foo':  }
          MANIFEST
        end.to raise_error(/type Integer, got Undef/)
      end

      it 'accepts a Resource as a Type' do
        catalog = compile_to_catalog(<<-MANIFEST)
          class foo(Type[Bar] $x) {
            notify { 'test': message => $x[text] }
          }
          define bar($text) { }
          bar { 'joke': text => 'knock knock' }
          class { 'foo': x => Bar[joke] }
        MANIFEST
        expect(catalog).to have_resource("Notify[test]").with_parameter(:message, 'knock knock')
      end
    end

    context 'when using typed parameters in lambdas' do
      it 'accepts type compliant arguments' do
        catalog = compile_to_catalog(<<-MANIFEST)
          with('value') |String $x| { notify { "$x": } }
        MANIFEST
        expect(catalog).to have_resource("Notify[value]")
      end

      it 'handles an array as a single argument' do
        catalog = compile_to_catalog(<<-MANIFEST)
          with(['value', 'second']) |$x| { notify { "${x[0]} ${x[1]}": } }
        MANIFEST
        expect(catalog).to have_resource("Notify[value second]")
      end

      # Conditinoally left out for Ruby 1.8.x since the Proc created for the expected number of arguments will accept
      # a call with fewer arguments and then pass all arguments to the closure. The closure then receives an argument
      # array of correct size with nil values instead of an array with too few arguments
      unless RUBY_VERSION[0,3] == '1.8'
        it 'denies when missing required arguments' do
          expect do
            compile_to_catalog(<<-MANIFEST)
              with(1) |$x, $y| { }
            MANIFEST
          end.to raise_error(/Parameter \$y is required but no value was given/m)
        end
      end

      it 'accepts anything when parameters are untyped' do
        catalog = compile_to_catalog(<<-MANIFEST)
          ['value', 1, true, undef].each |$x| { notify { "value: $x": } }
        MANIFEST

        expect(catalog).to have_resource("Notify[value: value]")
        expect(catalog).to have_resource("Notify[value: 1]")
        expect(catalog).to have_resource("Notify[value: true]")
        expect(catalog).to have_resource("Notify[value: ]")
      end

      it 'accepts type-compliant, slurped arguments' do
        catalog = compile_to_catalog(<<-MANIFEST)
          with(1, 2) |Integer *$x| { notify { "${$x[0] + $x[1]}": } }
        MANIFEST
        expect(catalog).to have_resource("Notify[3]")
      end

      it 'denies non-type-compliant arguments' do
        expect do
          compile_to_catalog(<<-MANIFEST)
            with(1) |String $x| { }
          MANIFEST
        end.to raise_error(/expected.*String.*actual.*Integer/m)
      end

      it 'denies non-type-compliant, slurped arguments' do
        expect do
          compile_to_catalog(<<-MANIFEST)
            with(1, "hello") |Integer *$x| { }
          MANIFEST
        end.to raise_error(/called with mis-matched arguments.*expected.*Integer.*actual.*Integer, String/m)
      end

      it 'denies non-type-compliant default argument' do
        expect do
          compile_to_catalog(<<-MANIFEST)
            with(1) |$x, String $defaulted = 1| { notify { "${$x + $defaulted}": }}
          MANIFEST
        end.to raise_error(/expected.*Any.*String.*actual.*Integer.*Integer/m)
      end

      it 'raises an error when a default argument value is an incorrect type and there are no arguments passed' do
        expect do
          compile_to_catalog(<<-MANIFEST)
            with() |String $defaulted = 1| {}
          MANIFEST
        end.to raise_error(/expected.*String.*actual.*Integer/m)
      end

      it 'raises an error when the default argument for a slurped parameter is an incorrect type' do
        expect do
          compile_to_catalog(<<-MANIFEST)
            with() |String *$defaulted = 1| {}
          MANIFEST
        end.to raise_error(/expected.*String.*actual.*Integer/m)
      end

      it 'allows using an array as the default slurped value' do
        catalog = compile_to_catalog(<<-MANIFEST)
          with() |String *$defaulted = [hi]| { notify { $defaulted[0]: } }
        MANIFEST

        expect(catalog).to have_resource('Notify[hi]')
      end

      it 'allows using a value of the type as the default slurped value' do
        catalog = compile_to_catalog(<<-MANIFEST)
          with() |String *$defaulted = hi| { notify { $defaulted[0]: } }
        MANIFEST

        expect(catalog).to have_resource('Notify[hi]')
      end

      it 'allows specifying the type of a slurped parameter as an array' do
        catalog = compile_to_catalog(<<-MANIFEST)
          with() |Array[String] *$defaulted = hi| { notify { $defaulted[0]: } }
        MANIFEST

        expect(catalog).to have_resource('Notify[hi]')
      end

      it 'raises an error when the number of default values does not match the parameter\'s size specification' do
        expect do
          compile_to_catalog(<<-MANIFEST)
            with() |Array[String, 2] *$defaulted = hi| { }
          MANIFEST
        end.to raise_error(/expected.*arg count \{2,\}.*actual.*arg count \{1\}/m)
      end

      it 'raises an error when the number of passed values does not match the parameter\'s size specification' do
        expect do
          compile_to_catalog(<<-MANIFEST)
            with(hi) |Array[String, 2] *$passed| { }
          MANIFEST
        end.to raise_error(/expected.*arg count \{2,\}.*actual.*arg count \{1\}/m)
      end

      it 'matches when the number of arguments passed for a slurp parameter match the size specification' do
        catalog = compile_to_catalog(<<-MANIFEST)
          with(hi, bye) |Array[String, 2] *$passed| {
            $passed.each |$n| { notify { $n: } }
          }
        MANIFEST

        expect(catalog).to have_resource('Notify[hi]')
        expect(catalog).to have_resource('Notify[bye]')
      end

      it 'raises an error when the number of allowed slurp parameters exceeds the size constraint' do
        expect do
          compile_to_catalog(<<-MANIFEST)
            with(hi, bye) |Array[String, 1, 1] *$passed| { }
          MANIFEST
        end.to raise_error(/expected.*arg count \{1\}.*actual.*arg count \{2\}/m)
      end

      it 'allows passing slurped arrays by specifying an array of arrays' do
        catalog = compile_to_catalog(<<-MANIFEST)
          with([hi], [bye]) |Array[Array[String, 1, 1]] *$passed| {
            notify { $passed[0][0]: }
            notify { $passed[1][0]: }
          }
        MANIFEST

        expect(catalog).to have_resource('Notify[hi]')
        expect(catalog).to have_resource('Notify[bye]')
      end

      it 'raises an error when a required argument follows an optional one' do
        expect do
          compile_to_catalog(<<-MANIFEST)
            with() |$y = first, $x, Array[String, 1] *$passed = bye| {}
          MANIFEST
        end.to raise_error(/Parameter \$x is required/)
      end

      it 'raises an error when the minimum size of a slurped argument makes it required and it follows an optional argument' do
        expect do
          compile_to_catalog(<<-MANIFEST)
            with() |$x = first, Array[String, 1] *$passed| {}
          MANIFEST
        end.to raise_error(/Parameter \$passed is required/)
      end

      it 'allows slurped arguments with a minimum size of 0 after an optional argument' do
        catalog = compile_to_catalog(<<-MANIFEST)
          with() |$x = first, Array[String, 0] *$passed| {
            notify { $x: }
          }
        MANIFEST

        expect(catalog).to have_resource('Notify[first]')
      end

      it 'accepts a Resource as a Type' do
        catalog = compile_to_catalog(<<-MANIFEST)
          define bar($text) { }
          bar { 'joke': text => 'knock knock' }

          with(Bar[joke]) |Type[Bar] $joke| { notify { "${joke[text]}": } }
        MANIFEST
        expect(catalog).to have_resource("Notify[knock knock]")
      end
    end
  end

  context 'when evaluating collection' do
    it 'matches on container inherited tags' do
      Puppet[:code] = <<-MANIFEST
      class xport_test {
        tag('foo_bar')
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

end
