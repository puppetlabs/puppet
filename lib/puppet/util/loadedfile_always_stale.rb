# A simple class that tells us when a file has changed and thus whether we
# should reload it

require 'puppet'
require 'puppet/util/loadedfile'

module Puppet
  class Util::LoadedFileAlwaysStale < Util::LoadedFile

    # This implementation of #changed? always returns true. 
    #
    def changed?
      true
    end
  end
end

