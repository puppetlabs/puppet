#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/node/rest'

describe Puppet::Node::REST do
    before do
        @searcher = Puppet::Node::REST.new
    end
    
    
end
