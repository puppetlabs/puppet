#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/compiler'
require 'puppet/parser/functions'
require 'matchers/containment_matchers'

describe 'The "contain" function' do
  include PuppetSpec::Compiler
  include ContainmentMatchers

  it "includes the class" do
    catalog = compile_to_catalog(<<-MANIFEST)
      class contained {
        notify { "contained": }
      }

      class container {
        contain contained
      }

      include container
    MANIFEST

    expect(catalog.classes).to include("contained")
  end

  it "makes the class contained in the current class" do
    catalog = compile_to_catalog(<<-MANIFEST)
      class contained {
        notify { "contained": }
      }

      class container {
        contain contained
      }

      include container
    MANIFEST

    expect(catalog).to contain_class("contained").in("container")
  end

  it "can contain multiple classes" do
    catalog = compile_to_catalog(<<-MANIFEST)
      class a {
        notify { "a": }
      }

      class b {
        notify { "b": }
      }

      class container {
        contain a, b
      }

      include container
    MANIFEST

    expect(catalog).to contain_class("a").in("container")
    expect(catalog).to contain_class("b").in("container")
  end

  it "can contain a class in multiple classes" do
    catalog = compile_to_catalog(<<-MANIFEST)
      class contained {
        notify { "contained": }
      }

      class container {
        contain contained
      }

      class another {
        contain contained
      }

      include container
      include another

      Class["container"] -> Class["another"]
    MANIFEST

    expect(catalog).to contain_class("contained").in("container")
    expect(catalog).to contain_class("contained").in("another")
  end

  it "causes a dependency cycle when multiple containment is combined with explicit dependencies" do
    manifest = <<-MANIFEST
      class contained {
        notify { "contained": }
      }

      class container {
        contain contained
      }

      class another {
        contain contained
      }

      include container
      include another

      Class["container"] -> Class["another"]
    MANIFEST

    expect { apply_compiled_manifest(manifest) }.to raise_error(
      Puppet::Error,
      /Found 1 dependency cycle/
    )
  end
end
