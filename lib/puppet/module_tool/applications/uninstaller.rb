module Puppet::Module::Tool
  module Applications
    class Uninstaller < Application

      def initialize(name, options = {})
        @name = name
        @target_directories = options[:target_directories]
        @removed_dirs = []
      end

      def run
        uninstall
        Puppet.notice "#{@name} is not installed" if @removed_dirs.empty?
        @removed_dirs
      end

      private

      def uninstall
        # TODO: #11803 Check for broken dependencies before uninstalling modules.
        #
        # Search each path in the target directories for the specified module
        # and delete the directory.
        @target_directories.each do |target|
          if File.directory? target
            module_path = File.join(target, @name)
            @removed_dirs << FileUtils.rm_rf(module_path).first if File.directory?(module_path)
          end
        end
      end
    end
  end
end
