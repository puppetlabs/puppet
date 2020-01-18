module PuppetSpec::Modules
  class << self
    def create(name, dir, options = {})
      module_dir = File.join(dir, name)
      FileUtils.mkdir_p(module_dir)

      environment = options[:environment]

      metadata = options[:metadata]
      if metadata
        metadata[:source]  ||= 'github'
        metadata[:author]  ||= 'puppetlabs'
        metadata[:version] ||= '9.9.9'
        metadata[:license] ||= 'to kill'
        metadata[:dependencies] ||= []

        metadata[:name] = "#{metadata[:author]}-#{name}"

        File.open(File.join(module_dir, 'metadata.json'), 'w') do |f|
          f.write(metadata.to_json)
        end
      end

      tasks = options[:tasks]
      if tasks
        tasks_dir = File.join(module_dir, 'tasks')
        FileUtils.mkdir_p(tasks_dir)
        tasks.each do |task_files|
          task_files.each do |task_file|
            if task_file.is_a?(String)
              # default content to acceptable metadata
              task_file = { :name => task_file, :content => "{}" }
            end
            File.write(File.join(tasks_dir, task_file[:name]), task_file[:content])
          end
        end
      end

      if plans = options[:plans]
        plans_dir = File.join(module_dir, 'plans')
        FileUtils.mkdir_p(plans_dir)
        plans.each do |plan_file|
          if plan_file.is_a?(String)
            # default content to acceptable metadata
            plan_file = { :name => plan_file, :content => "{}" }
          end
          File.write(File.join(plans_dir, plan_file[:name]), plan_file[:content])
        end
      end

      (options[:files] || {}).each do |fname, content|
        path = File.join(module_dir, fname)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, content)
      end

      Puppet::Module.new(name, module_dir, environment)
    end

    def generate_files(name, dir, options = {})
      module_dir = File.join(dir, name)
      FileUtils.mkdir_p(module_dir)

      if metadata = options[:metadata]
        File.open(File.join(module_dir, 'metadata.json'), 'w') do |f|
          f.write(metadata.to_json)
        end
      end
    end
  end
end
