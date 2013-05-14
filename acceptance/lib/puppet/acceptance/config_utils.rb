module Puppet
  module Acceptance
    module ConfigUtils
      class IniFile
        def initialize file_as_string
          @contents = parse( file_as_string )
        end

        def method_missing( meth, *args )
          if @contents.respond_to? meth
            @contents.send( meth, *args )
          else
            super
          end
        end

        def parse file_as_string
          accumulator = Hash.new
          accumulator[:global] = Hash.new
          section = :global
          file_as_string.each_line do |line|
            case line
            when /^\s*\[\S+\]/
              # We've got a section header
              match = line.match(/^\s*\[(\S+)\].*/)
              section = match[1]
              accumulator[section] = Hash.new
            when /^\s*\S+\s*=\s*\S/
              # add a key value pair to the current section
              # will add it to the :global section if before a section header
              # note: in line comments are not support in puppet.conf
              raw_key, raw_value = line.split( '=' )
              key = raw_key.strip
              value = raw_value.strip
              accumulator[section][key] = value
            end
            # comments, whitespace and lines without an '=' pass through
          end

          return accumulator
        end

        def to_s
          string = ''
          @contents.each_pair do |header, values|
            if header == :global
              values.each_pair do |key, value|
                next if value.nil?
                string << "#{key} = #{value}\n"
              end
              string << "\n"
            else
              string << "[#{header}]\n"
              values.each_pair do |key, value|
                next if value.nil?
                string << " #{key} = #{value}\n"
              end
              string << "\n"
            end
          end
          return string
        end
      end

      def puppet_conf_for host
        puppetconf = on( host, "cat #{host['puppetpath']}/puppet.conf" ).stdout
        IniFile.new( puppetconf )
      end

      def with_puppet_running_on host, conf_opts, testdir = host.tmpdir, &block
        new_conf = puppet_conf_for( host )
        new_conf.merge!( conf_opts )
        create_remote_file host, "#{testdir}/puppet.conf", new_conf.to_s

        begin
          on host, "cp #{host['puppetpath']}/puppet.conf #{host['puppetpath']}/puppet.conf.bak"
          on host, "cat #{testdir}/puppet.conf > #{host['puppetpath']}/puppet.conf"
          if host.is_pe?
            on host, '/etc/init.d/pe-httpd restart' # we work with PE yo!
          else
            on host, puppet( 'master' ) # maybe we even work with FOSS?!?!??
            require 'socket'
            inc = 0
            logger.debug 'Waiting for the puppet master to start'
            begin
              TCPSocket.new(host.to_s, 8140).close
            rescue Errno::ECONNREFUSED
              sleep 1
              inc += 1
              retry unless inc >= 9
              raise 'Puppet master did not start in a timely fashion'
            end
          end

          yield self if block_given?
        ensure
          on host, "if [ -f #{host['puppetpath']}/puppet.conf.bak ]; then mv -f #{host['puppetpath']}/puppet.conf.bak #{host['puppetpath']}/puppet.conf; fi"
          if host.is_pe?
            on host, '/etc/init.d/pe-httpd restart'
          else
            on host, 'kill $(cat `puppet master --configprint pidfile`)'
          end
        end
      end
    end
  end
end

