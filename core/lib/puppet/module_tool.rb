# encoding: UTF-8
# Load standard libraries
require 'pathname'
require 'fileutils'
require 'puppet/util/colors'

module Puppet
  module ModuleTool
    require 'puppet/module_tool/tar'
    extend Puppet::Util::Colors

    # Directory and names that should not be checksummed.
    ARTIFACTS = ['pkg', /^\./, /^~/, /^#/, 'coverage', 'metadata.json', 'REVISION']
    FULL_MODULE_NAME_PATTERN = /\A([^-\/|.]+)[-|\/](.+)\z/
    REPOSITORY_URL = Puppet.settings[:module_repository]

    # Is this a directory that shouldn't be checksummed?
    #
    # TODO: Should this be part of Checksums?
    # TODO: Rename this method to reflect its purpose?
    # TODO: Shouldn't this be used when building packages too?
    def self.artifact?(path)
      case File.basename(path)
      when *ARTIFACTS
        true
      else
        false
      end
    end

    # Return the +username+ and +modname+ for a given +full_module_name+, or raise an
    # ArgumentError if the argument isn't parseable.
    def self.username_and_modname_from(full_module_name)
      if matcher = full_module_name.match(FULL_MODULE_NAME_PATTERN)
        return matcher.captures
      else
        raise ArgumentError, "Not a valid full name: #{full_module_name}"
      end
    end

    # Find the module root when given a path by checking each directory up from
    # its current location until it finds one that contains a file called
    # 'Modulefile'.
    #
    # @param path [Pathname, String] path to start from
    # @return [Pathname, nil] the root path of the module directory or nil if
    #   we cannot find one
    def self.find_module_root(path)
      path = Pathname.new(path) if path.class == String

      path.expand_path.ascend do |p|
        return p if is_module_root?(p)
      end

      nil
    end

    # Analyse path to see if it is a module root directory by detecting a
    # file named 'Modulefile' in the directory.
    #
    # @param path [Pathname, String] path to analyse
    # @return [Boolean] true if the path is a module root, false otherwise
    def self.is_module_root?(path)
      path = Pathname.new(path) if path.class == String

      FileTest.file?(path + 'Modulefile')
    end

    # Builds a formatted tree from a list of node hashes containing +:text+
    # and +:dependencies+ keys.
    def self.format_tree(nodes, level = 0)
      str = ''
      nodes.each_with_index do |node, i|
        last_node = nodes.length - 1 == i
        deps = node[:dependencies] || []

        str << (indent = "  " * level)
        str << (last_node ? "└" : "├")
        str << "─"
        str << (deps.empty? ? "─" : "┬")
        str << " #{node[:text]}\n"

        branch = format_tree(deps, level + 1)
        branch.gsub!(/^#{indent} /, indent + '│') unless last_node
        str << branch
      end

      return str
    end

    def self.build_tree(mods, dir)
      mods.each do |mod|
        version_string = mod[:version][:vstring].sub(/^(?!v)/, 'v')

        if mod[:action] == :upgrade
          previous_version = mod[:previous_version].sub(/^(?!v)/, 'v')
          version_string = "#{previous_version} -> #{version_string}"
        end

        mod[:text] = "#{mod[:module]} (#{colorize(:cyan, version_string)})"
        mod[:text] += " [#{mod[:path]}]" unless mod[:path] == dir
        build_tree(mod[:dependencies], dir)
      end
    end

    def self.set_option_defaults(options)
      sep = File::PATH_SEPARATOR

      if options[:environment]
        Puppet.settings[:environment] = options[:environment]
      else
        options[:environment] = Puppet.settings[:environment]
      end

      if options[:modulepath]
        Puppet.settings[:modulepath] = options[:modulepath]
      else
        # (#14872) make sure the module path of the desired environment is used
        # when determining the default value of the --target-dir option
        Puppet.settings[:modulepath] = options[:modulepath] =
          Puppet.settings.value(:modulepath, options[:environment])
      end

      if options[:target_dir]
        options[:target_dir] = File.expand_path(options[:target_dir])
        # prepend the target dir to the module path
        Puppet.settings[:modulepath] = options[:modulepath] =
          options[:target_dir] + sep + options[:modulepath]
      else
        # default to the first component of the module path
        options[:target_dir] =
          File.expand_path(options[:modulepath].split(sep).first)
      end
    end
  end
end

# Load remaining libraries
require 'puppet/module_tool/errors'
require 'puppet/module_tool/applications'
require 'puppet/module_tool/checksums'
require 'puppet/module_tool/contents_description'
require 'puppet/module_tool/dependency'
require 'puppet/module_tool/metadata'
require 'puppet/module_tool/modulefile'
require 'puppet/module_tool/skeleton'
require 'puppet/forge/cache'
require 'puppet/forge'
