# frozen_string_literal: true

require_relative '../../puppet/util'

module Puppet::Util::RubyGems
  # Base/factory class for rubygems source. These classes introspec into
  # rubygems to in order to list where the rubygems system will look for files
  # to load.
  class Source
    class << self
      # @api private
      def has_rubygems?
        # Gems are not actually available when Bundler is loaded, even
        # though the Gem constant is defined. This is because Bundler
        # loads in rubygems, but then removes the custom require that
        # rubygems installs. So when Bundler is around we have to act
        # as though rubygems is not, e.g. we shouldn't be able to load
        # a gem that Bundler doesn't want us to see.
        defined? ::Gem and !defined? ::Bundler
      end

      # @api private
      def source
        if has_rubygems?
          Gems18Source
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
  # @api private
  class Gems18Source < Source
    def directories
      # `require 'mygem'` will consider and potentially load
      # prerelease gems, so we need to match that behavior.
      #
      # Just load the stub which points to the gem path, and
      # delay loading the full specification until if/when the
      # gem is required.
      Gem::Specification.stubs.collect do |spec|
        File.join(spec.full_gem_path, 'lib')
      end
    end

    def clear_paths
      Gem.clear_paths
    end
  end

  # @api private
  class NoGemsSource < Source
    def directories
      []
    end

    def clear_paths; end
  end
end
