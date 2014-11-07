module Puppet::Parser::Files

  module_function

  # Return a list of manifests as absolute filenames matching the given
  # pattern.
  #
  # @param pattern [String] A reference for a file in a module. It is the
  #   format "<modulename>/<file glob>"
  # @param environment [Puppet::Node::Environment] the environment of modules
  #
  # @return [Array(String, Array<String>)] the module name and the list of files found
  # @api private
  def find_manifests_in_modules(pattern, environment)
    module_name, file_pattern = split_file_path(pattern)

    if mod = environment.module(module_name)
      [mod.name, mod.match_manifests(file_pattern)]
    else
      [nil, []]
    end
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
    find_in_module(file, environment) do |mod,module_file|
      mod.file(module_file)
    end
  end

  # Find the path to the given template selector. Templates can be selected in
  # a couple of ways:
  #   * absolute path: the path is simply returned
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
    find_in_module(template, environment) do |mod,template_file|
      mod.template(template_file)
    end
  end

  # @api private
  def find_in_module(reference, environment)
    if Puppet::Util.absolute_path?(reference)
      reference
    else
      path, file = split_file_path(reference)
      mod = environment.module(path)

      if file && mod
        yield(mod, file)
      else
        nil
      end
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
