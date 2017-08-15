class Puppet::InfoService::TaskInformationService
  require 'puppet/module'

  def self.tasks_per_environment(environment_name)
    # get the actual environment object, raise error if the named env doesn't exist
    env = Puppet.lookup(:environments).get!(environment_name)
    env.modules.map do |mod|
      mod.tasks.map do |task|
        {:module => {:name => task.module.name}, :name => task.name}
      end
    end.flatten
  end

  def self.task_data(environment_name, module_name, task_name)
    # raise EnvironmentNotFound if applicable
    Puppet.lookup(:environments).get!(environment_name)

    pup_module = Puppet::Module.find(module_name, environment_name)
    if pup_module.nil?
      raise Puppet::Module::MissingModule, _("Module %{module_name} not found in environment %{environment_name}.") %
                                            {module_name: module_name, environment_name: environment_name}
    end

    task = pup_module.tasks.find { |t| t.name == task_name }
    if task.nil?
      raise Puppet::Module::Task::TaskNotFound, _("Task %{task_name} not found in module %{module_name}.") %
                                                 {task_name: task_name, module_name: module_name}
    end

    {:metadata_file => task.metadata_file, :files => task.files}
  end
end
