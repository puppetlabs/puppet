require 'puppet/module'

module Puppet::Parser::Files

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
  # return it directly. If that fails try to find it as a file in a
  # module.
  # In either case, an absolute path is returned, which does not
  # necessarily refer to an existing file
  #
  # @api private
  def find_file(file, environment)
    if Puppet::Util.absolute_path?(file)
      file
    else
      path, module_file = split_file_path(file)
      mod = environment.module(path)

      if module_file && mod
        mod.file(module_file)
      else
        nil
      end
    end
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
    if Puppet::Util.absolute_path?(template)
      template
    else
      in_templatepath = find_template_in_templatepath(template, environment)
      if in_templatepath
        in_templatepath
      else
        find_template_in_module(template, environment)
      end
    end
  end

  def find_template_in_templatepath(template, environment)
    # templatepaths are deprecated functionality
    template_paths = templatepath(environment)
    if template_paths
      template_paths.collect do |path|
        File::join(path, template)
      end.find do |f|
        Puppet::FileSystem.exist?(f)
      end
    else
      nil
    end
  end

  # @api private
  def find_template_in_module(template, environment)
    path, file = split_file_path(template)
    mod = environment.module(path)

    if file && mod
      mod.template(file)
    else
      nil
    end
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
end
