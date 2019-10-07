class Puppet::InfoService::PlanInformationService
  require 'puppet/module'

  def self.plans_per_environment(environment_name)
    # get the actual environment object, raise error if the named env doesn't exist
    env = Puppet.lookup(:environments).get!(environment_name)
    env.modules.map do |mod|
      mod.plans.map do |plan|
        {:module => {:name => plan.module.name}, :name => plan.name}
      end
    end.flatten
  end

  def self.plan_data(environment_name, module_name, plan_name)
    # raise EnvironmentNotFound if applicable
    Puppet.lookup(:environments).get!(environment_name)

    pup_module = Puppet::Module.find(module_name, environment_name)
    if pup_module.nil?
      raise Puppet::Module::MissingModule, _("Module %{module_name} not found in environment %{environment_name}.") %
                                            {module_name: module_name, environment_name: environment_name}
    end

    plan = pup_module.plans.find { |t| t.name == plan_name }
    if plan.nil?
      raise Puppet::Module::Plan::PlanNotFound.new(plan_name, module_name)
    end

    begin
      plan.validate
      {:metadata => plan.metadata, :files => plan.files}
    rescue Puppet::Module::Plan::Error => err
      { :metadata => nil, :files => [], :error => err.to_h }
    end
  end
end
