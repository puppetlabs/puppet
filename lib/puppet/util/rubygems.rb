require 'puppet/util'

module Puppet::Util::RubyGems

  #Base/factory class for rubygems source
  class Source
    class << self
      def has_rubygems?
        # Gems are not actually available when Bundler is loaded, even
        # though the Gem constant is defined. This is because Bundler
        # loads in rubygems, but then removes the custom require that
        # rubygems installs. So when Bundler is around we have to act
        # as though rubygems is not, e.g. we shouldn't be able to load
        # a gem that Bundler doesn't want us to see.
        defined? ::Gem and not defined? ::Bundler
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

