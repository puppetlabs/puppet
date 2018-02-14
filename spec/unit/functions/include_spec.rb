#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/compiler'
require 'puppet/parser/functions'
require 'matchers/containment_matchers'
require 'matchers/resource'
require 'matchers/include_in_order'
require 'unit/functions/shared'


describe 'The "include" function' do
  include PuppetSpec::Compiler
  include ContainmentMatchers
  include Matchers::Resource

  before(:each) do
    compiler  = Puppet::Parser::Compiler.new(Puppet::Node.new("foo"))
    @scope = Puppet::Parser::Scope.new(compiler)
  end

  it "includes a class" do
    catalog = compile_to_catalog(<<-MANIFEST)
      class included {
        notify { "included": }
      }

      include included
    MANIFEST

    expect(catalog.classes).to include("included")
  end

  it "includes a class when using a fully qualified anchored name" do
    catalog = compile_to_catalog(<<-MANIFEST)
      class included {
        notify { "included": }
      }

      include ::included
    MANIFEST

    expect(catalog.classes).to include("included")
  end

  it "includes multiple classes" do
    catalog = compile_to_catalog(<<-MANIFEST)
      class included {
        notify { "included": }
      }
      class included_too {
        notify { "included_too": }
      }

      include included, included_too
    MANIFEST

    expect(catalog.classes).to include("included")
    expect(catalog.classes).to include("included_too")
  end

  it "includes multiple classes given as an array" do
    catalog = compile_to_catalog(<<-MANIFEST)
      class included {
        notify { "included": }
      }
      class included_too {
        notify { "included_too": }
      }

      include [included, included_too]
    MANIFEST

    expect(catalog.classes).to include("included")
    expect(catalog.classes).to include("included_too")
  end

  it "flattens nested arrays" do
    catalog = compile_to_catalog(<<-MANIFEST)
      class included {
        notify { "included": }
      }
      class included_too {
        notify { "included_too": }
      }

      include [[[included], [[[included_too]]]]]
    MANIFEST

    expect(catalog.classes).to include("included")
    expect(catalog.classes).to include("included_too")
  end

  it "raises an error if class does not exist" do
    expect {
      compile_to_catalog(<<-MANIFEST)
        include the_god_in_your_religion
      MANIFEST
    }.to raise_error(Puppet::Error)
  end

    { "''"      => 'empty string', 
      'undef'   => 'undef',
      "['']"    => 'empty string',
      "[undef]" => 'undef'
    }.each_pair do |value, name_kind|
      it "raises an error if class is #{name_kind}" do
        expect {
          compile_to_catalog(<<-MANIFEST)
            include #{value}
          MANIFEST
        }.to raise_error(/Cannot use #{name_kind}/)
      end
    end

  it "does not contained the included class in the current class" do
    catalog = compile_to_catalog(<<-MANIFEST)
      class not_contained {
        notify { "not_contained": }
      }

      class container {
        include not_contained
      }

      include container
    MANIFEST

    expect(catalog).to_not contain_class("not_contained").in("container")
  end


  it 'produces an array with a single class references given a single argument' do
    catalog = compile_to_catalog(<<-MANIFEST)
      class a {
        notify { "a": }
      }

      $x = include(a)
      Array[Type[Class], 1, 1].assert_type($x)
      notify { 'feedback': message => "$x" }
    MANIFEST

    feedback = catalog.resource("Notify", "feedback")
    expect(feedback[:message]).to eql("[Class[a]]")
  end

  it 'produces an array with class references given multiple arguments' do
    catalog = compile_to_catalog(<<-MANIFEST)
      class a {
        notify { "a": }
      }

      class b {
        notify { "b": }
      }

      $x = include(a, b)
      Array[Type[Class], 2, 2].assert_type($x)
      notify { 'feedback': message => "$x" }
    MANIFEST

    feedback = catalog.resource("Notify", "feedback")
    expect(feedback[:message]).to eql("[Class[a], Class[b]]")
  end

  it 'allows the result to be used in a relationship operation' do
    catalog = compile_to_catalog(<<-MANIFEST)
      class a {
        notify { "a": }
      }

      class b {
        notify { "b": }
      }

      notify { 'c': }

      include(a, b) -> Notify[c]
    MANIFEST

    # Assert relationships are formed
    expect(catalog.resource("Class", "a")[:before][0]).to eql('Notify[c]')
    expect(catalog.resource("Class", "b")[:before][0]).to eql('Notify[c]')
  end

  it_should_behave_like 'all functions transforming relative to absolute names', :include
  it_should_behave_like 'an inclusion function, regardless of the type of class reference,', :include
  it_should_behave_like 'an inclusion function, when --tasks is on,', :include

end
