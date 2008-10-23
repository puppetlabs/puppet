#--
#  Copyright (C) 2008 Red Hat Inc.
#
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 2.1 of the License, or (at your option) any later version.
#
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  Lesser General Public License for more details.
#
#  You should have received a copy of the GNU Lesser General Public
#  License along with this library; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307  USA
#
# Author: Bryan Kearney <bkearney@redhat.com>

require 'augeas' if Puppet.features.augeas?

Puppet::Type.newtype(:augeas) do
    include Puppet::Util

    confine "The augeas Ruby bindings are not available" => Puppet.features.augeas?

    @doc = "Apply the changes (single or array of changes) to the filesystem
        via the augeas tool.

         Requires:
           - augeas to be installed (http://www.augeas.net)
           - ruby-augeas bindings

         Sample usage with a string:
            augeas{\"test1\" :
                   context => \"/files/etc/sysconfig/firstboot\",
                   changes => \"set RUN_FIRSTBOOT YES\"
                   onlyif  => \"match other_value size > 0\"
             }

         Sample usage with an array and custom lenses:
            augeas{\"jboss_conf\":
                context => \"/files\",
                changes => [
                    \"set /etc/jbossas/jbossas.conf/JBOSS_IP $ipaddress\",
                    \"set /etc/jbossas/jbossas.conf/JAVA_HOME /usr\"
                ],
                load_path => \"$/usr/share/jbossas/lenses\",
            }
         "

    newparam (:name) do
        desc "The name of this task. Used for uniqueness"
        isnamevar
    end

    newparam (:context) do
        desc "Optional context path. This value is pre-pended to the paths of all changes"
        defaultto ""
    end

    newparam (:onlyif) do
        desc "Optional augeas command and comparisons to control the execution of this type.
             Supported onlyif syntax:
               get [AUGEAS_PATH] [COMPARATOR] [STRING]
               match [MATCH_PATH] size [COMPARATOR] [INT]
               match [MATCH_PATH] include [STRING]
               match [MATCH_PATH] == [AN_ARRAY]

             where
               AUGEAS_PATH is a valid path scoped by the context
               MATCH_PATH is a valid match synatx scoped by the context
               COMPARATOR is in the set [> >= != == <= <]
               STRING is a string
               INT is a number
               AN_ARRAY is in the form ['a string', 'another']        "
        defaultto ""
    end


    newparam(:changes) do
        desc "The changes which should be applied to the filesystem. This
        can be either a string which contains a command or an array of commands.
        Commands supported are:

        set [PATH] [VALUE]     Sets the value VALUE at loction PATH
        rm [PATH]              Removes the node at location PATH
        remove [PATH]          Synonym for rm
        clear [PATH]           Keeps the node at PATH, but removes the value.
        ins [PATH]             Inserts an empty node at PATH.
        insert [PATH]          Synonym for ins

        If the parameter 'context' is set that that value is prepended to PATH"

        # Extracts an 2 dimensional array of commands which are in the
        # form of command path value.
        # The input can be
        # - A string with one command
        # - A string with many commands per line
        # - An array of strings.
        def parse_tokens(data)
            commands = Array.new()
            if data.is_a?(String)
                data.each_line do |line|
                    cmd_array = Array.new()
                    tokens = line.split(" ")
                    cmd = tokens.shift()
                    file = tokens.shift()
                    other = tokens.join(" ")
                    cmd_array << cmd if !cmd.nil?
                    cmd_array << file if !file.nil?
                    cmd_array << other if other != ""
                    commands << cmd_array
                end
            elsif data.is_a?(Array)
                data.each do |datum|
                    commands.concat(parse_tokens(datum))
                end
            end

            return commands
        end

        munge do |value|
            self.parse_tokens(value)
        end
    end

    newparam(:root) do
        desc "A file system path; all files loaded by Augeas are loaded underneath ROOT"
        defaultto "/"
    end

    newparam(:load_path) do
        desc "Optional colon separated list of directories; these directories are searched for schema definitions"
        defaultto ""
    end


    newparam(:type_check) do
        desc "Set to true if augeas should perform typechecking. Optional, defaults to false"
        newvalues(:true, :false)

        defaultto :false
    end

    # This is the acutal meat of the code. It forces
    # augeas to be run and fails or not based on the augeas return
    # code.
    newproperty(:returns) do |property|
        include Puppet::Util
        desc "The expected return code from the augeas command. Should not be set"

        defaultto 0

        def open_augeas
            flags = 0
            (flags = 1 << 2 ) if self.resource[:type_check] == :true
            root = self.resource[:root]
            load_path = self.resource[:load_path]
            debug("Opening augeas with root #{root}, lens path #{load_path}, flags #{flags}")
            Augeas.open(root, load_path,flags)
        end

        # Make output a bit prettier
        def change_to_s(currentvalue, newvalue)
            return "executed successfully"
        end

        # method to handle the onlif get strings.
        # Assumes a syntax of get /files/path [COMPARATOR] value
        def process_get(cmd_array)
            return_value = 0

            #validate and tear apart the command
            fail ("Invalid command: #{cmd_array.join(" ")}") if cmd_array.length < 4
            cmd = cmd_array.shift()
            path = cmd_array.shift()
            comparator = cmd_array.shift()
            arg = cmd_array.join(" ")

            #check the value in augeas
            aug = open_augeas()
            result = aug.get(path) || ''
            unless result.nil?
            	case comparator
            		when "!=":
            			return_value = :need_to_run if !(result == arg)
            		when "=~":
            			regex = Regexp.new(arg)
            			loc = result=~ regex
            			return_value = :need_to_run if ! loc.nil?
            		else
            			return_value = :need_to_run if (result.send(comparator, arg))
                end
            end
            return_value
        end

        # This will handle the following cases
        def process_match(cmd_array)
            return_value = 0

            #validate and tear apart the command
            fail("Invalid command: #{cmd_array.join(" ")}") if cmd_array.length < 4
            cmd = cmd_array.shift()
            path = cmd_array.shift()
            verb = cmd_array.shift()

            #Get the values from augeas
            aug = open_augeas()
            result = aug.match(path) || ''
            # Now do the work
            if (!result.nil?)
                case verb
                    when "size":
                        fail("Invalid command: #{cmd_array.join(" ")}") if cmd_array.length != 2
                        comparator = cmd_array.shift()
                        arg = cmd_array.shift().to_i
                        return_value = :need_to_run if (result.size.send(comparator, arg))
                    when "include":
                        arg = cmd_array.join(" ")
                        return_value = :need_to_run if result.include?(arg)
                    when "==":
                        begin
                            arg = cmd_array.join(" ")
                            new_array = eval arg
                            return_value = :need_to_run if result == new_array
                        rescue
                            fail("Invalid array in command: #{cmd_array.join(" ")}")
                        end
                end
            end
            return_value
        end

        # if the onlyif resource is provided, then the value is parsed.
        # a return value of 0 will stop exection becuase it matches the
        # default value.
        def retrieve
            return_value = :need_to_run
            filter = self.resource[:onlyif]
            unless (filter == "")
                cmd_array = filter.split
                command = cmd_array[0];
                cmd_array[1]= File.join(resource[:context], cmd_array[1])
                begin
                    case command
                        when "get" then return_value = process_get(cmd_array)
                        when "match" then return_value = process_match(cmd_array)
                    end
                rescue Exception => e
                    fail("Error sending command '#{command}' with params #{cmd_array[1..-1].inspect}/#{e.message}")
                end
            end
            return_value
        end

        # Actually execute the command.
        def sync
            aug = open_augeas
            commands = self.resource[:changes]
            commands.each do |cmd_array|
                fail("invalid command #{cmd_array.join[" "]}") if cmd_array.length < 2
                command = cmd_array[0]
                cmd_array.shift()
                cmd_array[0]=File.join(resource[:context], cmd_array[0])
                debug("sending command '#{command}' with params #{cmd_array.inspect}")
                begin
                    case command
                        when "set": aug.set(cmd_array[0], cmd_array[1])
                        when "rm", "remove": aug.rm(cmd_array[0])
                        when "clear": aug.clear(cmd_array[0])
                        when "insert", "ins": aug.insert(cmd_array[0])
                        else fail("Command '#{command}' is not supported")
                    end
                rescue Exception => e
                    fail("Error sending command '#{command}' with params #{cmd_array.inspect}/#{e.message}")
                end
            end
            success = aug.save()
            if (success != true)
                fail("Save failed with return code #{success}")
            end

            return :executed
        end
    end
end
