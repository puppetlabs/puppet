#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops/api'
require 'puppet/pops/api/model/model'
require 'puppet/pops/impl/model/factory'
require 'puppet/pops/impl/model/model_tree_dumper'
require 'puppet/pops/impl/evaluator_impl'
require 'puppet/pops/impl/base_scope'
require 'puppet/pops/impl/parser/eparser'

# relative to this spec file (./) does not work as this file is loaded by rspec
require File.join(File.dirname(__FILE__), '/parser_rspec_helper')

describe Puppet::Pops::Impl::Parser::Parser do

  context "When running these examples, the setup" do

    it "should be possible to create an empty hash after having required the files above" do
      # If this fails, it means the rgen addition to Array is not monkey patched as it
      # should (it will return an array instead of fail in a method_missing), and thus
      # screw up Hash's check if it can do "to_hash' or not.
      #
      Hash[[]]
    end

  end

end
