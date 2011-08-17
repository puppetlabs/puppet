#
#   Copyright 2011 Bryan Kearney <bkearney@redhat.com>
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

Puppet::Type.newtype(:augeas) do
  include Puppet::Util

  feature :parse_commands, "Parse the command string"
  feature :need_to_run?, "If the command should run"
  feature :execute_changes, "Actually make the changes"

  @doc = <<-EOT
    Apply the changes (single or array of changes) to the filesystem
    via the augeas tool.

    Requires:

    - augeas to be installed (http://www.augeas.net)
    - ruby-augeas bindings

    Sample usage with a string:

        augeas{"test1" :
          context => "/files/etc/sysconfig/firstboot",
          changes => "set RUN_FIRSTBOOT YES",
          onlyif  => "match other_value size > 0",
        }

    Sample usage with an array and custom lenses:

        augeas{"jboss_conf":
          context => "/files",
          changes => [
            "set etc/jbossas/jbossas.conf/JBOSS_IP $ipaddress",
            "set etc/jbossas/jbossas.conf/JAVA_HOME /usr",
          ],
          load_path => "$/usr/share/jbossas/lenses",
        }

  EOT

  newparam (:name) do
    desc "The name of this task. Used for uniqueness"
    isnamevar
  end

  newparam (:context) do
    desc "Optional context path. This value is prepended to the paths of all changes if the path is relative. If INCL is set, defaults to '/files' + INCL, otherwise the empty string"
    defaultto ""
    munge do |value|
      if value.empty? and resource[:incl]
        "/files" + resource[:incl]
      else
        value
      end
    end
  end

  newparam (:onlyif) do
    desc "Optional augeas command and comparisons to control the execution of this type.
      Supported onlyif syntax:

          get [AUGEAS_PATH] [COMPARATOR] [STRING]
          match [MATCH_PATH] size [COMPARATOR] [INT]
          match [MATCH_PATH] include [STRING]
          match [MATCH_PATH] not_include [STRING]
          match [MATCH_PATH] == [AN_ARRAY]
          match [MATCH_PATH] != [AN_ARRAY]

      where:

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
    Commands supported are:

        set [PATH] [VALUE]            Sets the value VALUE at loction PATH
        setm [PATH] [SUB] [VALUE]     Sets multiple nodes matching SUB relative to PATH, to VALUE
        rm [PATH]                     Removes the node at location PATH
        remove [PATH]                 Synonym for rm
        clear [PATH]                  Sets the node at PATH to NULL, creating it if needed
        ins [LABEL] [WHERE] [PATH]    Inserts an empty node LABEL either [WHERE={before|after}] PATH.
        insert [LABEL] [WHERE] [PATH] Synonym for ins
        mv [PATH] [PATH]              Moves a node at PATH to the new location PATH
        move [PATH] [PATH]            Synonym for mv
        defvar [NAME] [PATH]          Sets Augeas variable $NAME to PATH
        defnode [NAME] [PATH] [VALUE] Sets Augeas variable $NAME to PATH, creating it with VALUE if needed

    If the parameter 'context' is set that value is prepended to a relative PATH"
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

  newparam(:lens) do
    desc "Use a specific lens, e.g. `Hosts.lns`. When this parameter is set, you must also set the incl parameter to indicate which file to load. Only that file will be loaded, which greatly speeds up execution of the type"
  end

  newparam(:incl) do
    desc "Load only a specific file, e.g. `/etc/hosts`.  When this parameter is set, you must also set the lens parameter to indicate which lens to use."
  end

  validate do
    has_lens = !self[:lens].nil?
    has_incl = !self[:incl].nil?
    self.fail "You must specify both the lens and incl parameters, or neither" if has_lens != has_incl
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
      "executed successfully"
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
      @resource.provider.execute_changes
    end
  end

end
