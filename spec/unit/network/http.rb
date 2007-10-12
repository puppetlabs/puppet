#!/usr/bin/env ruby
#
#  Created by Rick Bradley on 2007-10-03.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/network/http'

describe Puppet::Network::HTTP do
    it "should require a server type when initializing"
    it "should return an instance of the http server class corresponding to the server type"
end