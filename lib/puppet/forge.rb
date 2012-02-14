require 'net/http'
require 'open-uri'
require 'pathname'
require 'uri'
require 'puppet/forge/cache'
require 'puppet/forge/repository'

module Puppet::Forge
  module Forge
    # Return a list of module metadata hashes that match the search query.
    # This return value is used by the module_tool face install search,
    # and displayed to on the console.
    #
    # Example return value:
    #
    # [
    #   {
    #     "author"      => "puppetlabs",
    #     "name"        => "bacula",
    #     "tag_list"    => ["backup", "bacula"],
    #     "releases"    => [{"version"=>"0.0.1"}, {"version"=>"0.0.2"}],
    #     "full_name"   => "puppetlabs/bacula",
    #     "version"     => "0.0.2",
    #     "project_url" => "http://github.com/puppetlabs/puppetlabs-bacula",
    #     "desc"        => "bacula"
    #   }
    # ]
    #
    def self.search(term)
      request = Net::HTTP::Get.new("/modules.json?q=#{URI.escape(term)}")
      response = repository.make_http_request(request)

      case response.code
      when "200"
        matches = PSON.parse(response.body)
      else
        raise RuntimeError, "Could not execute search (HTTP #{response.code})"
        matches = []
      end

      matches
    end

    def self.remote_dependency_info(author, mod_name, version)
      version_string = version ? "&version=#{version}" : ''
      request = Net::HTTP::Get.new("/api/v1/releases.json?module=#{author}/#{mod_name}" + version_string)
      begin
        response = repository.make_http_request(request)
      rescue => e
        raise ArgumentError, "Could not find release information for this module (#{e.message})"
      end
      PSON.parse(response.body)
    end

    def self.get_release_packages_from_repository(install_list)
      install_list.map do |release|
        modname, version, file = release
        cache_path = nil
        if file
          begin
            cache_path = repository.retrieve(file)
          rescue OpenURI::HTTPError => e
            raise RuntimeError, "Could not download module: #{e.message}"
          end
        else
          raise RuntimeError, "Malformed response from module repository."
        end
        cache_path
      end
    end

    # Locate a module release package on the local filesystem and move it
    # into the `Puppet.settings[:module_working_dir]`. Do not unpack it, just
    # return the location of the package on disk.
    def self.get_release_package_from_filesystem(filename)
      if File.exist?(File.expand_path(filename))
        repository = Repository.new('file:///')
        uri = URI.parse("file://#{URI.escape(File.expand_path(filename))}")
        cache_path = repository.retrieve(uri)
      else
        raise ArgumentError, "File does not exists: #{filename}"
      end

      cache_path
    end

    def self.repository
      @repository ||= Puppet::Forge::Repository.new
    end
  end
end

