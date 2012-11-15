#! /usr/bin/env ruby
require 'spec_helper'
require 'shared_behaviours/all_parsedfile_providers'

provider_class = Puppet::Type.type(:mailalias).provider(:aliases)

describe provider_class do
  # #1560, in which we corrupt the format of complex mail aliases.
  it_should_behave_like "all parsedfile providers", provider_class
end
