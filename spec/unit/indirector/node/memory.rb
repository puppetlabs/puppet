#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/node/memory'

# All of our behaviour is described here, so we always have to include it.
require File.dirname(__FILE__) + '/../memory'

describe Puppet::Node::Memory do
    before do
        @name = "me"
        @searcher = Puppet::Node::Memory.new
        @instance = stub 'instance', :name => @name
    end

    it_should_behave_like "A Memory Terminus"
end
