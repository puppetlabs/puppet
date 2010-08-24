Puppet::Type.newtype(:stage) do
  desc "A resource type for specifying run stages.  The actual stage should
  be specified on resources:
      
      class { foo: stage => pre }

  And you must manually control stage order:

      stage { pre: before => Stage[main] }

  You automatically get a 'main' stage created, and by default all resources
  get inserted into that stage.

  You can only set stages on class resources, not normal builtin resources."

  newparam :name do
    desc "The name of the stage. This will be used as the 'stage' for each resource."
  end
end
