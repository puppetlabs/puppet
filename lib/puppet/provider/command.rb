# A command that can be executed on the system
class Puppet::Provider::Command
  attr_reader :executable
  attr_reader :name

  # @param [String] name A way of referencing the name
  # @param [String] executable The path to the executable file
  # @param resolver An object for resolving the executable to an absolute path (usually Puppet::Util)
  # @param executor An object for performing the actual execution of the command (usually Puppet::Util::Execution)
  # @param [Hash] options Extra options to be used when executing (see Puppet::Util::Execution#execute)
  def initialize(name, executable, resolver, executor, options = {})
    @name = name
    @executable = executable
    @resolver = resolver
    @executor = executor
    @options = options
  end

  # @param args [Array<String>] Any command line arguments to pass to the executable
  # @return The output from the command
  def execute(*args)
    resolved_executable = @resolver.which(@executable) or raise Puppet::MissingCommand, _("Command %{name} is missing") % { name: @name }
    @executor.execute([resolved_executable] + args, @options)
  end
end
