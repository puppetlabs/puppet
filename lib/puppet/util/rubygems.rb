require 'puppet/util'

module Puppet::Util::RubyGems

  #Base/factory class for rubygems source
  class Source
    class << self
      def has_rubygems?
        begin
          require 'rubygems'
          true
        rescue LoadError
          false
        end
      end

      def source
        if has_rubygems?
          Gem::Specification.respond_to?(:latest_specs) ? Gems18Source : OldGemsSource
        else
          NoGemsSource
        end
      end

      def new(*args)
        object = source.allocate
        object.send(:initialize, *args)
        object
      end
    end
  end

  # For RubyGems >= 1.8.0
  class Gems18Source < Source
    def directories
      Gem::Specification.latest_specs.collect do |spec|
        File.join(spec.full_gem_path, 'lib')
      end
    end
  end

  # RubyGems < 1.8.0
  class OldGemsSource < Source
    def directories
      @paths ||= Gem.latest_load_paths
    end
  end

  class NoGemsSource < Source
    def directories
      []
    end
  end
end

