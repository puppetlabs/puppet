#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/util/reference'

describe Puppet::Util::Reference do
  it "should create valid Markdown extension definition lists" do
    my_fragment = nil
    Puppet::Util::Reference.newreference :testreference, :doc => "A peer of the type and configuration references, but with no useful information" do
      my_term = "A term"
      my_definition = <<-EOT
The definition of this term.
We should be able to handle multi-line definitions.

We should be able to handle multi-paragraph definitions.
      EOT
      my_fragment = markdown_definitionlist(my_term, my_definition)
    end
    Puppet::Util::Reference.reference(:testreference).send(:to_markdown, true)
    my_fragment.should == <<-EOT
A term
: The definition of this term.
    We should be able to handle multi-line definitions.

    We should be able to handle multi-paragraph definitions.

    EOT
  end

end