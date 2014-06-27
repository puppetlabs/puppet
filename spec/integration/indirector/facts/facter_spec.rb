#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet_spec/compiler'

describe Puppet::Node::Facts::Facter do
  include PuppetSpec::Compiler

  it "preserves case in fact values" do
    Facter.add(:downcase_test) do
      setcode do
        "AaBbCc"
      end
    end

    Facter.stubs(:reset)

    cat = compile_to_catalog('notify { $downcase_test: }',
                             Puppet::Node.indirection.find('foo'))
    cat.resource("Notify[AaBbCc]").should be
  end
end
