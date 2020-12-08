# is only needed to create the name space
module Puppet::Parser; end

require_relative '../puppet/parser/ast'
require_relative '../puppet/parser/abstract_compiler'
require_relative '../puppet/parser/compiler'
require_relative '../puppet/parser/compiler/catalog_validator'
require_relative '../puppet/resource/type_collection'

require_relative '../puppet/parser/functions'
require_relative '../puppet/parser/files'
require_relative '../puppet/parser/relationship'

require_relative '../puppet/resource/type'
require 'monitor'

require_relative '../puppet/parser/compiler/catalog_validator/relationship_validator'

# PUP-3274 This should probably go someplace else
class Puppet::LexError < RuntimeError; end
