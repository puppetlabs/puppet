# Load the appropriate libraries, or set a class indicating they aren't available

require 'facter'
require 'puppet'

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

module Puppet::Rails
require 'puppet/rails/database/schema_init'

    Puppet.config.setdefaults(:puppetmaster,
        #this should be changed to use $statedir, but for now it only works this way.
        :dblocation => { :default => "$statedir/clientconfigs.sqlite3",
            :mode => 0600,
            :owner => "$user",
            :group => "$group",
            :desc => "The database cache for client configurations.  Used for
                querying within the language."
        },
        :dbadapter => [ "sqlite3", "The type of database to use." ],
        :dbname => [ "puppet", "The name of the database to use." ],
        :dbserver => [ "localhost", "The database server for Client caching. Only
            used when networked databases are used."],
        :dbuser => [ "puppet", "The database user for Client caching. Only
            used when networked databases are used."],
        :dbpassword => [ "puppet", "The database password for Client caching. Only
            used when networked databases are used."],
        #this should be changed to use $logdir, but for now it only works this way.
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
        unless defined? ActiveRecord::Base
            raise Puppet::DevError, "No activerecord, cannot init Puppet::Rails"
        end

        # This global init does not work for testing, because we remove
        # the state dir on every test.
        #unless (defined? @inited and @inited) or defined? Test::Unit::TestCase
        unless (defined? @inited and @inited)
            Puppet.config.use(:puppetmaster)

            args = {:adapter => Puppet[:dbadapter]}

            case Puppet[:dbadapter]
            when "sqlite3":
                args[:database] = Puppet[:dblocation]
                unless FileTest.exists?(Puppet[:dblocation])
                    Puppet.config.use(:puppet)
                    Puppet.config.write(:dblocation) do |f|
                        f.print ""
                    end
                end
            
            when "mysql":
                args[:host]     = Puppet[:dbserver]
                args[:username] = Puppet[:dbuser]
                args[:password] = Puppet[:dbpassword]
                args[:database] = Puppet[:dbname]
            end

            begin
                ActiveRecord::Base.establish_connection(args)
            rescue => detail
                if Puppet[:trace]
                    puts detail.backtrace
                end
                raise Puppet::Error, "Could not connect to database: %s" % detail
            end 
            begin
                @inited = true if ActiveRecord::Base.connection.tables.include? "resources"
            rescue SQLite3::CantOpenException => detail
                @inited = false
            end
            #puts "Database initialized: #{@inited.inspect} "
        end

        if @inited
            dbdir = nil
            $:.each { |d|
                tmp = File.join(d, "puppet/rails/database")
                if FileTest.directory?(tmp)
                    dbdir = tmp 
                end
            }

            unless dbdir
                raise Puppet::Error, "Could not find Puppet::Rails database dir"
            end

            begin
                ActiveRecord::Migrator.migrate(dbdir)
            rescue => detail
                if Puppet[:trace]
                    puts detail.backtrace
                end
                raise Puppet::Error, "Could not initialize database: %s" % detail
            end
        else
            Puppet::Rails::Schema.init
        end
        Puppet.config.use(:puppet)
        ActiveRecord::Base.logger = Logger.new(Puppet[:railslog])
    end
end

if defined? ActiveRecord::Base
    require 'puppet/rails/host'
end

# $Id$
