# Created on 2008-02-12
# Copyright Luke Kanies

# A common module for converting between constants and
# file names.
module Puppet::Util::ConstantInflector
    def file2constant(file)
        file.split("/").collect { |name| name.capitalize }.join("::").gsub(/_+(.)/) { |term| $1.capitalize }
    end

    def constant2file(constant)
        constant.to_s.gsub(/([a-z])([A-Z])/) { |term| $1 + "_" + $2 }.gsub("::", "/").downcase
    end
end
