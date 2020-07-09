# This file was automatically generated on 2020-07-09 16:08:52 -0700.
# Use the 'puppet generate types' command to regenerate this file.

Puppet::Resource::ResourceType3.new(
  'applytest',
  [
    Puppet::Resource::Param(Any, 'message')
  ],
  [
    # An arbitrary tag for your own reference; the name of the message.
    Puppet::Resource::Param(Any, 'name', true),

    # The specific backend to use for this `applytest`
    # resource. You will seldom need to specify this --- Puppet will usually
    # discover the appropriate provider for your platform.Available providers are:
    # 
    # ruby
    # :
    Puppet::Resource::Param(Any, 'provider')
  ],
  {
    /(?m-ix:(.*))/ => ['name']
  },
  true,
  false)
