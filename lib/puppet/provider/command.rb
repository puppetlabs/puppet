class Puppet::Provider::Command
  def initialize(executable, options = {})
    @executable = executable
    @options = options
  end

  def execute(executor)
    executor.execute([@executable], @options)
  end
end
