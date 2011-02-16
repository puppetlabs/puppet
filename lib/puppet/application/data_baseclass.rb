require 'puppet/application'
require 'puppet/interface'

class Puppet::Application::DataBaseclass < Puppet::Application
  should_parse_config
  run_mode :agent

  option("--debug", "-d") do |arg|
    Puppet::Util::Log.level = :debug
  end

  option("--verbose", "-v") do
    Puppet::Util::Log.level = :info
  end

  option("--from TERMINUS", "-f") do |arg|
    @from = arg
  end

  option("--format FORMAT") do |arg|
    @format = arg.to_sym
  end

  # XXX this doesn't work, I think
  option("--list") do
    indirections.each do |ind|
      begin
        classes = terminus_classes(ind.to_sym)
      rescue => detail
        $stderr.puts "Could not load terminuses for #{ind}: #{detail}"
        next
      end
      puts "%-30s: #{classes.join(", ")}" % ind
    end
    exit(0)
  end

  option("--mode RUNMODE", "-r") do |arg|
    raise "Invalid run mode #{arg}; supported modes are user, agent, master" unless %w{user agent master}.include?(arg)
    self.class.run_mode(arg.to_sym)
    set_run_mode self.class.run_mode
  end


  attr_accessor :interface, :from, :type, :verb, :name, :arguments, :indirection, :format

  def main
    # Call the method associated with the provided action (e.g., 'find').
    result = interface.send(verb, name, *arguments)
    render_method = Puppet::Network::FormatHandler.format(format).render_method
    puts result.send(render_method) if result
  end

  def setup

    Puppet::Util::Log.newdestination :console

    @verb, @name, @arguments = command_line.args
    @arguments ||= []

    @type = self.class.name.to_s.sub(/.+:/, '').downcase.to_sym

    @interface = Puppet::Interface.interface(@type).new
    @format ||= @interface.class.default_format || :pson

    validate

    raise "Could not find data type #{type} for application #{self.class.name}" unless interface.indirection

    @interface.set_terminus(from) if from
  end

  def validate
    unless verb
      raise "You must specify #{interface.actions.join(", ")} as a verb; 'save' probably does not work right now"
    end

    unless interface.action?(verb)
      raise "Command '#{verb}' not found for #{type}"
    end
  end
end
