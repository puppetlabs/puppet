module Puppet::ModuleTool

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
      @paths ||= [ home_path, custom_path, default_path ]
    end

    # Return Pathname of custom templates directory.
    def custom_path
      Pathname(Puppet.settings[:module_working_dir]) + 'skeleton'
    end

    # Return Pathname of default template directory.
    def default_path
      Pathname(__FILE__).dirname + 'skeleton/templates/generator'
    end

    # Return settings from ~/.puppet-template/config
    def generate_settings
      file = ENV['HOME'] + '/.puppet-module-tool/config'
      if File.exist?(file)
        text = File.read(file)
        Hash[text.scan(/^\s*(\w+)\s*=\s*(.*?)\s*$/)]
      end
    end

    # Return path name of custom skeleton based on the homedir of the user
    def home_path
      Pathname(ENV['HOME'] + '/.puppet-module-tool/skeleton')
    end

  end
end
