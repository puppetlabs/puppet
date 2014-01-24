require 'puppet/util/methodhelper'

module Puppet::ModuleTool
  # = Metadata
  #
  # This class provides a data structure representing a module's metadata.
  # It provides some basic parsing, but other data is injected into it using
  # +annotate+ methods in other classes.
  class Metadata
    include Puppet::Util::MethodHelper

    # The full name of the module, which is a dash-separated combination of the
    # +username+ and module +name+.
    attr_reader :full_module_name

    # The name of the user that owns this module.
    attr_reader :username

    # The name of this module. See also +full_module_name+.
    attr_reader :name

    # The version of this module.
    attr_reader :version

    # Instantiate from a hash, whose keys are setters in this class.
    def initialize(settings={})
      if settings.include?('name')
        # Act as the reverse of to_hash method (settings typically stems from the metadata.json file)
        if settings.include?('full_module_name') || settings.include?('username')
          raise ArgumentError, "Parameter 'name' cannot be used in conjunction with 'full_module_name' or 'username'"
        end
        self.full_module_name = settings['name']
        settings = settings.reject {|k,v| k == 'name'}
      end
      set_options(settings)
    end

    # Set the full name of this module, and from it, the +username+ and
    # module +name+.
    def full_module_name=(full_module_name)
      @full_module_name = full_module_name
      @username, @name = Puppet::ModuleTool::username_and_modname_from(full_module_name)
    end

    # Return an array of the module's Dependency objects.
    def dependencies
      return @dependencies ||= []
    end

    def dependencies=(dependencies)
      return @dependencies = dependencies
    end

    def author
      @author || @username
    end

    def author=(author)
      @author = author
    end

    def source
      @source || 'UNKNOWN'
    end

    def source=(source)
      @source = source
    end

    def license
      @license || 'Apache License, Version 2.0'
    end

    def license=(license)
      @license = license
    end

    def summary
      @summary || 'UNKNOWN'
    end

    def summary=(summary)
      @summary = summary
    end

    def description
      @description || 'UNKNOWN'
    end

    def description=(description)
      @description = description
    end

    def project_page
      @project_page || 'UNKNOWN'
    end

    def project_page=(project_page)
      @project_page = project_page
    end

    # Return an array of the module's Puppet types, each one is a hash
    # containing :name and :doc.
    # This is deprecated. Types are now longer stored in metadata.
    def types
      return @types ||= []
    end

    # Deprecated but needed in order to read legacy metadata
    def types=(types)
      @types = types
    end

    # Return module's file checksums.
    # This is deprecated. Checksums are now stored in 'checksums.json'
    def checksums
      return @checksums ||= {}
    end

    # Deprecated but needed in order to read legacy metadata
    def checksums=(checksums)
      @checksums = checksums
    end

    # Return the dashed name of the module, which may either be the
    # dash-separated combination of the +username+ and module +name+, or just
    # the module +name+.
    def dashed_name
      return [@username, @name].compact.join('-')
    end

    # Return the release name, which is the combination of the +dashed_name+
    # of the module and its +version+ number.
    def release_name
      return [dashed_name, @version].join('-')
    end

    # Set the version of this module, ensure a string like '0.1.0' see the
    # Semantic Versions here: http://semver.org
    def version=(version)
      if SemVer.valid?(version)
        @version = version
      else
        raise ArgumentError, "Invalid version format: #{@version} (Semantic Versions are acceptable: http://semver.org)"
      end
    end

    def to_data_hash()
      return {
        'name'         => @full_module_name,
        'version'      => @version,
        'source'       => source,
        'author'       => author,
        'license'      => license,
        'summary'      => summary,
        'description'  => description,
        'project_page' => project_page,
        'dependencies' => dependencies
      }
    end

    def to_hash()
      to_data_hash
    end

    # Return the PSON record representing this instance.
    def to_pson(*args)
      return to_data_hash.to_pson(*args)
    end
  end
end
