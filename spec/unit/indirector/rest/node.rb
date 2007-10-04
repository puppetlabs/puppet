#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/rest/node'

describe Puppet::Indirector::REST::Node do
    before do
        @searcher = Puppet::Indirector::REST::Node.new
    end
    
    
end
