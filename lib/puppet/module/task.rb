require 'puppet/util/logging'

class Puppet::Module
  class Task
    class Error < Puppet::Error; end
    class InvalidName < Error; end
    class InvalidFile < Error; end
    class TaskNotFound < Error; end

    FORBIDDEN_EXTENSIONS = %w{.conf .md}

    def self.is_task_name?(name)
      return true if name =~ /^[a-z][a-z0-9_]*$/
      return false
    end

    # Determine whether a file has a legal name for either a task's executable or metadata file.
    def self.is_tasks_filename?(path)
      name_less_extension = File.basename(path, '.*')
      return false if not is_task_name?(name_less_extension)
      FORBIDDEN_EXTENSIONS.each do |ext|
        return false if path.end_with?(ext)
      end
      return true
    end

    def self.is_tasks_metadata_filename?(name)
      is_tasks_filename?(name) && name.end_with?('.json')
    end

    def self.is_tasks_executable_filename?(name)
      is_tasks_filename?(name) && !name.end_with?('.json')
    end

    def self.tasks_in_module(pup_module)
      Dir.glob(File.join(pup_module.tasks_directory, '*'))
        .keep_if { |f| is_tasks_filename?(f) }
        .group_by { |f| task_name_from_path(f) }
        .map { |task, files| new_with_files(pup_module, task, files) }
    end

    attr_reader :name, :module, :metadata_file, :files

    def initialize(pup_module, task_name, files, metadata_file = nil)
      if !Puppet::Module::Task.is_task_name?(task_name)
        raise InvalidName, _("Task names must start with a lowercase letter and be composed of only lowercase letters, numbers, and underscores")
      end

      all_files = metadata_file.nil? ? files : files + [metadata_file]
      all_files.each do |f|
        if !f.start_with?(pup_module.tasks_directory)
          msg = _("The file '%{path}' is not located in the %{module_name} module's tasks directory") %
                       {path: f.to_s, module_name: pup_module.name}

          # we can include some extra context for the log message:
          Puppet.err(msg + " (#{pup_module.tasks_directory})")
          raise InvalidFile, msg
        end
      end

      name = task_name == "init" ? pup_module.name : "#{pup_module.name}::#{task_name}"

      @module = pup_module
      @name = name
      @metadata_file = metadata_file if metadata_file
      @files = files
    end

    def ==(other)
      self.name == other.name &&
      self.module == other.module
    end

    def self.new_with_files(pup_module, name, tasks_files)
      files = tasks_files.map do |filename|
        File.join(pup_module.tasks_directory, File.basename(filename))
      end

      metadata_files, exe_files = files.partition { |f| is_tasks_metadata_filename?(f) }
      Puppet::Module::Task.new(pup_module, name, exe_files, metadata_files.first)
    end
    private_class_method :new_with_files

    def self.task_name_from_path(path)
      return File.basename(path, '.*')
    end
    private_class_method :task_name_from_path
  end
end
