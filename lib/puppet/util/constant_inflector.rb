# Created on 2008-02-12
# Copyright Luke Kanies

# NOTE: I think it might be worth considering moving these methods directly into Puppet::Util.

# A common module for converting between constants and
# file names.


module Puppet
  module Util
    module ConstantInflector
      def file2constant(file)
        file.split("/").collect { |name| name.capitalize }.join("::").gsub(/_+(.)/) { |term| $1.capitalize }
      end
      module_function :file2constant

      def constant2file(constant)
        constant.to_s.gsub(/([a-z])([A-Z])/) { |term| $1 + "_#{$2}" }.gsub("::", "/").downcase
      end
      module_function :constant2file
    end
  end
end
