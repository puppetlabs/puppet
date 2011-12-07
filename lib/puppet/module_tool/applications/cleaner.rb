module Puppet::Module::Tool
  module Applications
    class Cleaner < Application
      def run
        Puppet::Module::Tool::Cache.clean

        # Return a status Hash containing the status of the clean command
        # and a status message. This return value is used by the module_tool
        # face clean action, and the status message, return_value[:msg], is
        # displayed on the console.
        #
        { :status => "success", :msg => "Cleaned module cache." }
      end
    end
  end
end
