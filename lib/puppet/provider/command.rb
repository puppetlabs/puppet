class Puppet::Provider::Command
  def initialize(executable, options = {})
    @executable = executable
    @options = options
  end

  def execute(executor, *args)
    executor.execute([@executable] + args, @options)
  end
end
