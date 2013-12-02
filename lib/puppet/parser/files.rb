require 'puppet/module'

module Puppet; module Parser; module Files

  module_function

  # Return a list of manifests as absolute filenames matching the given 
  # pattern.
  #
  # @param pattern [String] A reference for a file in a module. It is the format "<modulename>/<file glob>"
  # @param environment [Puppet::Node::Environment] the environment of modules
  #
  # @return [Array(String, Array<String>)] the module name and the list of files found
  # @api private
  def find_manifests_in_modules(pattern, environment)
    module_name, file_pattern = split_file_path(pattern)
    begin
      if mod = Puppet::Module.find(module_name, environment)
        return [mod.name, mod.match_manifests(file_pattern)]
      end
    rescue Puppet::Module::InvalidName
      # one of the modules being loaded might have an invalid name and so
      # looking for one might blow up since we load them lazily.
    end
    [nil, []]
  end

  # Find the concrete file denoted by +file+. If +file+ is absolute,
  # return it directly. Otherwise try to find relative to the +templatedir+
  # config param.  If that fails try to find it as a template in a
  # module.
  # In all cases, an absolute path is returned, which does not
  # necessarily refer to an existing file
  def find_template(template, environment = nil)
    if template == File.expand_path(template)
      return template
    end

    if template_paths = templatepath(environment)
      # If we can find the template in :templatedir, we return that.
      template_paths.collect { |path|
        File::join(path, template)
      }.each do |f|
        return f if Puppet::FileSystem::File.exist?(f)
      end
    end

    # check in the default template dir, if there is one
    if td_file = find_template_in_module(template, environment)
      return td_file
    end

    nil
  end

  def find_template_in_module(template, environment = nil)
    path, file = split_file_path(template)

    # Because templates don't have an assumed template name, like manifests do,
    # we treat templates with no name as being templates in the main template
    # directory.
    return nil unless file

    if mod = Puppet::Module.find(path, environment) and t = mod.template(file)
      return t
    end
    nil
  end

  # Return an array of paths by splitting the +templatedir+ config
  # parameter.
  def templatepath(environment = nil)
    dirs = Puppet.settings.value(:templatedir, environment).split(File::PATH_SEPARATOR)
    dirs.select do |p|
      File::directory?(p)
    end
  end

  # Split the path into the module and the rest of the path, or return
  # nil if the path is empty or absolute (starts with a /).
  def split_file_path(path)
    if path == "" or Puppet::Util.absolute_path?(path)
      nil
    else
      path.split(File::SEPARATOR, 2)
    end
  end

end; end; end
