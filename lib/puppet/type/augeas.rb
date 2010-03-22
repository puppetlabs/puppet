#--
#  Copyright (C) 2008 Red Hat Inc.
#
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU General Public
#  License as published by the Free Software Foundation; either
#  version 2 of the License, or (at your option) any later version.
#
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  General Public License for more details.
#
#  You should have received a copy of the GNU General Public
#  License along with this library; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307  USA
#
# Author: Bryan Kearney <bkearney@redhat.com>

Puppet::Type.newtype(:augeas) do
    include Puppet::Util

    feature :parse_commands, "Parse the command string"
    feature :need_to_run?, "If the command should run"
    feature :execute_changes, "Actually make the changes"

    @doc = "Apply the changes (single or array of changes) to the filesystem
        via the augeas tool.

         Requires:
           - augeas to be installed (http://www.augeas.net)
           - ruby-augeas bindings

         Sample usage with a string::

            augeas{\"test1\" :
                   context => \"/files/etc/sysconfig/firstboot\",
                   changes => \"set RUN_FIRSTBOOT YES\",
                   onlyif  => \"match other_value size > 0\",
             }

         Sample usage with an array and custom lenses::

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
        desc "Optional context path. This value is pre-pended to the paths of all changes if the
              path is relative. So a path specified as /files/foo will not be prepended with the
              context whild files/foo will be prepended"
        defaultto ""
    end

    newparam (:onlyif) do
        desc "Optional augeas command and comparisons to control the execution of this type.
             Supported onlyif syntax::

               get [AUGEAS_PATH] [COMPARATOR] [STRING]
               match [MATCH_PATH] size [COMPARATOR] [INT]
               match [MATCH_PATH] include [STRING]
               match [MATCH_PATH] not_include [STRING]
               match [MATCH_PATH] == [AN_ARRAY]
               match [MATCH_PATH] != [AN_ARRAY]

             where::

               AUGEAS_PATH is a valid path scoped by the context
               MATCH_PATH is a valid match synatx scoped by the context
               COMPARATOR is in the set [> >= != == <= <]
               STRING is a string
               INT is a number
               AN_ARRAY is in the form ['a string', 'another']"
        defaultto ""
    end


    newparam(:changes) do
        desc "The changes which should be applied to the filesystem. This
        can be either a string which contains a command or an array of commands.
        Commands supported are::

          set [PATH] [VALUE]     Sets the value VALUE at loction PATH
          rm [PATH]              Removes the node at location PATH
          remove [PATH]          Synonym for rm
          clear [PATH]           Keeps the node at PATH, but removes the value.
          ins [LABEL] [WHERE] [PATH]
                                 Inserts an empty node LABEL either [WHERE={before|after}] PATH.
          insert [LABEL] [WHERE] [PATH]
                                 Synonym for ins

        If the parameter 'context' is set that value is prepended to PATH"
    end


    newparam(:root) do
        desc "A file system path; all files loaded by Augeas are loaded underneath ROOT"
        defaultto "/"
    end

    newparam(:load_path) do
        desc "Optional colon separated list of directories; these directories are searched for schema definitions"
        defaultto ""
    end

    newparam(:force) do
        desc "Optional command to force the augeas type to execute even if it thinks changes
        will not be made. This does not overide the only setting. If onlyif is set, then the
        foce setting will not override that result"

        defaultto false
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

        # Make output a bit prettier
        def change_to_s(currentvalue, newvalue)
            return "executed successfully"
        end

        # if the onlyif resource is provided, then the value is parsed.
        # a return value of 0 will stop exection because it matches the
        # default value.
        def retrieve
            if @resource.provider.need_to_run?()
                :need_to_run
            else
                0
            end
        end

        # Actually execute the command.
        def sync
            @resource.provider.execute_changes()
        end
    end

end
