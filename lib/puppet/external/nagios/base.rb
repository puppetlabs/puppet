# The base class for all of our Nagios object types.  Everything else
# is mostly just data.
class Nagios::Base

    class UnknownNagiosType < RuntimeError # When an unknown type is asked for by name.
    end

    include Enumerable

    class << self
        attr_accessor :parameters, :derivatives, :ocs, :name, :att
        attr_accessor :ldapbase

        attr_writer :namevar

        attr_reader :superior
    end

    # Attach one class to another.
    def self.attach(hash)
        @attach ||= {}
        hash.each do |n, v| @attach[n] = v end
    end

    # Convert a parameter to camelcase
    def self.camelcase(param)
        param.gsub(/_./) do |match|
            match.sub(/_/,'').capitalize
        end
    end

    # Uncamelcase a parameter.
    def self.decamelcase(param)
        param.gsub(/[A-Z]/) do |match|
            "_" + match.downcase
        end
    end

    # Create a new instance of a given class.
    def self.create(name, args = {})
        name = name.intern if name.is_a? String

        if @types.include?(name)
            @types[name].new(args)
        else
            raise UnknownNagiosType, "Unknown type %s" % name
        end
    end

    # Yield each type in turn.
    def self.eachtype
        @types.each do |name, type|
            yield [name, type]
        end
    end

    # Create a mapping.
    def self.map(hash)
        @map ||= {}
        hash.each do |n, v| @map[n] = v end
    end

    # Return a mapping (or nil) for a param
    def self.mapping(name)
        name = name.intern if name.is_a? String
        if defined? @map
            @map[name]
        else
            nil
        end
    end

    # Return the namevar for the canonical name.
    def self.namevar
        if defined? @namevar
            return @namevar
        else
            if parameter?(:name)
                return :name
            elsif tmp = (self.name.to_s + "_name").intern and parameter?(tmp)
                @namevar = tmp
                return @namevar
            else
                raise "Type %s has no name var" % self.name
            end
        end
    end

    # Create a new type.
    def self.newtype(name, &block)
        name = name.intern if name.is_a? String

        @types ||= {}

        # Create the class, with the correct name.
        t = Class.new(self)
        t.name = name

        # Everyone gets this.  There should probably be a better way, and I
        # should probably hack the attribute system to look things up based on
        # this "use" setting, but, eh.
        t.parameters = [:use]

        const_set(name.to_s.capitalize,t)

        # Evaluate the passed block.  This should usually define all of the work.
        t.class_eval(&block)

        @types[name] = t
    end

    # Define both the normal case and camelcase method for a parameter
    def self.paramattr(name)
        camel = camelcase(name)
        param = name

        [name, camel].each do |method|
            define_method(method) do
                @parameters[param]
            end

            define_method(method.to_s + "=") do |value|
                @parameters[param] = value
            end
        end

    end

    # Is the specified name a valid parameter?
    def self.parameter?(name)
        name = name.intern if name.is_a? String
        return @parameters.include?(name)
    end

    # Manually set the namevar
    def self.setnamevar(name)
        name = name.intern if name.is_a? String
        @namevar = name
    end

    # Set the valid parameters for this class
    def self.setparameters(*array)
        @parameters += array
    end

    # Set the superior ldap object class.  Seems silly to include this
    # in this class, but, eh.
    def self.setsuperior(name)
        @superior = name
    end

    # Parameters to suppress in output.
    def self.suppress(name)
        @suppress ||= []
        @suppress << name
    end

    # Whether a given parameter is suppressed.
    def self.suppress?(name)
        defined? @suppress and @suppress.include?(name)
    end

    # Return our name as the string.
    def self.to_s
        self.name.to_s
    end

    # Return a type by name.
    def self.type(name)
        name = name.intern if name.is_a? String

        @types[name]
    end

    # Convenience methods.
    def [](param)
        send(param)
    end

    # Convenience methods.
    def []=(param,value)
        send(param.to_s + "=", value)
    end

    # Iterate across all ofour set parameters.
    def each
        @parameters.each { |param,value|
            yield(param,value)
        }
    end

    # Initialize our object, optionally with a list of parameters.
    def initialize(args = {})
        @parameters = {}

        args.each { |param,value|
            self[param] = value
        }
        if @namevar == :_naginator_name
          self['_naginator_name'] = self['name']
        end
    end

    # Handle parameters like attributes.
    def method_missing(mname, *args)
        pname = mname.to_s
        pname.sub!(/=/, '')

        if self.class.parameter?(pname)
            if pname =~ /A-Z/
                pname = self.class.decamelcase(pname)
            end
            self.class.paramattr(pname)

            # Now access the parameters directly, to make it at least less
            # likely we'll end up in an infinite recursion.
            if mname.to_s =~ /=$/
                @parameters[pname] = *args
            else
                return @parameters[mname]
            end
        else
            super
        end
    end

    # Retrieve our name, through a bit of redirection.
    def name
        send(self.class.namevar)
    end

    # This is probably a bad idea.
    def name=(value)
        unless self.class.namevar.to_s == "name"
            send(self.class.namevar.to_s + "=", value)
        end
    end

    def namevar
        return (self.type + "_name").intern
    end

    def parammap(param)
        unless defined? @map
            map = {
                self.namevar => "cn"
            }
            if self.class.map
                map.update(self.class.map)
            end
        end
        if map.include?(param)
            return map[param]
        else
            return "nagios-" + param.id2name.gsub(/_/,'-')
        end
    end

    def parent
        unless defined? self.class.attached
            puts "Duh, you called parent on an unattached class"
            return
        end

        klass,param = self.class.attached
        unless @parameters.include?(param)
            puts "Huh, no attachment param"
            return
        end
        klass[@parameters[param]]
    end

    # okay, this sucks
    # how do i get my list of ocs?
    def to_ldif
        base = self.class.ldapbase
        str = self.dn + "\n"
        ocs = Array.new
        if self.class.ocs
            # i'm storing an array, so i have to flatten it and stuff
            kocs = self.class.ocs
            ocs.push(*kocs)
        end
        ocs.push "top"
        oc = self.class.to_s
        oc.sub!(/Nagios/,'nagios')
        oc.sub!(/::/,'')
        ocs.push oc
        ocs.each { |oc|
            str += "objectclass: " + oc + "\n"
        }
        @parameters.each { |name,value|
            if self.class.suppress.include?(name)
                next
            end
            ldapname = self.parammap(name)
            str += ldapname + ": " + value + "\n"
        }
        str += "\n"
        str
    end

    def to_s
        str = "define #{self.type} {\n"

        self.each { |param,value|
            str += %{\t%-30s %s\n} % [ param,
                if value.is_a? Array
                    value.join(",")
                else
                    value
                end
                ]
        }

        str += "}\n"

        str
    end

    # The type of object we are.
    def type
        self.class.name
    end

    # object types
    newtype :host do
        setparameters :host_name, :alias, :display_name, :address, :parents,
            :hostgroups, :check_command, :initial_state, :max_check_attempts,
            :check_interval, :retry_interval, :active_checks_enabled,
            :passive_checks_enabled, :check_period, :obsess_over_host,
            :check_freshness, :freshness_threshold, :event_handler,
            :event_handler_enabled, :low_flap_threshold, :high_flap_threshold,
            :flap_detection_enabled, :flap_detection_options,
            :failure_prediction_enabled, :process_perf_data,
            :retain_status_information, :retain_nonstatus_information, :contacts,
            :contact_groups, :notification_interval, :first_notification_delay,
            :notification_period, :notification_options, :notifications_enabled,
            :stalking_options, :notes, :notes_url, :action_url, :icon_image,
            :icon_image_alt, :vrml_image, :statusmap_image, "2d_coords".intern,
            "3d_coords".intern,
            :register, :use

        setsuperior "person"
        map :address => "ipHostNumber"
    end

    newtype :hostgroup do
      setparameters :hostgroup_name, :alias, :members, :hostgroup_members, :notes,
          :notes_url, :action_url,
          :register, :use
    end

    newtype :service do
        attach :host => :host_name
        setparameters :host_name, :hostgroup_name, :service_description,
            :display_name, :servicegroups, :is_volatile, :check_command,
            :initial_state, :max_check_attempts, :check_interval, :retry_interval,
            :normal_check_interval, :retry_check_interval, :active_checks_enabled,
            :passive_checks_enabled, :parallelize_check, :check_period,
            :obsess_over_service, :check_freshness, :freshness_threshold,
            :event_handler, :event_handler_enabled, :low_flap_threshold,
            :high_flap_threshold, :flap_detection_enabled,:flap_detection_options,
            :process_perf_data, :failure_prediction_enabled, :retain_status_information,
            :retain_nonstatus_information, :notification_interval,
            :first_notification_delay, :notification_period, :notification_options,
            :notifications_enabled, :contacts, :contact_groups, :stalking_options,
            :notes, :notes_url, :action_url, :icon_image, :icon_image_alt,
            :register, :use,
            :_naginator_name

        suppress :host_name

        setnamevar :_naginator_name
    end

    newtype :servicegroup do
        setparameters :servicegroup_name, :alias, :members, :servicegroup_members,
            :notes, :notes_url, :action_url,
            :register, :use
    end

    newtype :contact do
        setparameters :contact_name, :alias, :contactgroups,
            :host_notifications_enabled, :service_notifications_enabled,
            :host_notification_period, :service_notification_period,
            :host_notification_options, :service_notification_options,
            :host_notification_commands, :service_notification_commands,
            :email, :pager, :address1, :address2, :address3, :address4,
            :address5, :address6, :can_submit_commands, :retain_status_information,
            :retain_nonstatus_information,
            :register, :use

        setsuperior "person"
    end

    newtype :contactgroup do
        setparameters :contactgroup_name, :alias, :members, :contactgroup_members,
            :register, :use
    end

    # TODO - We should support generic time periods here eg "day 1 - 15"
    newtype :timeperiod do
        setparameters :timeperiod_name, :alias, :sunday, :monday, :tuesday,
            :wednesday, :thursday, :friday, :saturday, :exclude,
            :register, :use
    end

    newtype :command do
        setparameters :command_name, :command_line
    end

    newtype :servicedependency do
        auxiliary = true
        setparameters :dependent_host_name, :dependent_hostgroup_name,
            :dependent_service_description, :host_name, :hostgroup_name,
            :service_description, :inherits_parent, :execution_failure_criteria,
            :notification_failure_criteria, :dependency_period,
            :register, :use,
            :_naginator_name

        setnamevar :_naginator_name
    end

    newtype :serviceescalation do
        setparameters :host_name, :hostgroup_name, :servicegroup_name,
            :service_description, :contacts, :contact_groups,
            :first_notification, :last_notification, :notification_interval,
            :escalation_period, :escalation_options,
            :register, :use,
            :_naginator_name

        setnamevar :_naginator_name
    end

    newtype :hostdependency do
      auxiliary = true
      setparameters :dependent_host_name, :dependent_hostgroup_name, :host_name,
          :hostgroup_name, :inherits_parent, :execution_failure_criteria,
          :notification_failure_criteria, :dependency_period,
          :register, :use,
          :_naginator_name

      setnamevar :_naginator_name
    end

    newtype :hostescalation do
        setparameters :host_name, :hostgroup_name, :contacts, :contact_groups,
            :first_notification, :last_notification, :notification_interval,
            :escalation_period, :escalation_options,
            :register, :use,
            :_naginator_name

        setnamevar :_naginator_name
    end

    newtype :hostextinfo do
        auxiliary = true
        setparameters :host_name, :notes, :notes_url, :icon_image, :icon_image_alt,
            :vrml_image, :statusmap_image, "2d_coords".intern, "3d_coords".intern,
            :register, :use

        setnamevar :host_name
    end

    newtype :serviceextinfo do
        auxiliary = true

        setparameters :host_name, :service_description, :notes, :notes_url,
            :action_url, :icon_image, :icon_image_alt,
            :register, :use,
            :_naginator_name

        setnamevar :_naginator_name
    end

end

# $Id$
