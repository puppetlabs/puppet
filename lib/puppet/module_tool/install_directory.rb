require 'puppet/module_tool'
require 'puppet/module_tool/errors'

module Puppet
  module ModuleTool
    # Control the install location for modules.
    class InstallDirectory
      include Puppet::ModuleTool::Errors

      attr_reader :target
      def initialize(target)
        @target = target
      end

      # prepare the module install location. This will create the location if
      # needed.
      def prepare(module_name, version)
        return if @target.directory?

        begin
          @target.mkpath
          Puppet.notice _("Created target directory %{dir}") % { dir: @target }
        rescue SystemCallError => orig_error
          raise converted_to_friendly_error(module_name, version, orig_error)
        end
      end

    private

      ERROR_MAPPINGS = {
        Errno::EACCES => PermissionDeniedCreateInstallDirectoryError,
        Errno::EEXIST => InstallPathExistsNotDirectoryError,
      }

      def converted_to_friendly_error(module_name, version, orig_error)
        return orig_error if not ERROR_MAPPINGS.include?(orig_error.class)

        ERROR_MAPPINGS[orig_error.class].new(orig_error,
          :requested_module  => module_name,
          :requested_version => version,
          :directory         => @target.to_s)
      end
    end
  end
end
