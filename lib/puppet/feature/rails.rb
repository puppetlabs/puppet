require 'puppet/util/feature'

Puppet.features.rubygems?

Puppet.features.add(:rails) do
  begin
    require 'active_record'
    require 'active_record/version'
  rescue LoadError => detail
    if FileTest.exists?("/usr/share/rails")
      count = 0
      Dir.entries("/usr/share/rails").each do |dir|
        libdir = File.join("/usr/share/rails", dir, "lib")
        if FileTest.exists?(libdir) and ! $LOAD_PATH.include?(libdir)
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
