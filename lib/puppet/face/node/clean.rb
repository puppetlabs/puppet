Puppet::Face.define(:node, '0.0.1') do
  action(:clean) do

    summary _("Clean up cached facts, node objects, and reports for a node stored by the puppetmaster")
    arguments _("<host1> [<host2> ...]")
    description <<-'EOT'
      Cleans up the following information a puppet master knows about a node:

      <Cached facts> - ($vardir/yaml/facts/node.domain.yaml)

      <Cached node objects> - ($vardir/yaml/node/node.domain.yaml)

      <Reports> - ($vardir/reports/node.domain)

      NOTE: this action no longer cleans up certs. For cert cleaning, please use `puppetserver ca clean`.
    EOT

    when_invoked do |*args|
      nodes = args[0..-2]
      options = args.last
      raise _("At least one node should be passed") if nodes.empty? || nodes == options

      Puppet::Node::Facts.indirection.terminus_class = :yaml
      Puppet::Node::Facts.indirection.cache_class = :yaml
      Puppet::Node.indirection.terminus_class = :yaml
      Puppet::Node.indirection.cache_class = :yaml

      nodes.each { |node| cleanup(node.downcase) }
    end
  end

  def cleanup(node)
    clean_cached_facts(node)
    clean_cached_node(node)
    clean_reports(node)
  end

  # clean facts for +host+
  def clean_cached_facts(node)
    Puppet::Node::Facts.indirection.destroy(node)
    Puppet.info _("%{node}'s facts removed") % { node: node }
  end

  # clean cached node +host+
  def clean_cached_node(node)
    Puppet::Node.indirection.destroy(node)
    Puppet.info _("%{node}'s cached node removed") % { node: node }
  end

  # clean node reports for +host+
  def clean_reports(node)
    Puppet::Transaction::Report.indirection.destroy(node)
    Puppet.info _("%{node}'s reports removed") % { node: node }
  end

  def environment
    @environment ||= Puppet.lookup(:current_environment)
  end

  def type_is_ensurable(resource)
    if (type = Puppet::Type.type(resource.restype)) && type.validattr?(:ensure)
      return true
    else
      type = environment.known_resource_types.find_definition(resource.restype)
      return true if type && type.arguments.keys.include?('ensure')
    end
    return false
  end
end
