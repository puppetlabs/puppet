module Puppet::Parser::Functions
  newfunction(:hiera_array, :type => :rvalue, :arity => -2, :doc => <<-'ENDHEREDOC') do |*args|
    Returns an array of all values that match the given key.
    
    This function takes one mandatory argument, a key name. To make use of the databindings
    feature available in Pupept 3.0.0 and newer, use a key of the format `klass::paramater`:
    
        # Perform an explicit hiera lookup
        $myarray = hiera_array('some_array')
    
    A second, optional parameter may be given to supply a default value to be used if the key is not found.
    
        # Perform an explicit hiera lookup with a supplied defualt
        $myarray = hiera('some_array', [ 'default1', 'default2' ])
    
    A third, optional parameter may also be given to override the hiearchy. If you are only using the yaml backend,
    then the following will cause this lookup to first look in the `site_overrides.yaml` file in the hieradata location:
    
        # Perform an explicit hiera lookup with a supplied default and an override
        $myarray = hiera('some_array' , [ 'default1', 'default2' ], 'site_overrides')
    
  ENDHEREDOC
    require 'hiera_puppet'
    key, default, override = HieraPuppet.parse_args(args)
    HieraPuppet.lookup(key, default, self, override, :array)
  end
end

