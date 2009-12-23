require 'puppet'
require 'puppet/application'
require 'facter'

Puppet::Application.new(:ralsh) do

    should_not_parse_config

    attr_accessor :host, :extra_params

    preinit do
        @extra_params = []
        @host = nil
        Facter.loadfacts
    end

    option("--debug","-d")
    option("--verbose","-v")
    option("--edit","-e")

    option("--host HOST","-H") do |arg|
        @host = arg
    end

    option("--types", "-t") do |arg|
        types = []
        Puppet::Type.loadall
        Puppet::Type.eachtype do |t|
            next if t.name == :component
            types << t.name.to_s
        end
        puts types.sort
        exit
    end

    option("--param PARAM", "-p") do |arg|
        @extra_params << arg.to_sym
    end

    command(:main) do
        type = ARGV.shift or raise "You must specify the type to display"
        typeobj = Puppet::Type.type(type) or raise "Could not find type #{type}"
        name = ARGV.shift
        params = {}
        ARGV.each do |setting|
            if setting =~ /^(\w+)=(.+)$/
                params[$1] = $2
            else
                raise "Invalid parameter setting %s" % setting
            end
        end

        if options[:edit] and @host
            raise "You cannot edit a remote host"
        end

        properties = typeobj.properties.collect { |s| s.name }

        format = proc {|trans|
            trans.dup.collect do |param, value|
                if value.nil? or value.to_s.empty?
                    trans.delete(param)
                elsif value.to_s == "absent" and param.to_s != "ensure"
                    trans.delete(param)
                end

                unless properties.include?(param) or @extra_params.include?(param)
                    trans.delete(param)
                end
            end
            trans.to_manifest
        }

        text = if @host
            client = Puppet::Network::Client.resource.new(:Server => @host, :Port => Puppet[:puppetport])
            unless client.read_cert
                raise "client.read_cert failed"
            end
            begin
                # They asked for a single resource.
                if name
                    transbucket = [client.describe(type, name)]
                else
                    # Else, list the whole thing out.
                    transbucket = client.instances(type)
                end
            rescue Puppet::Network::XMLRPCClientError => exc
                raise "client.list(#{type}) failed: #{exc.message}"
            end
            transbucket.sort { |a,b| a.name <=> b.name }.collect(&format)
        else
            if name
                obj = typeobj.instances.find { |o| o.name == name } || typeobj.new(:name => name, :check => properties)
                vals = obj.retrieve

                unless params.empty?
                    params.each do |param, value|
                        obj[param] = value
                    end
                    catalog = Puppet::Resource::Catalog.new
                    catalog.add_resource obj
                    begin
                        catalog.apply
                    rescue => detail
                        if Puppet[:trace]
                            puts detail.backtrace
                        end
                    end

                end
                [format.call(obj.to_trans(true))]
            else
                typeobj.instances.collect do |obj|
                    next if ARGV.length > 0 and ! ARGV.include? obj.name
                    trans = obj.to_trans(true)
                    format.call(trans)
                end
            end
        end.compact.join("\n")

        if options[:edit]
            file = "/tmp/x2puppet-#{Process.pid}.pp"
            begin
                File.open(file, "w") do |f|
                    f.puts text
                end
                ENV["EDITOR"] ||= "vi"
                system(ENV["EDITOR"], file)
                system("puppet -v " + file)
            ensure
                #if FileTest.exists? file
                #    File.unlink(file)
                #end
            end
        else
            puts text
        end
    end

    setup do
        Puppet::Util::Log.newdestination(:console)

        # Now parse the config
        Puppet.parse_config

        if options[:debug]
            Puppet::Util::Log.level = :debug
        elsif options[:verbose]
            Puppet::Util::Log.level = :info
        end
    end
end
