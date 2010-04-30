require 'puppet'
require 'puppet/application'
require 'facter'

class Puppet::Application::Resource < Puppet::Application

    should_not_parse_config

    attr_accessor :host, :extra_params

    def preinit
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

    def main
        args = command_line.args
        type = args.shift or raise "You must specify the type to display"
        typeobj = Puppet::Type.type(type) or raise "Could not find type #{type}"
        name = args.shift
        params = {}
        args.each do |setting|
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

        if @host
            Puppet::Resource.indirection.terminus_class = :rest
            port = Puppet[:puppetport]
            key = ["https://#{host}:#{port}", "production", "resources", type, name].join('/')
        else
            key = [type, name].join('/')
        end

        text = if name
            if params.empty?
                [ Puppet::Resource.find( key ) ]
            else
                [ Puppet::Resource.new( type, name, params ).save( key ) ]
            end
        else
            Puppet::Resource.search( key, {} )
        end.map(&format).join("\n")

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

    def setup
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
