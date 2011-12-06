module Puppet::Module::Tool

  class Dependency

    # Instantiates a new module dependency with a +full_module_name+ (e.g.
    # "myuser-mymodule"), and optional +version_requirement+ (e.g. "0.0.1") and
    # optional repository (a URL string).
    def initialize(full_module_name, version_requirement = nil, repository = nil)
      @full_module_name = full_module_name
      # TODO: add error checking, the next line raises ArgumentError when +full_module_name+ is invalid
      @username, @name = Puppet::Module::Tool.username_and_modname_from(full_module_name)
      @version_requirement = version_requirement
      @repository = repository ? Repository.new(repository) : nil
    end

    # Return PSON representation of this data.
    def to_pson(*args)
      result = { :name => @full_module_name }
      result[:version_requirement] = @version_requirement if @version_requirement && ! @version_requirement.nil?
      result[:repository] = @repository.to_s if @repository && ! @repository.nil?
      result.to_pson(*args)
    end
  end
end
