#  Created by Luke Kanies on 2006-11-07.
#  Copyright (c) 2006. All rights reserved.

require 'puppet/feature'

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
        end
    end

    # If we couldn't find it the normal way, try using a Gem.
    unless defined? ActiveRecord
        begin
            require 'rubygems'
            require_gem 'rails'
        rescue LoadError
            # Nothing
        end
    end

    if defined? ActiveRecord
        require 'puppet/rails'
        true
    else
        false
    end
end

# $Id$
