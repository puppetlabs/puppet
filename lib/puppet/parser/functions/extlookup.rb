require 'csv'

module Puppet::Parser::Functions
  newfunction(:extlookup,
  :type => :rvalue,
  :arity => -2,
  :doc => "This is a parser function to read data from external files, this version
uses CSV files but the concept can easily be adjust for databases, yaml
or any other queryable data source.

The object of this is to make it obvious when it's being used, rather than
magically loading data in when a module is loaded I prefer to look at the code
and see statements like:

    $snmp_contact = extlookup(\"snmp_contact\")

The above snippet will load the snmp_contact value from CSV files, this in its
own is useful but a common construct in puppet manifests is something like this:

    case $domain {
      \"myclient.com\": { $snmp_contact = \"John Doe <john@myclient.com>\" }
      default:        { $snmp_contact = \"My Support <support@my.com>\" }
    }

Over time there will be a lot of this kind of thing spread all over your manifests
and adding an additional client involves grepping through manifests to find all the
places where you have constructs like this.

This is a data problem and shouldn't be handled in code, and using this function you
can do just that.

First you configure it in site.pp:

    $extlookup_datadir = \"/etc/puppet/manifests/extdata\"
    $extlookup_precedence = [\"%{fqdn}\", \"domain_%{domain}\", \"common\"]

The array tells the code how to resolve values, first it will try to find it in
web1.myclient.com.csv then in domain_myclient.com.csv and finally in common.csv

Now create the following data files in /etc/puppet/manifests/extdata:

    domain_myclient.com.csv:
      snmp_contact,John Doe <john@myclient.com>
      root_contact,support@%{domain}
      client_trusted_ips,192.168.1.130,192.168.10.0/24

    common.csv:
      snmp_contact,My Support <support@my.com>
      root_contact,support@my.com

Now you can replace the case statement with the simple single line to achieve
the exact same outcome:

    $snmp_contact = extlookup(\"snmp_contact\")

The above code shows some other features, you can use any fact or variable that
is in scope by simply using %{varname} in your data files, you can return arrays
by just having multiple values in the csv after the initial variable name.

In the event that a variable is nowhere to be found a critical error will be raised
that will prevent your manifest from compiling, this is to avoid accidentally putting
in empty values etc.  You can however specify a default value:

    $ntp_servers = extlookup(\"ntp_servers\", \"1.${country}.pool.ntp.org\")

In this case it will default to \"1.${country}.pool.ntp.org\" if nothing is defined in
any data file.

You can also specify an additional data file to search first before any others at use
time, for example:

    $version = extlookup(\"rsyslog_version\", \"present\", \"packages\")
    package{\"rsyslog\": ensure => $version }

This will look for a version configured in packages.csv and then in the rest as configured
by $extlookup_precedence if it's not found anywhere it will default to `present`, this kind
of use case makes puppet a lot nicer for managing large amounts of packages since you do not
need to edit a load of manifests to do simple things like adjust a desired version number.

Precedence values can have variables embedded in them in the form %{fqdn}, you could for example do:

    $extlookup_precedence = [\"hosts/%{fqdn}\", \"common\"]

This will result in /path/to/extdata/hosts/your.box.com.csv being searched.

This is for back compatibility to interpolate variables with %. % interpolation is a workaround for a problem that has been fixed: Puppet variable interpolation at top scope used to only happen on each run.") do |args|

  key = args[0]

  default  = args[1]
  datafile = args[2]

  raise ArgumentError, ("extlookup(): wrong number of arguments (#{args.length}; must be <= 3)") if args.length > 3

  extlookup_datadir = undef_as('',self['::extlookup_datadir'])

  extlookup_precedence = undef_as([],self['::extlookup_precedence']).collect { |var| var.gsub(/%\{(.+?)\}/) { self["::#{$1}"] } }

  datafiles = Array.new

  # if we got a custom data file, put it first in the array of search files
  if datafile != ""
    datafiles << extlookup_datadir + "/#{datafile}.csv" if Puppet::FileSystem.exist?(extlookup_datadir + "/#{datafile}.csv")
  end

  extlookup_precedence.each do |d|
    datafiles << extlookup_datadir + "/#{d}.csv"
  end

  desired = nil

  datafiles.each do |file|
    if desired.nil?
      if Puppet::FileSystem.exist?(file)
        result = CSV.read(file).find_all do |r|
          r[0] == key
        end

        # return just the single result if theres just one,
        # else take all the fields in the csv and build an array
        if result.length > 0
          if result[0].length == 2
            val = result[0][1].to_s

            # parse %{}'s in the CSV into local variables using the current scope
            while val =~ /%\{(.+?)\}/
              val.gsub!(/%\{#{$1}\}/, self[$1])
            end

            desired = val
          elsif result[0].length > 1
            length = result[0].length
            cells = result[0][1,length]

            # Individual cells in a CSV result are a weird data type and throws
            # puppets yaml parsing, so just map it all to plain old strings
            desired = cells.map do |c|
              # parse %{}'s in the CSV into local variables using the current scope
              while c =~ /%\{(.+?)\}/
                c.gsub!(/%\{#{$1}\}/, self[$1])
              end

              c.to_s
            end
          end
        end
      end
    end
  end

  desired || default or raise Puppet::ParseError, "No match found for '#{key}' in any data file during extlookup()"
  end
end
