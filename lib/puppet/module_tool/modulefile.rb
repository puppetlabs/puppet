module Puppet::Module::Tool

  # = Modulefile
  #
  # This class provides the DSL used for evaluating the module's 'Modulefile'.
  # These methods are used to concisely define this module's attributes, which
  # are later rendered as PSON into a 'metadata.json' file.
  class ModulefileReader

    # Read the +filename+ and eval its Ruby code to set values in the Metadata
    # +metadata+ instance.
    def self.evaluate(metadata, filename)
      returning(new(metadata)) do |builder|
        if File.file?(filename)
          builder.instance_eval(File.read(filename.to_s), filename.to_s, 1)
        else
          Puppet.warning "No Modulefile: #{filename}"
        end
      end
    end

    # Instantiate with the Metadata +metadata+ instance.
    def initialize(metadata)
      @metadata = metadata
    end

    # Set the +full_module_name+ (e.g. "myuser-mymodule"), which will also set the
    # +username+ and module +name+. Required.
    def name(name)
      @metadata.full_module_name = name
    end

    # Set the module +version+ (e.g., "0.0.1"). Required.
    def version(version)
      @metadata.version = version
    end

    # Add a dependency with the full_module_name +name+ (e.g. "myuser-mymodule"), an
    # optional +version_requirement+ (e.g. "0.0.1") and +repository+ (a URL
    # string). Optional. Can be called multiple times to add many dependencies.
    def dependency(name, version_requirement = nil, repository = nil)
      @metadata.dependencies << Dependency.new(name, version_requirement, repository)
    end

    # Set the source
    def source(source)
      @metadata.source = source
    end

    # Set the author or default to +username+
    def author(author)
        @metadata.author = author
    end

    # Set the license
    def license(license)
      @metadata.license = license
    end

   # Set the summary
   def summary(summary)
      @metadata.summary = summary
    end

   # Set the description
   def description(description)
      @metadata.description = description
   end

   # Set the project page
   def project_page(project_page)
      @metadata.project_page = project_page
    end
  end
end
