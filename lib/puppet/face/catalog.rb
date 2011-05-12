require 'puppet/indirector/face'

Puppet::Indirector::Face.define(:catalog, '0.0.1') do
  copyright "Puppet Labs", 2011
  license   "Apache 2 license; see COPYING"

  summary "Compile, save, view, and convert catalogs."
  description <<-EOT
    This face primarily interacts with the compiling subsystem. By default,
    it compiles a catalog using the default manifest and the hostname from
    `certname`, but you can choose to retrieve a catalog from the server by
    specifying `--terminus rest`.  You can also choose to print any catalog
    in 'dot' format (for easy graph viewing with OmniGraffle or Graphviz)
    with '--render-as dot'.
  EOT
  notes <<-EOT
    This is an indirector face, which exposes find, search, save, and
    destroy actions for an indirected subsystem of Puppet. Valid terminuses
    for this face include:

    * `active_record`
    * `compiler`
    * `queue`
    * `rest`
    * `yaml`
  EOT

  action(:apply) do
    summary "Apply a Puppet::Resource::Catalog object"
    description <<-EOT
      Applies a catalog object retrieved with the `download` action. This
      action cannot consume a serialized catalog, and is not intended for
      command-line use."
    EOT
    notes <<-EOT
      This action returns a Puppet::Transaction::Report object.
    EOT
    examples <<-EOT
      From `secret_agent.rb`:

          Puppet::Face[:plugin, '0.0.1'].download

          facts   = Puppet::Face[:facts, '0.0.1'].find(certname)
          catalog = Puppet::Face[:catalog, '0.0.1'].download(certname, facts)
          report  = Puppet::Face[:catalog, '0.0.1'].apply(catalog)

          Puppet::Face[:report, '0.0.1'].submit(report)
    EOT

    when_invoked do |options|
      catalog = Puppet::Face[:catalog, "0.0.1"].find(Puppet[:certname]) or raise "Could not find catalog for #{Puppet[:certname]}"
      catalog = catalog.to_ral

      report = Puppet::Transaction::Report.new("apply")
      report.configuration_version = catalog.version

      Puppet::Util::Log.newdestination(report)

      begin
        benchmark(:notice, "Finished catalog run") do
          catalog.apply(:report => report)
        end
      rescue => detail
        puts detail.backtrace if Puppet[:trace]
        Puppet.err "Failed to apply catalog: #{detail}"
      end

      report.finalize_report
      report
    end
  end

  action(:download) do
    summary "Download this node's catalog from the puppet master server"
    description <<-EOT
      Retrieves a catalog from the puppet master. Unlike the `find` action,
      `download` submits facts to the master as part of the request. This
      action is not intended for command-line use.
    EOT
    notes "This action returns a Puppet::Resource::Catalog object."
    examples <<-EOT
      From `secret_agent.rb`:

          Puppet::Face[:plugin, '0.0.1'].download

          facts   = Puppet::Face[:facts, '0.0.1'].find(certname)
          catalog = Puppet::Face[:catalog, '0.0.1'].download(certname, facts)
          report  = Puppet::Face[:catalog, '0.0.1'].apply(catalog)

          Puppet::Face[:report, '0.0.1'].submit(report)
    EOT
    when_invoked do |options|
      Puppet::Resource::Catalog.indirection.terminus_class = :rest
      Puppet::Resource::Catalog.indirection.cache_class = nil
      catalog = nil
      retrieval_duration = thinmark do
        catalog = Puppet::Face[:catalog, '0.0.1'].find(Puppet[:certname])
      end
      catalog.retrieval_duration = retrieval_duration
      catalog.write_class_file

      Puppet::Resource::Catalog.indirection.terminus_class = :yaml
      Puppet::Face[:catalog, "0.0.1"].save(catalog)
      Puppet.notice "Saved catalog for #{Puppet[:certname]} to yaml"
      nil
    end
  end
end
