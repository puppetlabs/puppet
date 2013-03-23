module Puppet::Parser::Functions
  newfunction(:hiera_hash, :type => :rvalue, :arity => -2, :doc => <<-'ENDHEREDOC') do |*args|
    Returns a hash of all values that match a given key, performing a shallow merge on the hashes
    
    This function takes one mandatory argument, a key name:
    
        # Perform an explicit hiera lookup
        $myhash = hiera_hash(klass::myhash)
    
    A second, optional parameter may be given to supply a default value to be used if the key is not found.
    
        # Perform an explicit hiera lookup with a supplied defualt
        $myhash = hiera_hash(klass::myhash, { key1 => 'default1', key2 => 'default2' } )
    
    A third, optional parameter may also be given to override the hiearchy. If you are only using the yaml backend,
    then the following will cause this lookup to first look in the `site_overrides.yaml` file in the hieradata location:
    
        # Perform an explicit hiera lookup with a supplied default and an override
        $myhash = hiera_hash(klass::myhash , { key1 => 'default1', key2 => 'default2' }, 'site_overrides')
    
  ENDHEREDOC
    require 'hiera_puppet'
    key, default, override = HieraPuppet.parse_args(args)
    HieraPuppet.lookup(key, default, self, override, :hash)
  end
end

