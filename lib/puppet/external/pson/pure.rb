require_relative '../../../puppet/external/pson/common'
require_relative 'pure/parser'
require_relative 'pure/generator'

module PSON
  # This module holds all the modules/classes that implement PSON's
  # functionality in pure ruby.
  module Pure
    $DEBUG and warn "Using pure library for PSON."
    PSON.parser = Parser
    PSON.generator = Generator
  end

  PSON_LOADED = true
end
