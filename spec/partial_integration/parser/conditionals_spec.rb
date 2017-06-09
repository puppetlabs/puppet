require 'spec_helper'
require 'puppet_spec/compiler'
require 'matchers/resource'

describe "Evaluation of Conditionals" do
  include PuppetSpec::Compiler
  include Matchers::Resource

  context "a catalog built with conditionals" do
    it "evaluates an if block correctly" do
      catalog = compile_to_catalog(<<-CODE)
      if( 1 == 1) {
        notify { 'if': }
      } elsif(2 == 2) {
        notify { 'elsif': }
      } else {
        notify { 'else': }
      }
      CODE
      expect(catalog).to have_resource("Notify[if]")
    end

    it "evaluates elsif block" do
      catalog = compile_to_catalog(<<-CODE)
      if( 1 == 3) {
        notify { 'if': }
      } elsif(2 == 2) {
        notify { 'elsif': }
      } else {
        notify { 'else': }
      }
      CODE
      expect(catalog).to have_resource("Notify[elsif]")
    end

    it "reaches the else clause if no expressions match" do
      catalog = compile_to_catalog(<<-CODE)
      if( 1 == 2) {
        notify { 'if': }
      } elsif(2 == 3) {
        notify { 'elsif': }
      } else {
        notify { 'else': }
      }
      CODE
      expect(catalog).to have_resource("Notify[else]")
    end

    it "evalutes false to false" do
      catalog = compile_to_catalog(<<-CODE)
      if false {
      } else {
        notify { 'false': }
      }
      CODE
      expect(catalog).to have_resource("Notify[false]")
    end

    it "evaluates the string 'false' as true" do
      catalog = compile_to_catalog(<<-CODE)
      if 'false' {
        notify { 'true': }
      } else {
        notify { 'false': }
      }
      CODE
      expect(catalog).to have_resource("Notify[true]")
    end

    it "evaluates undefined variables as false" do
      catalog = compile_to_catalog(<<-CODE)
      if $undef_var {
      } else {
        notify { 'undef': }
      }
      CODE
      expect(catalog).to have_resource("Notify[undef]")
    end

    it "evaluates empty string as true" do
      catalog = compile_to_catalog(<<-CODE)
      if '' {
        notify { 'true': }
      } else {
        notify { 'empty': }
      }
      CODE
      expect(catalog).to have_resource("Notify[true]")
    end
  end

end
