require 'puppet/external/pson/common'
require 'puppet/external/pson/pure/parser'
require 'puppet/external/pson/pure/generator'

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
