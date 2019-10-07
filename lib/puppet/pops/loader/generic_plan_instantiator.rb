module Puppet::Pops
module Loader
# The GenericPlanInstantiator dispatches to either PuppetPlanInstantiator or a
# yaml_plan_instantiator injected through the Puppet context, depending on
# the type of the plan.
#
class GenericPlanInstantiator
  def self.create(loader, typed_name, source_refs)
    if source_refs.length > 1
      raise ArgumentError, _("Found multiple files for plan '%{plan_name}' but only one is allowed") % { plan_name: typed_name.name }
    end

    source_ref = source_refs[0]
    code_string = Puppet::FileSystem.read(source_ref, :encoding => 'utf-8')

    instantiator = if source_ref.end_with?('.pp')
                     Puppet::Pops::Loader::PuppetPlanInstantiator
                   else
                     Puppet.lookup(:yaml_plan_instantiator) do
                       raise Puppet::DevError, _("No instantiator is available to load plan from %{source_ref}") % { source_ref: source_ref }
                     end
                   end

    instantiator.create(loader, typed_name, source_ref, code_string)
  end
end
end
end
