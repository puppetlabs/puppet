Puppet::Indirector::Face.define(:node, '0.0.1') do
  action(:clean) do
    option "--[no-]unexport" do
      summary "Unexport exported resources"
    end
  
    summary "Clean up everything a puppetmaster knows about a node"
    
    arguments "<host1> [<host2> ...]"

    description <<-EOT
This includes

 * Signed certificates ($vardir/ssl/ca/signed/node.domain.pem)
 * Cached facts ($vardir/yaml/facts/node.domain.yaml)
 * Cached node stuff ($vardir/yaml/node/node.domain.yaml)
 * Reports ($vardir/reports/node.domain)
 * Stored configs: it can either remove all data from an host in your storedconfig
 database, or with --unexport turn every exported resource supporting ensure to absent
 so that any other host checking out their config can remove those exported configurations.

This will unexport exported resources of a
host, so that consumers of these resources can remove the exported
resources and we will safely remove the node from our
infrastructure.
EOT
    when_invoked do |*args|
      nodes = args[0..-2]
      options = args.last
      raise "At least one node should be passed" if nodes.empty? || nodes == options

      # TODO: this is a hack and should be removed if faces provide the proper
      # infrastructure to set the run mode.
      require 'puppet/util/run_mode'
      $puppet_application_mode = Puppet::Util::RunMode[:master]

      if Puppet::SSL::CertificateAuthority.ca?
        Puppet::SSL::Host.ca_location = :local
      else
        Puppet::SSL::Host.ca_location = :none
      end
  
      Puppet::Node::Facts.indirection.terminus_class = :yaml
      Puppet::Node::Facts.indirection.cache_class = :yaml
      Puppet::Node.indirection.terminus_class = :yaml
      Puppet::Node.indirection.cache_class = :yaml

      begin
        nodes.each do |node|
          node = node.downcase
          clean_cert(node)
          clean_cached_facts(node)
          clean_cached_node(node)
          clean_reports(node)
          clean_storeconfigs(node,options[:unexport])
        end
      rescue => detail
        puts detail.backtrace if Puppet[:trace]
        puts detail.to_s
      end
    end
  end
  
  # clean signed cert for +host+
  def clean_cert(node)
    if Puppet::SSL::Host.ca_location == :local
      ca.apply(:revoke, :to => [node])
      ca.apply(:destroy, :to => [node])
      Puppet.info "%s certificates removed from ca" % node
    else
      Puppet.info "Not managing %s certs as this host is not a CA" % node
    end
  end

  # clean facts for +host+
  def clean_cached_facts(node)
    Puppet::Node::Facts.indirection.destroy(node)
    Puppet.info "%s's facts removed" % node
  end

  # clean cached node +host+
  def clean_cached_node(node)
    Puppet::Node.indirection.destroy(node)
    Puppet.info "%s's cached node removed" % node
  end

  # clean node reports for +host+
  def clean_reports(node)
    Puppet::Transaction::Report.indirection.destroy(node)
    Puppet.info "%s's reports removed" % node
  end

  # clean storeconfig for +node+
  def clean_storeconfigs(node,do_unexport=false)
    return unless Puppet[:storeconfigs] && Puppet.features.rails?
    require 'puppet/rails'
    Puppet::Rails.connect
    unless rails_node = Puppet::Rails::Host.find_by_name(node)
      Puppet.notice "No entries found for %s in storedconfigs." % node
      return
    end

    if do_unexport
      unexport(rails_node)
      Puppet.notice "Force %s's exported resources to absent" % node
      Puppet.warning "Please wait until all other hosts have checked out their configuration before finishing the cleanup with:"
      Puppet.warning "$ puppet node clean #{node}"
    else
      rails_node.destroy
      Puppet.notice "%s storeconfigs removed" % node
    end
  end

  def unexport(node)
    # fetch all exported resource
    query = {:include => {:param_values => :param_name}}
    query[:conditions] = ["exported=? AND host_id=?", true, node.id]
    Puppet::Rails::Resource.find(:all, query).each do |resource|
      if type_is_ensurable(resource)
        line = 0
        param_name = Puppet::Rails::ParamName.find_or_create_by_name("ensure")

        if ensure_param = resource.param_values.find(
          :first,
          :conditions => [ 'param_name_id = ?', param_name.id]
        )
          line = ensure_param.line.to_i
          Puppet::Rails::ParamValue.delete(ensure_param.id);
        end

        # force ensure parameter to "absent"
        resource.param_values.create(
          :value => "absent",
          :line => line,
          :param_name => param_name
        )
        Puppet.info("%s has been marked as \"absent\"" % resource.name)
      end
    end
  end

  def ca
    @ca ||= Puppet::SSL::CertificateAuthority.instance
  end

  def environment
    @environemnt ||= Puppet::Node::Environment.new
  end

  def type_is_ensurable(resource)
      (type=Puppet::Type.type(resource.restype)) && type.validattr?(:ensure) || \
        (type = environment.known_resource_types.find_definition('',resource.restype)) && type.arguments.keys.include?('ensure')
  end
end