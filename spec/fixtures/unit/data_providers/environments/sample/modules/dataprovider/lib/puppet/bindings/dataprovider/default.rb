# This registers the default bindings for this module.
# These bidnings are loaded at the start of a Puppet
# catalog production.
# 
# The registrations makes 'sample' available as both a
# data provider for an environment, and individually
# selectable in modules.
#
# Note that there are two different implementation classes
# registered, one for environment, and one for modules.
#
# Also note that all data are strings including the names
# of the classes that implement the provider logic. This
# is to not cause loading of those classes until they
# are needed.
#
Puppet::Bindings.newbindings('dataprovider::default') do

  # Make the SampleEnvData provider available for use in environments
  # as 'sample'.
  #
  bind {
    name 'sample'
    in_multibind 'puppet::environment_data_providers'
    to_instance 'PuppetX::Helindbe::SampleEnvData'
  }

  # Make the SampleModuleData provider available for use in environments
  # as 'sample'.
  #
  bind {
    name 'sample'
    in_multibind 'puppet::module_data_providers'
    to_instance 'PuppetX::Helindbe::SampleModuleData'
  }

  # This is what users of the 'sample' module data provider should
  # use in its default.rb bindings. The module providing the implementation
  # of this data provider typically does not have any puppet logic, so it
  # would not have this binding. This example module has this however since
  # it would otherwise require an additional module with just some puppet code
  # and this binding to demonstrate the functionality.
  #
  # This binding declares that this module wants to use the 'sample' data provider
  # for this module. (Thus ending up using the SampleModuleData implementation
  # bound above in this example).
  # 
  bind {
    name 'dataprovider'
    to 'sample'
    in_multibind 'puppet::module_data'
  }
end

