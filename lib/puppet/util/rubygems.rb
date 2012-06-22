require 'puppet/util'

module Puppet::Util::RubyGems
  module_function

  # Get the load paths for the latest versions of installed gems. We only want
  # the latest versions of each gem to prevent mixing old and new code for
  # things like Faces, and custom report processors.
  def directories
    begin
      require 'rubygems'
      # Rubygems >= 1.8.0
      if Gem::Specification.respond_to? :latest_specs
        dirs = Gem::Specification.latest_specs.collect do |spec|
          File.join(spec.full_gem_path, '/lib')
        end
      elsif Gem.respond_to? :latest_load_paths
        dirs = Gem.latest_load_paths
      else
        return []
      end
    rescue LoadError
      return []
    end

    dirs.find_all { |d| FileTest.directory?(d) }
  end
end

