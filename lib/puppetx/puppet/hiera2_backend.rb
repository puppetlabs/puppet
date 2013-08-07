module Puppetx::Puppet

  # Hiera2Backend is a Puppet Extension Point for the purpose of extending Puppet with a hiera data compatible
  # backend. The intended use is to create a class derived from this class and then register it with the
  # Puppet Binder under a backend name in the `binder_config.yaml` file to map symbolic name to class name.
  #
  # The responsibility of a Hiera2 backend is minimal. It should read the given file (with some extesion(s) determined by
  # the backend, and return a hash of the content. If the directory does not exist, or the file does not exist an empty
  # hash should be produced.
  #
  # @abstract
  # @api public
  #
  class Hiera2Backend
    # Produces a hash with data read from the file in the given
    # directory having the given file_name (with extensions appended under the discretion of this
    # backend).
    #
    # Should return an empty hash if the directory or the file does not exist. May raise exception on other types of errors, but
    # not return nil.
    #
    # @param directory [String] the path to the directory containing the file to read
    # @param file_name [String] the file name (without extension) that should be read
    # @return [Hash<String, Object>, Hash<Symbol, Object>] the produced hash with data, may be empty if there was no file
    # @api public
    #
    def read_data(directory, file_name)
      raise NotImplementedError, "The class #{self.class.name} should have implemented the method 'read_data(directory, file_name)'"
    end
  end
end
