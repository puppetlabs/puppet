class Puppet::Provider::Command
  attr_reader :executable

  def initialize(executable, options = {})
    @executable = executable
    @options = options
  end

  def execute(name, resolver, executor, *args)
    resolved_executable = resolver.which(@executable) or raise Puppet::Error, "Command #{name} is missing"
    executor.execute([resolved_executable] + args, @options)
  end
end
