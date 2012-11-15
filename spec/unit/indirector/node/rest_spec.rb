#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/node/rest'

describe Puppet::Node::Rest do
  before do
    @searcher = Puppet::Node::Rest.new
  end


end
