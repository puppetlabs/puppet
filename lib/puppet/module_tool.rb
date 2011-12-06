# Load standard libraries
require 'pathname'
require 'fileutils'
require 'puppet/module_tool/utils'

# Define tool
module Puppet
  class Module
    module Tool

      # Directory names that should not be checksummed.
      ARTIFACTS = ['pkg', /^\./, /^~/, /^#/, 'coverage']
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

      # Read HTTP proxy configurationm from Puppet's config file, or the
      # http_proxy environment variable.
      def self.http_proxy_env
        proxy_env = ENV["http_proxy"] || ENV["HTTP_PROXY"] || nil
        begin
          return URI.parse(proxy_env) if proxy_env
        rescue URI::InvalidURIError
          return nil
        end
        return nil
      end

      def self.http_proxy_host
        env = http_proxy_env

        if env and env.host then
          return env.host
        end

        if Puppet.settings[:http_proxy_host] == 'none'
          return nil
        end

        return Puppet.settings[:http_proxy_host]
      end

      def self.http_proxy_port
        env = http_proxy_env

        if env and env.port then
          return env.port
        end

        return Puppet.settings[:http_proxy_port]
      end

      def self.find_module_root(path)
        for dir in [path, Dir.pwd].compact
          if File.exist?(File.join(dir, 'Modulefile'))
            return dir
          end
        end
        raise ArgumentError, "Could not find a valid module at #{path ? path.inspect : 'current directory'}"
      end
    end
  end
end

# Load remaining libraries
require 'puppet/module_tool/applications'
require 'puppet/module_tool/cache'
require 'puppet/module_tool/checksums'
require 'puppet/module_tool/contents_description'
require 'puppet/module_tool/dependency'
require 'puppet/module_tool/metadata'
require 'puppet/module_tool/modulefile'
require 'puppet/module_tool/repository'
require 'puppet/module_tool/skeleton'
