require 'puppet'
# The CompilableResourceType module should be either included in a class or used as a class extension
# to mark that the instance used as the 'resource type' of a resource instance
# is an object that is compatible with Puppet::Type's API wrt. compiling.
# Puppet Resource Types written in Ruby use a meta programmed Ruby Class as the type. Those classes
# are subtypes of Puppet::Type. Meta data (Pcore/puppet language) based resource types uses instances of
# a class instead.
# 
module Puppet::CompilableResourceType
  # All 3.x resource types implemented in Ruby using Puppet::Type respond true.
  # Other kinds of implementations should reimplement and return false.
  def is_3x_ruby_plugin?
    true
  end
end