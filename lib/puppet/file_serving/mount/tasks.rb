require 'puppet/file_serving/mount'

class Puppet::FileServing::Mount::Tasks < Puppet::FileServing::Mount
  def find(path, request)
    raise _("No task specified") if path.to_s.empty?
    module_name, task_path = path.split("/", 2)
    mod = request.environment.module(module_name)
    return nil unless mod

    mod.task_file(task_path)
  end

  def search(path, request)
    result = find(path, request)
    if result
      [result]
    end
  end

  def valid?
    true
  end
end
