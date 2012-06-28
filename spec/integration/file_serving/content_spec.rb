#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-10-18.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/file_serving/content'
require 'shared_behaviours/file_serving'

describe Puppet::FileServing::Content, " when finding files" do
  it_should_behave_like "a file_serving model"
end
