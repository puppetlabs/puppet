# Load the appropriate libraries, or set a class indicating they aren't available

require 'facter'
require 'puppet'

module Puppet::Rails
    TIME_DEBUG = true

    def self.connect
        # This global init does not work for testing, because we remove
        # the state dir on every test.
        return if ActiveRecord::Base.connected?

        Puppet.settings.use(:main, :rails, :puppetmasterd)

        ActiveRecord::Base.logger = Logger.new(Puppet[:railslog])
        begin
            loglevel = Logger.const_get(Puppet[:rails_loglevel].upcase)
            ActiveRecord::Base.logger.level = loglevel
        rescue => detail
            Puppet.warning "'%s' is not a valid Rails log level; using debug" % Puppet[:rails_loglevel]
            ActiveRecord::Base.logger.level = Logger::DEBUG
        end

        if (::ActiveRecord::VERSION::MAJOR == 2 and ::ActiveRecord::VERSION::MINOR <= 1)
            ActiveRecord::Base.allow_concurrency = true
        end

        ActiveRecord::Base.verify_active_connections!

        begin
            args = database_arguments
            Puppet.info "Connecting to #{args[:adapter]} database: #{args[:database]}"
            ActiveRecord::Base.establish_connection(args)
        rescue => detail
            if Puppet[:trace]
                puts detail.backtrace
            end
            raise Puppet::Error, "Could not connect to database: %s" % detail
        end
    end

    # The arguments for initializing the database connection.
    def self.database_arguments
        adapter = Puppet[:dbadapter]

        args = {:adapter => adapter, :log_level => Puppet[:rails_loglevel]}

        case adapter
        when "sqlite3"
            args[:database] = Puppet[:dblocation]
        when "mysql", "postgresql"
            args[:host]     = Puppet[:dbserver] unless Puppet[:dbserver].empty?
            args[:username] = Puppet[:dbuser] unless Puppet[:dbuser].empty?
            args[:password] = Puppet[:dbpassword] unless Puppet[:dbpassword].empty?
            args[:database] = Puppet[:dbname]
            args[:reconnect]= true

            socket          = Puppet[:dbsocket]
            args[:socket]   = socket unless socket.empty?
        else
            raise ArgumentError, "Invalid db adapter %s" % adapter
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

        unless ActiveRecord::Base.connection.tables.include?("resources")
            raise Puppet::Error, "Database has problems, can't migrate."
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

        Puppet.settings.use(:puppetmasterd, :rails)

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

