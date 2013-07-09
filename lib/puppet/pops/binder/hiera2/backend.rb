module Puppet::Pops::Binder::Hiera2
  # A Hiera2 backend is responsible for producing a key value hash that represents
  # the bindings for a certain categorization within a module. The Backend class
  # has some helper method that assist with loading backend implementations
  # based on a key (yaml, json, etc.).
  #
  # An implementor of a Backend must implement the method read_data(module_dir, source)
  #
  class Backend
    # Checks that a backend class exists that corresponds to the given key
    # @param key The key to use when finding the corresponding backend class
    # @param acceptor Acceptor that will receive diagnostics if the class cannot be found and loaded
    def self.check_key(key, config_file, acceptor)
      bc = nil
      begin
        bc = backend_class(key)
      rescue NameError
        begin
          # Require the needed file and try again
          source_file = "puppet/pops/binder/hiera2/#{key.downcase}_backend"
          require source_file
          begin
            bc = backend_class(key)
          rescue NameError
            acceptor.accept(Issues::BACKEND_FILE_DOES_NOT_DEFINE_CLASS, source_file, { :class_name => backend_class_name(key) } )
          end
        rescue LoadError => e
          acceptor.accept(Issues::CANNOT_LOAD_BACKEND, config_file, { :key => key, :error => e} )
        end
      end
      unless bc.nil?
        acceptor.accept(Issues::NOT_A_BACKEND_CLASS, config_file, { :key => key, :class_name => bc.name }) unless has_backend_api?(bc)
      end
    end

    # Creates a new backend instance from the class loading with the given key
    # @param key The key that identifies the backend. Typically 'yaml' or 'json'
    # @return The created backend instance
    def self.new_backend(key)
      self.backend_class(key).new()
    end

    # Read data for the given module_dir and source. The value of the contained hash may
    # contain numbers, strings, true, false, nil, arrays, and hashes. It can be nested to
    # any depth. All strings may contain puppet-style interpolations, i.e. ${var}. This applies
    # to strings in nested structures as well.
    #
    # @param module_dir [String] The module directory
    # @source [String] The source (as specified in the configuration hierarchy)
    # @return [Hash<String,Object>] the hash, possibly empty but never nil
    #
    def read_data(module_dir, source)
      raise NoMethodError, 'read_data'
    end

    private

    # @param key [String] key that identifies the backend
    # @return [Class] the backend class for the given key
    def self.backend_class(key)
      Puppet::Pops::Binder::Hiera2.const_get(backend_class_name(key), false)
    end

    # @param key [String] key that identifies the backend
    # @return [String] the unqualified name of the backend class for the given key
    def self.backend_class_name(key)
      "#{key.capitalize}_backend"
    end

    # Check if the given class implements the Backend API
    #
    # @param backend_class [Class] The class to check
    # @return true if the given class implements the methods needed to be a backend
    def self.has_backend_api?(backend_class)
      begin
        backend_class.instance_method('read_data').parameters.length == 2
      rescue NameError
        false
      end
    end
  end
end
