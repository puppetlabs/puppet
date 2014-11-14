# is only needed to create the name space
module Puppet::Parser; end

require 'puppet/parser/ast'
require 'puppet/parser/compiler'
require 'puppet/resource/type_collection'

require 'puppet/parser/functions'
require 'puppet/parser/files'
require 'puppet/parser/relationship'

require 'puppet/resource/type_collection_helper'
require 'puppet/resource/type'
require 'monitor'

# PUP-3274 This should probably go someplace else
class Puppet::LexError < RuntimeError; end
