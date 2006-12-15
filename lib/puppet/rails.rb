# Load the appropriate libraries, or set a class indicating they aren't available

require 'facter'
require 'puppet'

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
        :dbmigrate => [ false, "Whether to automatically migrate the database." ],
        :dbname => [ "puppet", "The name of the database to use." ],
        :dbserver => [ "localhost", "The database server for Client caching. Only
            used when networked databases are used."],
        :dbuser => [ "puppet", "The database user for Client caching. Only
            used when networked databases are used."],
        :dbpassword => [ "puppet", "The database password for Client caching. Only
            used when networked databases are used."],
        :railslog => {:default => "/tmp/puppetpuppetrails.log",
            :mode => 0600,
            :owner => "$user",
            :group => "$group",
            :desc => "Where Rails-specific logs are sent"
        }
    )
    
    def self.clear
    end

    def self.teardown
        unless defined? ActiveRecord::Base
            raise Puppet::DevError, "No activerecord, cannot init Puppet::Rails"
        end
            Puppet.config.use(:puppetmaster)

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

        begin
            ActiveRecord::Base.establish_connection(args)
        rescue => detail
            if Puppet[:trace]
               puts detail.backtrace
            end
            raise Puppet::Error, "Could not connect to database: %s" % detail
        end 

        ActiveRecord::Base.connection.tables.each do |t| 
            ActiveRecord::Base.connection.drop_table t
        end

        @inited = false
    end

    # Set up our database connection.  It'd be nice to have a "use" system
    # that could make callbacks.
    def self.init
        unless Puppet.features.rails?
            raise Puppet::DevError, "No activerecord, cannot init Puppet::Rails"
        end

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
                #unless FileTest.exists?(Puppet[:dblocation])
                #    Puppet.config.use(:puppet)
                #    Puppet.config.write(:dblocation) do |f|
                #        f.print ""
                #    end
                #end
            
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
            unless ActiveRecord::Base.connection.tables.include?("resources")
                require 'puppet/rails/database/schema'
                Puppet::Rails::Schema.init
            end
            @inited = true
        end
        ActiveRecord::Base.logger = Logger.new(Puppet[:railslog])

        if Puppet[:dbmigrate]
            dbdir = nil
            $:.each { |d|
                tmp = File.join(d, "puppet/rails/database")
                if FileTest.directory?(tmp)
                    dbdir = tmp
                    break
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
        end
        Puppet.config.use(:puppetmaster)
        ActiveRecord::Base.logger = Logger.new(Puppet[:railslog])
    end
end

if Puppet.features.rails?
    require 'puppet/rails/host'
end

# $Id$
