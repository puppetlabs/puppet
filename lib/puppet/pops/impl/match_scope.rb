require 'puppet/pops/api'
require 'puppet/pops/impl'

module Puppet::Pops::Impl
  # This is a special inner scope class that implements mappint of numeric variables
  # to a match result. It is not a free standing scope.
  #
  class MatchScope
    def initialize(match_data = nil, origin = nil)
      @match_data = (match_data ? match_data : [])
      @origin = origin
    end

    def get_entry(n)
      Puppet::Pops::NamedEntry.new(:variable, n.to_s, @match_data[n], @origin).freeze
    end

    def [](n)
      get_entry(n)
    end
  end
end