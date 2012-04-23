# encoding: UTF-8
# Load standard libraries
require 'pathname'
require 'fileutils'
require 'puppet/util/colors'

# Define tool
module Puppet
  module ModuleTool
    extend Puppet::Util::Colors

    # Directory and names that should not be checksummed.
    ARTIFACTS = ['pkg', /^\./, /^~/, /^#/, 'coverage', 'metadata.json', 'REVISION']
    FULL_MODULE_NAME_PATTERN = /\A([^-\/|.]+)[-|\/](.+)\z/
    REPOSITORY_URL = Puppet.settings[:module_repository]

    # Is this a directory that shouldn't be checksummed?
    #
    # TODO: Should this be part of Checksums?
    # TODO: Rename this method to reflect it's purpose?
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

    def self.find_module_root(path)
      for dir in [path, Dir.pwd].compact
        if File.exist?(File.join(dir, 'Modulefile'))
          return dir
        end
      end
      raise ArgumentError, "Could not find a valid module at #{path ? path.inspect : 'current directory'}"
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
