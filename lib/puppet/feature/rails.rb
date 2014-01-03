require 'puppet/util/feature'

Puppet.features.add(:rails) do
  begin
    # Turn off the constant watching parts of ActiveSupport, which have a huge
    # cost in terms of the system watching loaded code to figure out if it was
    # a missing content, and which we don't actually *use* anywhere.
    #
    # In fact, we *can't* depend on the feature: we don't require
    # ActiveSupport, just load it if we use rails, if we depend on a feature
    # that it offers. --daniel 2012-07-16
    require 'active_support'
    begin
      require 'active_support/dependencies'
      ActiveSupport::Dependencies.unhook!
      ActiveSupport::Dependencies.mechanism = :require
    rescue LoadError, ScriptError, StandardError => e
      # ignore any failure - worst case we run without disabling the CPU
      # sucking features, so are slower but ... not actually failed, just
      # because some random future version of ActiveRecord changes.
      Puppet.debug("disabling ActiveSupport::Dependencies failed: #{e}")
    end

    require 'active_record'
    require 'active_record/version'
  rescue LoadError
    if Puppet::FileSystem.exist?("/usr/share/rails")
      count = 0
      Dir.entries("/usr/share/rails").each do |dir|
        libdir = File.join("/usr/share/rails", dir, "lib")
        if Puppet::FileSystem.exist?(libdir) and ! $LOAD_PATH.include?(libdir)
          count += 1
          $LOAD_PATH << libdir
        end
      end

      retry if count > 0
    end
  end

  unless (Puppet::Util.activerecord_version >= 2.1)
    Puppet.info "ActiveRecord 2.1 or later required for StoreConfigs"
    false
  else
    true
  end
end
