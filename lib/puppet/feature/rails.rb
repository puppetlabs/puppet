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
        end
    end

    # If we couldn't find it the normal way, try using a Gem.
    unless defined? ActiveRecord
        begin
            require 'rubygems'
            gem 'rails'
        rescue LoadError
            # Nothing
        end
    end

    # We check a fairly specific class, so that we can be sure that we've
    # loaded a new enough version of AR that will support the features we
    # actually use.
    if defined? ActiveRecord::Associations::BelongsToPolymorphicAssociation
        require 'puppet/rails'
        true
    else
        false
    end
end

# $Id$
