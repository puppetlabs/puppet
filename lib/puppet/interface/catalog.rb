require 'puppet/interface/indirector'

Puppet::Interface::Indirector.new(:catalog) do
  action(:apply) do
    invoke do |catalog|
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
    invoke do |certname,facts|
      Puppet::Resource::Catalog.terminus_class = :rest
      facts_to_upload = {:facts_format => :b64_zlib_yaml, :facts => CGI.escape(facts.render(:b64_zlib_yaml))}
      catalog = nil
      retrieval_duration = thinmark do
        catalog = Puppet::Interface::Catalog.find(certname, facts_to_upload)
      end
      catalog = catalog.to_ral
      catalog.finalize
      catalog.retrieval_duration = retrieval_duration
      catalog.write_class_file
      catalog
    end
  end
end
