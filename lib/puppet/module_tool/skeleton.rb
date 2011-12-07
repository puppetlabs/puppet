module Puppet::Module::Tool

  # = Skeleton
  #
  # This class provides methods for finding templates for the 'generate' action.
  class Skeleton

    # TODO Review whether the 'freeze' feature should be fixed or deleted.
    # def freeze!
    #   FileUtils.rm_fr custom_path rescue nil
    #   FileUtils.cp_r default_path, custom_path
    # end

    # Return Pathname with 'generate' templates.
    def path
      paths.detect { |path| path.directory? }
    end

    # Return Pathnames to look for 'generate' templates.
    def paths
      @paths ||= [ custom_path, default_path ]
    end

    # Return Pathname of custom templates directory.
    def custom_path
      Pathname(Puppet.settings[:module_working_dir]) + 'skeleton'
    end

    # Return Pathname of default template directory.
    def default_path
      Pathname(__FILE__).dirname + 'skeleton/templates/generator'
    end
  end
end
