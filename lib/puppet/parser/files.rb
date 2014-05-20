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
      if mod = environment.module(module_name)
        return [mod.name, mod.match_manifests(file_pattern)]
      end
    rescue Puppet::Module::InvalidName
      # one of the modules being loaded might have an invalid name and so
      # looking for one might blow up since we load them lazily.
    end
    [nil, []]
  end

  # Find the concrete file denoted by +file+. If +file+ is absolute,
  # return it directly. If that fails try to find it as a template in a
  # module.
  # In either case, an absolute path is returned, which does not
  # necessarily refer to an existing file
  #
  # @api private
  def find_file(file, environment)
    # if +file+ is absolute, return it directly
    if file == File.expand_path(file)
      return template
    end

    # check in the module's file dir, if there is one
    if module_file = find_file_in_module(file, environment)
      return module_file
    end

    nil
  end

  # @api private
  def find_file_in_module(file, environment)
    path, module_file = split_file_path(file)

    # Because files don't have an assumed file name, like manifests do,
    # we treat files with no name as being files in the main template
    # directory.
    # if there's no module_file then +file+ doesn't describe a file in
    # a module.
    return nil unless module_file

    if mod = environment.module(path) and f = mod.file(module_file)
      return f
    end
    nil
  end

  # Find the concrete file denoted by +file+. If +file+ is absolute,
  # return it directly. Otherwise try to find relative to the +templatedir+
  # config param.  If that fails try to find it as a template in a
  # module.
  # In all cases, an absolute path is returned, which does not
  # necessarily refer to an existing file
  #
  # @api private
  def find_template(template, environment)
    if template == File.expand_path(template)
      return template
    end

    if template_paths = templatepath(environment)
      # If we can find the template in :templatedir, we return that.
      template_paths.collect { |path|
        File::join(path, template)
      }.each do |f|
        return f if Puppet::FileSystem.exist?(f)
      end
    end

    # check in the default template dir, if there is one
    if td_file = find_template_in_module(template, environment)
      return td_file
    end

    nil
  end

  # @api private
  def find_template_in_module(template, environment)
    path, file = split_file_path(template)

    # Because templates don't have an assumed template name, like manifests do,
    # we treat templates with no name as being templates in the main template
    # directory.
    return nil unless file

    if mod = environment.module(path) and t = mod.template(file)
      return t
    end
    nil
  end

  # Return an array of paths by splitting the +templatedir+ config
  # parameter.
  # @api private
  def templatepath(environment)
    dirs = Puppet.settings.value(:templatedir, environment.to_s).split(File::PATH_SEPARATOR)
    dirs.select do |p|
      File::directory?(p)
    end
  end

  # Split the path into the module and the rest of the path, or return
  # nil if the path is empty or absolute (starts with a /).
  # @api private
  def split_file_path(path)
    if path == "" or Puppet::Util.absolute_path?(path)
      nil
    else
      path.split(File::SEPARATOR, 2)
    end
  end

end; end; end
