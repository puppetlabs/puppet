module Spec
  module VERSION
    unless defined? MAJOR
      MAJOR  = 1
      MINOR  = 0
      TINY   = 8
      RELEASE_CANDIDATE = nil

      # RANDOM_TOKEN: 0.510454315029681
      REV = "$LastChangedRevision: 2338 $".match(/LastChangedRevision: (\d+)/)[1]

      STRING = [MAJOR, MINOR, TINY].join('.')
      TAG = "REL_#{[MAJOR, MINOR, TINY, RELEASE_CANDIDATE].compact.join('_')}".upcase.gsub(/\.|-/, '_')
      FULL_VERSION = "#{[MAJOR, MINOR, TINY, RELEASE_CANDIDATE].compact.join('.')} (r#{REV})"

      NAME   = "RSpec"
      URL    = "http://rspec.rubyforge.org/"  
    
      DESCRIPTION = "#{NAME}-#{FULL_VERSION} - BDD for Ruby\n#{URL}"
    end
  end
end

