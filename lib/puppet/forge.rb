require 'net/http'
require 'open-uri'
require 'pathname'
require 'uri'
require 'puppet/forge/cache'
require 'puppet/forge/repository'

module Puppet::Forge
  class Forge
    def initialize(url=Puppet.settings[:module_repository])
      @uri = URI.parse(url)
    end

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
    def search(term)
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

    # Return a Pathname object representing the path to the module
    # release package in the `Puppet.settings[:module_working_dir]`.
    def get_release_package(params)
      cache_path = nil
      case params[:source]
      when :repository
        if not (params[:author] && params[:modname])
          raise ArgumentError, ":author and :modename required"
        end
        cache_path = get_release_package_from_repository(params[:author], params[:modname], params[:version])
      when :filesystem
        if not params[:filename]
          raise ArgumentError, ":filename required"
        end
        cache_path = get_release_package_from_filesystem(params[:filename])
      else
        raise ArgumentError, "Could not determine installation source"
      end

      cache_path
    end

    def get_releases(author, modname)
      request_string = "/#{author}/#{modname}"

      begin
        response = repository.make_http_request(request_string)
      rescue => e
        raise ArgumentError, "Could not find a release for this module (#{e.message})"
      end

      results = PSON.parse(response.body)
      # At this point releases look like this:
      # [{"version" => "0.0.1"}, {"version" => "0.0.2"},{"version" => "0.0.3"}]
      #
      # Lets fix this up a bit and return something like this to the caller
      # ["0.0.1", "0.0.2", "0.0.3"]
      results["releases"].collect {|release| release["version"]}
    end

    private

    # Locate and download a module release package from the remote forge
    # repository into the `Puppet.settings[:module_working_dir]`. Do not
    # unpack it, just return the location of the package on disk.
    def get_release_package_from_repository(author, modname, version=nil)
      release = get_release(author, modname, version)
      if release['file']
        begin
          cache_path = repository.retrieve(release['file'])
        rescue OpenURI::HTTPError => e
          raise RuntimeError, "Could not download module: #{e.message}"
        end
      else
        raise RuntimeError, "Malformed response from module repository."
      end

      cache_path
    end

    # Locate a module release package on the local filesystem and move it
    # into the `Puppet.settings[:module_working_dir]`. Do not unpack it, just
    # return the location of the package on disk.
    def get_release_package_from_filesystem(filename)
      if File.exist?(File.expand_path(filename))
        repository = Repository.new('file:///')
        uri = URI.parse("file://#{URI.escape(File.expand_path(filename))}")
        cache_path = repository.retrieve(uri)
      else
        raise ArgumentError, "File does not exists: #{filename}"
      end

      cache_path
    end

    def repository
      @repository ||= Puppet::Forge::Repository.new(@uri)
    end

    # Connect to the remote repository and locate a specific module release
    # by author/name combination. If a version requirement is specified, search
    # for that exact version, or grab the latest release available.
    #
    # Return the following response to the caller:
    #
    # {"file"=>"/system/releases/p/puppetlabs/puppetlabs-apache-0.0.3.tar.gz", "version"=>"0.0.3"}
    #
    #
    def get_release(author, modname, version_requirement=nil)
      request_string = "/users/#{author}/modules/#{modname}/releases/find.json"
      if version_requirement
        request_string + "?version=#{URI.escape(version_requirement)}"
      end
      request = Net::HTTP::Get.new(request_string)

      begin
        response = repository.make_http_request(request)
      rescue => e
        raise  ArgumentError, "Could not find a release for this module (#{e.message})"
      end

      PSON.parse(response.body)
    end
  end
end

