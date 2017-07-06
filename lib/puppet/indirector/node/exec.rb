require 'puppet/node'
require 'puppet/indirector/exec'

class Puppet::Node::Exec < Puppet::Indirector::Exec
  desc "Call an external program to get node information.  See
  the [External Nodes](https://docs.puppetlabs.com/guides/external_nodes.html) page for more information."
  include Puppet::Util

  def command
    command = Puppet[:external_nodes]
    raise ArgumentError, _("You must set the 'external_nodes' parameter to use the external node terminus") unless command != _("none")
    command.split
  end

  # Look for external node definitions.
  def find(request)
    output = super or return nil

    # Translate the output to ruby.
    result = translate(request.key, output)

    facts = request.options[:facts].is_a?(Puppet::Node::Facts) ? request.options[:facts] : nil

    # Set the requested environment if it wasn't overridden
    # If we don't do this it gets set to the local default
    result[:environment] ||= request.environment

    create_node(request.key, result, facts)
  end

  private

  # Proxy the execution, so it's easier to test.
  def execute(command, arguments)
    Puppet::Util::Execution.execute(command,arguments)
  end

  # Turn our outputted objects into a Puppet::Node instance.
  def create_node(name, result, facts = nil)
    node = Puppet::Node.new(name)
    set = false
    [:parameters, :classes, :environment].each do |param|
      if value = result[param]
        node.send(param.to_s + "=", value)
        set = true
      end
    end

    node.fact_merge(facts)
    node
  end

  # Translate the yaml string into Ruby objects.
  def translate(name, output)
    YAML.load(output).inject({}) do |hash, data|
      case data[0]
      when String
        hash[data[0].intern] = data[1]
      when Symbol
        hash[data[0]] = data[1]
      else
        raise Puppet::Error, _("key is a %{klass}, not a string or symbol") % { klass: data[0].class }
      end

      hash
    end

  rescue => detail
      raise Puppet::Error, _("Could not load external node results for %{name}: %{detail}") % { name: name, detail: detail }, detail.backtrace
  end
end
