require 'puppet/file_serving/mount'

class Puppet::FileServing::Mount::Tasks < Puppet::FileServing::Mount
  def find(path, request)
    raise _("No task specified") if path.to_s.empty?
    module_name, task_path = path.split("/", 2)
    return nil unless mod = request.environment.module(module_name)

    mod.task_file(task_path)
  end

  def search(path, request)
    if result = find(path, request)
      [result]
    end
  end

  def valid?
    true
  end
end
