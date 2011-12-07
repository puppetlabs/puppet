module Puppet::Module::Tool

  # = Metadata
  #
  # This class provides a data structure representing a module's metadata.
  # It provides some basic parsing, but other data is injected into it using
  # +annotate+ methods in other classes.
  class Metadata

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
      settings.each do |key, value|
        send("#{key}=", value)
      end
    end

    # Set the full name of this module, and from it, the +username+ and
    # module +name+.
    def full_module_name=(full_module_name)
      @full_module_name = full_module_name
      @username, @name = Puppet::Module::Tool::username_and_modname_from(full_module_name)
    end

    # Return an array of the module's Dependency objects.
    def dependencies
      return @dependencies ||= []
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
    def types
      return @types ||= []
    end

    # Return module's file checksums.
    def checksums
      return @checksums ||= {}
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

    # Return the PSON record representing this instance.
    def to_pson(*args)
      return {
        :name         => @full_module_name,
        :version      => @version,
        :source       => source,
        :author       => author,
        :license      => license,
        :summary      => summary,
        :description  => description,
        :project_page => project_page,
        :dependencies => dependencies,
        :types        => types,
        :checksums    => checksums
      }.to_pson(*args)
    end
  end
end
