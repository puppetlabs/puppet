#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/memory/node'

# All of our behaviour is described here, so we always have to 
# include it.
require 'unit/indirector/memory'

describe Puppet::Indirector::Memory::Node do
    before do
        @name = "me"
        @searcher = Puppet::Indirector::Memory::Node.new
        @instance = stub 'instance', :name => @name
    end

    it_should_behave_like "A Memory Terminus"
end
