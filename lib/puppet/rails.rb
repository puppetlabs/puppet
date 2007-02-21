# Load the appropriate libraries, or set a class indicating they aren't available

require 'facter'
require 'puppet'

module Puppet::Rails
    Puppet.config.setdefaults(:puppetmaster,
        :dblocation => { :default => "$statedir/clientconfigs.sqlite3",
            :mode => 0660,
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
        :railslog => {:default => "$logdir/rails.log",
            :mode => 0600,
            :owner => "$user",
            :group => "$group",
            :desc => "Where Rails-specific logs are sent"
        }
    )

    # The arguments for initializing the database connection.
    def self.database_arguments
        args = {:adapter => Puppet[:dbadapter]}

        case Puppet[:dbadapter]
        when "sqlite3":
            args[:dbfile] = Puppet[:dblocation]
        when "mysql", "postgresql":
            args[:host]     = Puppet[:dbserver]
            args[:username] = Puppet[:dbuser]
            args[:password] = Puppet[:dbpassword]
            args[:database] = Puppet[:dbname]
        else
            raise ArgumentError, "Invalid db adapter %s" % Puppet[:dbadapter]
        end
        args
    end

    # Set up our database connection.  It'd be nice to have a "use" system
    # that could make callbacks.
    def self.init
        unless Puppet.features.rails?
            raise Puppet::DevError, "No activerecord, cannot init Puppet::Rails"
        end

        # This global init does not work for testing, because we remove
        # the state dir on every test.
        unless ActiveRecord::Base.connected?
            Puppet.config.use(:puppet)

            ActiveRecord::Base.logger = Logger.new(Puppet[:railslog])
            ActiveRecord::Base.allow_concurrency = true
            ActiveRecord::Base.verify_active_connections!

            begin
                ActiveRecord::Base.establish_connection(database_arguments())
            rescue => detail
                if Puppet[:trace]
                    puts detail.backtrace
                end
                raise Puppet::Error, "Could not connect to database: %s" % detail
            end 
        end

        unless ActiveRecord::Base.connection.tables.include?("resources")
            require 'puppet/rails/database/schema'
            Puppet::Rails::Schema.init
        end

        if Puppet[:dbmigrate]
            migrate()
        end

        # For now, we have to use :puppet, too, since non-puppetmasterd processes
        # (including testing) put the logdir in :puppet, not in :puppetmasterd.
        Puppet.config.use(:puppetmaster, :puppet)

        # This has to come after we create the logdir with the :use above.
        ActiveRecord::Base.logger = Logger.new(Puppet[:railslog])
    end

    # Migrate to the latest db schema.
    def self.migrate
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
            raise Puppet::Error, "Could not migrate database: %s" % detail
        end
    end

    # Tear down the database.  Mostly only used during testing.
    def self.teardown
        unless Puppet.features.rails?
            raise Puppet::DevError, "No activerecord, cannot init Puppet::Rails"
        end

        Puppet.config.use(:puppetmaster)

        begin
            ActiveRecord::Base.establish_connection(database_arguments())
        rescue => detail
            if Puppet[:trace]
               puts detail.backtrace
            end
            raise Puppet::Error, "Could not connect to database: %s" % detail
        end 

        ActiveRecord::Base.connection.tables.each do |t| 
            ActiveRecord::Base.connection.drop_table t
        end
    end
end

if Puppet.features.rails?
    require 'puppet/rails/host'
end

# $Id$
