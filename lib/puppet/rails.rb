# Load the appropriate libraries, or set a class indicating they aren't available

require 'facter'
require 'puppet'

begin
    require 'active_record'
rescue LoadError => detail
    if Facter["operatingsystem"].value == "Debian"
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

module Puppet::Rails
    Puppet.config.setdefaults(:puppetmaster,
        :dblocation => { :default => "$statedir/clientconfigs.sqlite3",
            :mode => 0600,
            :owner => "$user",
            :group => "$group",
            :desc => "The database cache for client configurations.  Used for
                querying within the language."
        },
        :dbadapter => [ "sqlite3", "The type of database to use." ],
        :dbname => [ "puppet", "The name of the database to use." ],
        :dbserver => [ "puppet", "The database server for Client caching. Only
            used when networked databases are used."],
        :dbuser => [ "puppet", "The database user for Client caching. Only
            used when networked databases are used."],
        :dbpassword => [ "puppet", "The database password for Client caching. Only
            used when networked databases are used."],
        :railslog => {:default => "$logdir/puppetrails.log",
            :mode => 0600,
            :owner => "$user",
            :group => "$group",
            :desc => "Where Rails-specific logs are sent"
        }
    )

    def self.clear
        @inited = false
    end

    # Set up our database connection.  It'd be nice to have a "use" system
    # that could make callbacks.
    def self.init
        # This global init does not work for testing, because we remove
        # the state dir on every test.
        #unless (defined? @inited and @inited) or defined? Test::Unit::TestCase
        unless (defined? @inited and @inited)
            Puppet.config.use(:puppet)

            ActiveRecord::Base.logger = Logger.new(Puppet[:railslog])
            args = {:adapter => Puppet[:dbadapter]}

            case Puppet[:dbadapter]
            when "sqlite3":
                args[:database] = Puppet[:dblocation]
            when "mysql":
                args[:host]     = Puppet[:dbserver]
                args[:username] = Puppet[:dbuser]
                args[:password] = Puppet[:dbpassword]
                args[:database] = Puppet[:dbname]
            end

            ActiveRecord::Base.establish_connection(args)

            @inited = true
        end

        if Puppet[:dbadapter] == "sqlite3" and ! FileTest.exists?(Puppet[:dblocation])
            require 'puppet/rails/database'
            Puppet::Rails::Database.up
        end
            Puppet.config.use(:puppetmaster)
    end
end

if defined? ActiveRecord::Base
    require 'puppet/rails/host'
end

# $Id$
