# is only needed to create the name space
module Puppet::Parser; end

require 'puppet/parser/ast'
require 'puppet/parser/abstract_compiler'
require 'puppet/parser/compiler'
require 'puppet/parser/compiler/catalog_validator'
require 'puppet/resource/type_collection'

require 'puppet/parser/functions'
require 'puppet/parser/files'
require 'puppet/parser/relationship'

require 'puppet/resource/type'
require 'monitor'

require 'puppet/parser/compiler/catalog_validator/relationship_validator.rb'

# PUP-3274 This should probably go someplace else
class Puppet::LexError < RuntimeError; end
