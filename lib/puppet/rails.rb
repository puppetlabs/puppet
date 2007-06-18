# Load the appropriate libraries, or set a class indicating they aren't available

require 'facter'
require 'puppet'

module Puppet::Rails

    def self.connect
        # This global init does not work for testing, because we remove
        # the state dir on every test.
        unless ActiveRecord::Base.connected?
            Puppet.config.use(:main, :rails, :puppetmasterd)

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
    end

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

        connect()

        unless ActiveRecord::Base.connection.tables.include?("resources")
            require 'puppet/rails/database/schema'
            Puppet::Rails::Schema.init
        end

        if Puppet[:dbmigrate]
            migrate()
        end
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

        Puppet.notice "Migrating"

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

        Puppet.config.use(:puppetmasterd, :rails)

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
