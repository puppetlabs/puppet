# frozen_string_literal: true

# is only needed to create the name space
module Puppet::Parser; end

require_relative 'parser/ast'
require_relative 'parser/abstract_compiler'
require_relative 'parser/compiler'
require_relative 'parser/compiler/catalog_validator'
require_relative '../puppet/resource/type_collection'

require_relative 'parser/functions'
require_relative 'parser/files'
require_relative 'parser/relationship'

require_relative '../puppet/resource/type'
require 'monitor'

require_relative 'parser/compiler/catalog_validator/relationship_validator'

# PUP-3274 This should probably go someplace else
class Puppet::LexError < RuntimeError; end
