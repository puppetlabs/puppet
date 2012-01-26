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
      @environment = Puppet::Node::Environment.new(Puppet.settings[:environment])
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
    def get_release_packages(params)
      cache_paths = nil
      case params[:source]
      when :repository
        if not (params[:author] && params[:modname])
          raise ArgumentError, ":author and :modename required"
        end
        cache_paths = get_release_packages_from_repository(params[:author], params[:modname], params[:version])
      when :filesystem
        if not params[:filename]
          raise ArgumentError, ":filename required"
        end
        cache_paths = get_release_package_from_filesystem(params[:filename])
      else
        raise ArgumentError, "Could not determine installation source"
      end

      cache_paths
    end

    private

    # Locate and download a module release package from the remote forge
    # repository into the `Puppet.settings[:module_working_dir]`. Do not
    # unpack it, just return the location of the package on disk.
    def get_release_packages_from_repository(author, modname, version=nil)
      install_list = resolve_remote_and_local_constraints(author, modname, version)
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
#   def get_release(author, modname, version_requirement=nil)
#     begin
#       response = repository.make_http_request(request)
#     rescue => e
#       raise  ArgumentError, "Could not find a release for this module (#{e.message})"
#     end

#     PSON.parse(response.body)
#   end

    def remote_dependency_info(author, mod_name, version)
      version_string = version ? "&version=#{version}" : ''
      request = Net::HTTP::Get.new("/api/v1/releases.json?module=#{author}/#{mod_name}" + version_string)
      begin
        response = repository.make_http_request(request)
      rescue => e
        raise ArgumentError, "Could not find release information for this module (#{e.message})"
      end
      PSON.parse(response.body)
    end

    def find_latest_working_versions(name, versions, ancestors = [])
      return if ancestors.include?(name)
      ancestors << name

      if !versions[name] || versions[name].empty?
        # Raising here prevents us from backtracking and trying earlier
        # versions This means installations are less likely to succeed, but
        # should be more predictable If it's later decided that backtracking
        # is desired, replacing the raise with a `return false` should work
        raise RuntimeError, "No working versions for #{name}"
      end
      versions[name].sort_by {|v| v['version']}.reverse.each do |version|
        results = [[name, version['version'], version['file']]]
        return results if version['dependencies'].empty?
        version['dependencies'].each do |dep|
          dep_name, dep_req = dep
          working_version = find_latest_working_versions(dep_name, versions, ancestors)
          results += working_version if working_version
        end
        return results
      end
      false
    end

    def resolve_remote_and_local_constraints(author, modname, version=nil)
      remote_deps = remote_dependency_info(author, modname, version)

      warnings = remote_deps.delete('_warnings')
      warnings.each do |warning|
        Puppet.warning warning
      end if warnings

      remote_deps.each do |mod_name, versions|
        resolve_already_existing_module_constraints(mod_name, versions)
        resolve_local_constraints(mod_name, versions)
      end
      mod_download_list = find_latest_working_versions("#{author}/#{modname}", remote_deps)
      mod_download_list
    end

    def resolve_local_constraints(forge_name, versions)
      local_deps = @environment.module_requirements
      versions.delete_if do |version_info|
        semver = SemVer.new(version_info['version'])
        local_deps[forge_name] and local_deps[forge_name][:required_by].any? do |req|
          req_name, version_req = req
          equality, local_ver = version_req.split(/\s/)
          !(semver.send(equality, SemVer.new(local_ver)))
        end
      end
    end

    def resolve_already_existing_module_constraints(forge_name, versions)
      author_name, mod_name = forge_name.split('/')
      existing_mod = @environment.module(mod_name)
      if existing_mod
        unless existing_mod.has_metadata?
          raise RuntimeError, "A local version of the #{mod_name} module exists but has no metadata"
        end
        if existing_mod.forge_name != forge_name
          raise RuntimeError, "A local version of the #{mod_name} module exists but has a different name (#{existing_mod.forge_name})"
        end
        if !existing_mod.version || existing_mod.version.empty?
          raise RuntimeError, "A local version of the #{mod_name} module exists without version info"
        end
        begin
          SemVer.new(existing_mod.version)
        rescue => e
          raise RuntimeError,
            "A local version of the #{mod_name} module declares a non semantic version (#{existing_mod.version})"
        end
        if versions.map {|v| v['version']}.include? existing_mod.version
          versions.delete_if {|version_info| version_info['version'] != existing_mod.version}
        end
      end
    end
  end
end

