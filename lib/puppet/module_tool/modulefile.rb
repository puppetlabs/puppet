require 'puppet/module_tool'
require 'puppet/module_tool/dependency'

module Puppet::ModuleTool

  # = Modulefile
  #
  # This class provides the DSL used for evaluating the module's 'Modulefile'.
  # These methods are used to concisely define this module's attributes, which
  # are later rendered as PSON into a 'metadata.json' file.
  class ModulefileReader

    # Read the +filename+ and eval its Ruby code to set values in the Metadata
    # +metadata+ instance.
    def self.evaluate(metadata, filename)
      builder = new(metadata)
      if File.file?(filename)
        builder.instance_eval(File.read(filename.to_s), filename.to_s, 1)
      else
        Puppet.warning "No Modulefile: #{filename}"
      end
      return builder
    end

    # Instantiate with the Metadata +metadata+ instance.
    def initialize(metadata)
      @metadata = metadata
    end

    # Set the +full_module_name+ (e.g. "myuser-mymodule"), which will also set the
    # +username+ and module +name+. Required.
    def name(name)
      @metadata.update('name' => name)
    end

    # Set the module +version+ (e.g., "0.1.0"). Required.
    def version(version)
      @metadata.update('version' => version)
    end

    # Add a dependency with the full_module_name +name+ (e.g. "myuser-mymodule"), an
    # optional +version_requirement+ (e.g. "0.1.0") and +repository+ (a URL
    # string). Optional. Can be called multiple times to add many dependencies.
    def dependency(name, version_requirement = nil, repository = nil)
      @metadata.add_dependency(name, version_requirement, repository)
    end

    # Set the source
    def source(source)
      @metadata.update('source' => source)
    end

    # Set the author or default to +username+
    def author(author)
      @metadata.update('author' => author)
    end

    # Set the license
    def license(license)
      @metadata.update('license' => license)
    end

    # Set the summary
    def summary(summary)
      @metadata.update('summary' => summary)
    end

    # Set the description
    def description(description)
      @metadata.update('description' => description)
    end

    # Set the project page
    def project_page(project_page)
      @metadata.update('project_page' => project_page)
    end
  end
end
