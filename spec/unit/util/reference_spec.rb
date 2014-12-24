#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/util/reference'

describe Puppet::Util::Reference do
  it "should create valid Markdown extension definition lists" do
    my_fragment = nil
    Puppet::Util::Reference.newreference :testreference, :doc => "A peer of the type and configuration references, but with no useful information" do
      my_term = "A term"
      my_definition = <<-EOT
        The definition of this term, marked by a colon and a space.
        We should be able to handle multi-line definitions. Each subsequent
        line should left-align with the first word character after the colon
        used as the definition marker.

        We should be able to handle multi-paragraph definitions.

        Leading indentation should be stripped from the definition, which allows
        us to indent the source string for cosmetic purposes.
      EOT
      my_fragment = markdown_definitionlist(my_term, my_definition)
    end
    Puppet::Util::Reference.reference(:testreference).send(:to_markdown, true)
    expect(my_fragment).to eq <<-EOT
A term
: The definition of this term, marked by a colon and a space.
  We should be able to handle multi-line definitions. Each subsequent
  line should left-align with the first word character after the colon
  used as the definition marker.

  We should be able to handle multi-paragraph definitions.

  Leading indentation should be stripped from the definition, which allows
  us to indent the source string for cosmetic purposes.

    EOT
  end

end
