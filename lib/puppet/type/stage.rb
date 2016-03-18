Puppet::Type.newtype(:stage) do
  desc "A resource type for creating new run stages.  Once a stage is available,
    classes can be assigned to it by declaring them with the resource-like syntax
    and using
    [the `stage` metaparameter](https://docs.puppetlabs.com/puppet/latest/reference/metaparameter.html#stage).

    Note that new stages are not useful unless you also declare their order
    in relation to the default `main` stage.

    A complete run stage example:

        stage { 'pre':
          before => Stage['main'],
        }

        class { 'apt-updates':
          stage => 'pre',
        }

    Individual resources cannot be assigned to run stages; you can only set stages
    for classes."

  newparam :name do
    desc "The name of the stage. Use this as the value for the `stage` metaparameter
      when assigning classes to this stage."
  end
end
