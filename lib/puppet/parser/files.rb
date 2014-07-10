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

  # Find the path to the given file selector. Files can be selected in
  # one of two ways:
  #   * absolute path: the path is simply returned
  #   * modulename/filename selector: a file is found in the file directory
  #     of the named module.
  #
  # In the second case a nil is returned if there isn't a file found. In the
  # first case (absolute path), there is no existence check done and so the
  # path will be returned even if there isn't a file available.
  #
  # @param template [String] the file selector
  # @param environment [Puppet::Node::Environment] the environment in which to search
  # @return [String, nil] the absolute path to the file or nil if there is no file found
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

  # Find the path to the given template selector. Templates can be selected in
  # a number of ways:
  #   * absolute path: the path is simply returned
  #   * path relative to the templatepath setting: a file is found and the path
  #     is returned
  #   * modulename/filename selector: a file is found in the template directory
  #     of the named module.
  #
  # In the last two cases a nil is returned if there isn't a file found. In the
  # first case (absolute path), there is no existence check done and so the
  # path will be returned even if there isn't a file available.
  #
  # @param template [String] the template selector
  # @param environment [Puppet::Node::Environment] the environment in which to search
  # @return [String, nil] the absolute path to the template file or nil if there is no file found
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

  # Templatepaths are deprecated functionality, this will be going away in
  # Puppet 4.
  #
  # @api private
  def find_template_in_templatepath(template, environment)
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
    if path == "" || Puppet::Util.absolute_path?(path)
      nil
    else
      path.split(File::SEPARATOR, 2)
    end
  end
end
