#  Created by Luke Kanies on 2006-11-07.
#  Copyright (c) 2006. All rights reserved.

require 'puppet/util/feature'

Puppet.features.add(:rails) do
    begin
        require 'active_record'
    rescue LoadError => detail
        if Facter["operatingsystem"].value == "Debian" and
            FileTest.exists?("/usr/share/rails")
                count = 0
                Dir.entries("/usr/share/rails").each do |dir|
                    libdir = File.join("/usr/share/rails", dir, "lib")
                    if FileTest.exists?(libdir) and ! $:.include?(libdir)
                        count += 1
                        $: << libdir
                    end
                end

                if count > 0
                    retry
                end
        else
            #If ActiveRecord was installed only via rubygems this is required
            require 'rubygems'
            require 'active_record'
        end
    end

    if ! (defined?(::ActiveRecord) and defined?(::ActiveRecord::VERSION) and defined?(::ActiveRecord::VERSION::MAJOR) and defined?(::ActiveRecord::VERSION::MINOR))
        false
    elsif !  ::ActiveRecord::VERSION::MAJOR == 2 and ::ActiveRecord::VERSION::MINOR == 3
        Puppet.info "ActiveRecord 2.3 required for StoreConfigs"
        false
    else
        true
    end
end

