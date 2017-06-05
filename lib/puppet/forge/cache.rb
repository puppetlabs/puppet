require 'uri'

require 'puppet/forge'

class Puppet::Forge
  # = Cache
  #
  # Provides methods for reading files from local cache, filesystem or network.
  class Cache

    # Instantiate new cache for the +repository+ instance.
    def initialize(repository, options = {})
      @repository = repository
      @options = options
    end

    # Return filename retrieved from +uri+ instance. Will download this file and
    # cache it if needed.
    #
    # TODO: Add checksum support.
    # TODO: Add error checking.
    def retrieve(url)
      (path + File.basename(url.to_s)).tap do |cached_file|
        uri = url.is_a?(::URI) ? url : ::URI.parse(url)
        unless cached_file.file?
          if uri.scheme == 'file'
            # CGI.unescape butchers Uris that are escaped properly
            FileUtils.cp(URI.unescape(uri.path), cached_file)
          else
            # TODO: Handle HTTPS; probably should use repository.contact
            data = read_retrieve(uri)
            cached_file.open('wb') { |f| f.write data }
          end
        end
      end
    end

    # Return contents of file at the given URI's +uri+.
    def read_retrieve(uri)
      return uri.read
    end

    # Return Pathname for repository's cache directory, create it if needed.
    def path
      (self.class.base_path + @repository.cache_key).tap{ |o| o.mkpath }
    end

    # Return the base Pathname for all the caches.
    def self.base_path
      (Pathname(Puppet.settings[:module_working_dir]) + 'cache').tap do |o|
        o.mkpath unless o.exist?
      end
    end

    # Clean out all the caches.
    def self.clean
      base_path.rmtree if base_path.exist?
    end
  end
end
