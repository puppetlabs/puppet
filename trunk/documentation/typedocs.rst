==============
Type Reference
==============

    

---------------
Meta-Parameters
---------------

Metaparameters are parameters that work with any element; they are part of the
Puppet framework itself rather than being part of the implementation of any
given instance.  Thus, any defined metaparameter can be used with any instance
in your manifest, including defined components.

    
- **alias**
    Creates an alias for the object.  Puppet uses this internally when you
    provide a symbolic name::
    
        file { sshdconfig:
            path => $operatingsystem ? {
                solaris => "/usr/local/etc/ssh/sshd_config",
                default => "/etc/ssh/sshd_config"
            },
            source => "..."
        }
    
        service { sshd:
            subscribe => file[sshdconfig]
        }
    
    When you use this feature, the parser sets ``sshdconfig`` as the name,
    and the library sets that as an alias for the file so the dependency
    lookup for ``sshd`` works.  You can use this parameter yourself,
    but note that only the library can use these aliases; for instance,
    the following code will not work::
    
        file { "/etc/ssh/sshd_config":
            owner => root,
            group => root,
            alias => sshdconfig
        }
    
        file { sshdconfig:
            mode => 644
        }
    
    There's no way here for the Puppet parser to know that these two stanzas
    should be affecting the same file.
    
    See the `language tutorial <http://reductivelabs.com/projects/puppet/documentation/languagetutorial>`__ for more information.
    
- **check**
    States which should have their values retrieved
    but which should not actually be modified.  This is currently used
    internally, but will eventually be used for querying, so that you
    could specify that you wanted to check the install state of all
    packages, and then query the Puppet client daemon to get reports
    on all packages.
- **loglevel**
    Sets the level that information will be logged.
    The log levels have the biggest impact when logs are sent to
    syslog (which is currently the default).  Valid values are ``debug``, ``info``, ``notice``, ``warning``, ``err``, ``alert``, ``emerg``, ``crit``, ``verbose``.
- **noop**
    Boolean flag indicating whether work should actually
    be done.  *true*/**false**
- **require**
    One or more objects that this object depends on.
    This is used purely for guaranteeing that changes to required objects
    happen before the dependent object.  For instance::
    
        # Create the destination directory before you copy things down
        file { "/usr/local/scripts":
            ensure => directory
        }
    
        file { "/usr/local/scripts/myscript":
            source => "puppet://server/module/myscript",
            mode => 755,
            require => file["/usr/local/scripts"]
        }
    
    Note that Puppet will autorequire everything that it can, and
    there are hooks in place so that it's easy for elements to add new
    ways to autorequire objects, so if you think Puppet could be
    smarter here, let us know.
    
    In fact, the above code was redundant -- Puppet will autorequire
    any parent directories that are being managed; it will
    automatically realize that the parent directory should be created
    before the script is pulled down.
    
    Currently, exec_ elements will autorequire their CWD (if it is
    specified) plus any fully qualified paths that appear in the
    command.   For instance, if you had an ``exec`` command that ran
    the ``myscript`` mentioned above, the above code that pulls the
    file down would be automatically listed as a requirement to the
    ``exec`` code, so that you would always be running againts the
    most recent version.
- **schedule**
    On what schedule the object should be managed.  You must create a
    schedule_ object, and then reference the name of that object to use
    that for your schedule::
    
        schedule { daily:
            period => daily,
            range => "2-4"
        }
    
        exec { "/usr/bin/apt-get update":
            schedule => daily
        }
    
    The creation of the schedule object does not need to appear in the
    configuration before objects that use it.
- **subscribe**
    One or more objects that this object depends on.  Changes in the
    subscribed to objects result in the dependent objects being
    refreshed (e.g., a service will get restarted).  For instance::
    
        class nagios {
            file { "/etc/nagios/nagios.conf":
                source => "puppet://server/module/nagios.conf",
                alias => nagconf # just to make things easier for me
            }
    
            service { nagios:
                running => true,
                subscribe => file[nagconf]
            }
        }
- **tag**
    Add the specified tags to the associated element.  While all elements
    are automatically tagged with as much information as possible
    (e.g., each class and component containing the element), it can
    be useful to add your own tags to a given element.
    
    Tags are currently useful for things like applying a subset of a
    host's configuration::
        
        puppetd --test --tag mytag
    
    This way, when you're testing a configuration you can run just the
    portion you're testing.

-----
Types
-----

- *namevar* is the parameter used to uniquely identify a type instance.
  This is the parameter that gets assigned when a string is provided before
  the colon in a type declaration.  In general, only developers will need to
  worry about which parameter is the ``namevar``.
  
  In the following code::

    file { "/etc/passwd":
        owner => root,
        group => root,
        mode => 644
    }

  "/etc/passwd" is considered the name of the file object (used for things like
  dependency handling), and because ``path`` is the namevar for ``file``, that
  string is assigned to the ``path`` parameter.

- *parameters* determine the specific configuration of the instance.  They either
  directly modify the system (internally, these are called states) or they affect
  how the instance behaves (e.g., adding a search path for ``exec`` instances
  or determining recursion on ``file`` instances).

    


----------------


cron
========
Installs and manages cron jobs.  All fields except the command 
and the user are optional, although specifying no periodic
fields would result in the command being executed every
minute.  While the name of the cron job is not part of the actual
job, it is used by Puppet to store and retrieve it.

If you specify a cron job that matches an existing job in every way
except name, then the jobs will be considered equivalent and the
new name will be permanently associated with that job.  Once this
association is made and synced to disk, you can then manage the job
normally (e.g., change the schedule of the job).

Example::
    
    cron { logrotate:
        command => "/usr/sbin/logrotate",
        user => root,
        hour => 2,
        minute => 0
    }



Cron Parameters
''''''''''''''''''''''''''''''
- **command**
    The command to execute in the cron job.  The environment
    provided to the command varies by local system rules, and it is
    best to always provide a fully qualified command.  The user's
    profile is not sourced when the command is run, so if the
    user's environment is desired it should be sourced manually.
    
    All cron parameters support ``absent`` as a value; this will
    remove any existing values for that field.
- **ensure**
    The basic state that the object should be in.  Valid values are ``absent``, ``present``.
- **hour**
    The hour at which to run the cron job. Optional;
    if specified, must be between 0 and 23, inclusive.
- **minute**
    The minute at which to run the cron job.
    Optional; if specified, must be between 0 and 59, inclusive.
- **month**
    The month of the year.  Optional; if specified
    must be between 1 and 12 or the month name (e.g., December).
- **monthday**
    The day of the month on which to run the
    command.  Optional; if specified, must be between 1 and 31.
- **name**
    The symbolic name of the cron job.  This name
    is used for human reference only and is generated automatically
    for cron jobs found on the system.  This generally won't
    matter, as Puppet will do its best to match existing cron jobs
    against specified jobs (and Puppet adds a comment to cron jobs it
    adds), but it is at least possible that converting from
    unmanaged jobs to managed jobs might require manual
    intervention.
    
    The names can only have alphanumeric characters plus the '-'
    character.
- **user**
    The user to run the command as.  This user must
    be allowed to run cron jobs, which is not currently checked by
    Puppet.
    
    The user defaults to whomever Puppet is running as.
- **weekday**
    The weekday on which to run the command.
    Optional; if specified, must be between 0 and 6, inclusive, with
    0 being Sunday, or must be the name of the day (e.g., Tuesday).



----------------


exec
========
Executes external commands.  It is critical that all commands
executed using this mechanism can be run multiple times without
harm, i.e., they are *idempotent*.  One useful way to create idempotent
commands is to use the *creates* parameter.

It is worth noting that ``exec`` is special, in that it is not
currently considered an error to have multiple ``exec`` instances
with the same name.  This was done purely because it had to be this
way in order to get certain functionality, but it complicates things.
In particular, you will not be able to use ``exec`` instances that
share their commands with other instances as a dependency, since
Puppet has no way of knowing which instance you mean.

For example::

    # defined in the production class
    exec { "make":
        cwd => "/prod/build/dir",
        path => "/usr/bin:/usr/sbin:/bin"
    }

    . etc. .

    # defined in the test class
    exec { "make":
        cwd => "/test/build/dir",
        path => "/usr/bin:/usr/sbin:/bin"
    }

Any other type would throw an error, complaining that you had
the same instance being managed in multiple places, but these are
obviously different images, so ``exec`` had to be treated specially.

It is recommended to avoid duplicate names whenever possible.

There is a strong tendency to use ``exec`` to do whatever work Puppet
can't already do; while this is obviously acceptable (and unavoidable)
in the short term, it is highly recommended to migrate work from ``exec``
to real Puppet element types as quickly as possible.  If you find that
you are doing a lot of work with ``exec``, please at least notify
us at Reductive Labs what you are doing, and hopefully we can work with
you to get a native element type for the work you are doing.  In general,
it is a Puppet bug if you need ``exec`` to do your work.


Exec Parameters
''''''''''''''''''''''''''''''
- **command** (*namevar*)
    The actual command to execute.  Must either be fully qualified
    or a search path for the command must be provided.  If the command
    succeeds, any output produced will be logged at the instance's
    normal log level (usually ``notice``), but if the command fails
    (meaning its return code does not match the specified code) then
    any output is logged at the ``err`` log level.
- **creates**
    A file that this command creates.  If this
    parameter is provided, then the command will only be run
    if the specified file does not exist.
    
    ::
    
        exec { "tar xf /my/tar/file.tar":
            cwd => "/var/tmp",
            creates => "/var/tmp/myfile",
            path => ["/usr/bin", "/usr/sbin"]
        }
    
- **cwd**
    The directory from which to run the command.  If
    this directory does not exist, the command will fail.
- **group**
    The group to run the command as.  This seems to work quite
    haphazardly on different platforms -- it is a platform issue
    not a Ruby or Puppet one, since the same variety exists when
    running commnands as different users in the shell.
- **logoutput**
    Whether to log output.  Defaults to logging output at the
    loglevel for the ``exec`` element.  Values are **true**, *false*,
    and any legal log level.  Valid values are ``true``, ``false``, ``debug``, ``info``, ``notice``, ``warning``, ``err``, ``alert``, ``emerg``, ``crit``.
- **onlyif**
    If this parameter is set, then this +exec+ will only run if
    the command returns 0.  For example::
        
        exec { "logrotate":
            path => "/usr/bin:/usr/sbin:/bin",
            onlyif => "test `du /var/log/messages | cut -f1` -gt 100000"
        }
    
    This would run +logrotate+ only if that test returned true.
    
    Note that this command follows the same rules as the main command,
    which is to say that it must be fully qualified if the path is not set.
- **path**
    The search path used for command execution.
    Commands must be fully qualified if no path is specified.  Paths
    can be specified as an array or as a colon-separated list.
- **refreshonly**
    The command should only be run as a
    refresh mechanism for when a dependent object is changed.  It only
    makes sense to use this option when this command depends on some
    other object; it is useful for triggering an action::
        
        # Pull down the main aliases file
        file { "/etc/aliases":
            source => "puppet://server/module/aliases"
        }
    
        # Rebuild the database, but only when the file changes
        exec { newaliases:
            path => ["/usr/bin", "/usr/sbin"],
            subscribe => file["/etc/aliases"],
            refreshonly => true
        }
    
    Note that only ``subscribe`` can trigger actions, not ``require``,
    so it only makes sense to use ``refreshonly`` with ``subscribe``.  Valid values are ``true``, ``false``.
- **returns**
    The expected return code.  An error will be returned if the
    executed command returns something else.  Defaults to 0.
- **unless**
    If this parameter is set, then this +exec+ will run unless
    the command returns 0.  For example::
        
        exec { "/bin/echo root >> /usr/lib/cron/cron.allow":
            path => "/usr/bin:/usr/sbin:/bin",
            unless => "grep root /usr/lib/cron/cron.allow 2>/dev/null"
        }
    
    This would add +root+ to the cron.allow file (on Solaris) unless
    +grep+ determines it's already there.
    
    Note that this command follows the same rules as the main command,
    which is to say that it must be fully qualified if the path is not set.
- **user**
    The user to run the command as.  Note that if you
    use this then any error output is not currently captured.  This
    is because of a bug within Ruby.



----------------


file
========
Manages local files, including setting ownership and
permissions, creation of both files and directories, and
retrieving entire files from remote servers.  As Puppet matures, it
expected that the ``file`` element will be used less and less to
manage content, and instead native elements will be used to do so.

If you find that you are often copying files in from a central
location, rather than using native elements, please contact
Reductive Labs and we can hopefully work with you to develop a
native element to support what you are doing.


File Parameters
''''''''''''''''''''''''''''''
- **backup**
    Whether files should be backed up before
    being replaced.  If a filebucket_ is specified, files will be
    backed up there; else, they will be backed up in the same directory
    with a ``.puppet-bak`` extension.
    
    To use filebuckets, you must first create a filebucket in your
    configuration::
        
        filebucket { main:
            server => puppet
        }
    
    ``puppetmasterd`` creates a filebucket by default, so you can
    usually back up to your main server with this configuration.  Once
    you've described the bucket in your configuration, you can use
    it in any file::
    
        file { "/my/file":
            source => "/path/in/nfs/or/something",
            backup => main
        }
    
    This will back the file up to the central server.
    
    At this point, the only benefits to doing so are that you do not
    have backup files lying around on each of your machines, a given
    version of a file is only backed up once, and you can restore
    any given file manually, no matter how old.  Eventually,
    transactional support will be able to automatically restore
    filebucketed files.
- **checksum**
    How to check whether a file has changed.  **md5**/*lite-md5*/
    *time*/*mtime*  Valid values are ``md5lite``, ``time``, ``timestamp``, ``mtime``, ``nosum``, ``md5``.  Values can also match ``(?-mix:^\{md5|md5lite|timestamp|mtime|time\})``.
- **content**
    Specify the contents of a file as a string.  Newlines, tabs, and spaces
    can be specified using the escaped syntax (e.g., \n for a newline).  The
    primary purpose of this parameter is to provide a kind of limited
    templating::
    
        define resolve(nameserver1, nameserver2, domain, search) {
            $str = "search $search
        domain $domain
        nameserver $nameserver1
        nameserver $nameserver2
        "
    
            file { "/etc/resolv.conf":
                content => $str
            }
        }
    
    Yes, it's very primitive, and it's useless for larger files, but it
    is mostly meant as a stopgap measure for simple cases.
- **ensure**
    Whether to create files that don't currently exist.
    Possible values are *absent*, *present* (equivalent to *file*),
    *file*, and *directory*.  Specifying 'absent' will delete the file,
    although currently this will not recursively delete directories.
    
    Anything other than those values will be considered to be a symlink.
    For instance, the following text creates a link::
        
        # Useful on solaris
        file { "/etc/inetd.conf":
            ensure => "/etc/inet/inetd.conf"
        }
    
    You can make relative links::
        
        # Useful on solaris
        file { "/etc/inetd.conf":
            ensure => "inet/inetd.conf"
        }
    
    If you need to make a relative link to a file named the same
    as one of the valid values, you must prefix it with ``./`` or
    something similar.
    
    You can also make recursive symlinks, which will create a
    directory structure that maps to the target directory,
    with directories corresponding to each directory
    and links corresponding to each file.  Valid values are ``link``, ``absent`` (also called ``false``), ``directory``, ``file`` (also called ``present``).  Values can also match ``(?-mix:.)``.
- **group**
    Which group should own the file.  Argument can be either group
    name or group ID.
- **ignore**
    A parameter which omits action on files matching
    specified patterns during recursion.  Uses Ruby's builtin globbing
    engine, so shell metacharacters are fully supported, e.g. ``[a-z]*``.
    Matches that would descend into the directory structure are ignored,
    e.g., ``*/*``.
- **linkmaker**
    An internal parameter used by the *symlink*
    type to do recursive link creation.
- **links**
    How to handle links during file actions.  During file copying,
    ``follow`` will copy the target file instead of the link, ``manage``
    will copy the link itself, and ``ignore`` will just pass it by.
    When not copying, ``manage`` and ``ignore`` behave equivalently
    (because you cannot really ignore links entirely during local
    recursion), and ``follow`` will manage the file to which the
    link points.  Valid values are ``follow``, ``manage``, ``ignore``.
- **mode**
    Mode the file should be.  Currently relatively limited:
    you must specify the exact mode the file should be.
- **owner**
    To whom the file should belong.  Argument can be user name or
    user ID.
- **path** (*namevar*)
    The path to the file to manage.  Must be fully qualified.
- **recurse**
    Whether and how deeply to do recursive
    management.  Valid values are ``true``, ``false``, ``inf``.  Values can also match ``(?-mix:^[0-9]+$)``.
- **source**
    Copy a file over the current file.  Uses ``checksum`` to
    determine when a file should be copied.  Valid values are either
    fully qualified paths to files, or URIs.  Currently supported URI
    types are *puppet* and *file*.
    
    This is one of the primary mechanisms for getting content into
    applications that Puppet does not directly support and is very
    useful for those configuration files that don't change much across
    sytems.  For instance::
    
        class sendmail {
            file { "/etc/mail/sendmail.cf":
                source => "puppet://server/module/sendmail.cf"
            }
        }
    
    See the `fileserver docs`_ for information on how to configure
    and use file services within Puppet.
    
    
.. _fileserver docs: /projects/puppet/documentation/fsconfigref
    
- **target**
    The target for creating a link.  Currently, symlinks are the
    only type supported.  Valid values are ``notlink``.  Values can also match ``(?-mix:.)``.
- **type**
    A read-only state to check the file type.



----------------


filebucket
==============
A repository for backing up files.  If no filebucket is
defined, then files will be backed up in their current directory,
but the filebucket can be either a host- or site-global repository
for backing up.  It stores files and returns the MD5 sum, which
can later be used to retrieve the file if restoration becomes
necessary.  A filebucket does not do any work itself; instead,
it can be specified as the value of *backup* in a **file** object.

Currently, filebuckets are only useful for manual retrieval of
accidentally removed files (e.g., you look in the log for the md5
sum and retrieve the file with that sum from the filebucket), but
when transactions are fully supported filebuckets will be used to
undo transactions.


Filebucket Parameters
''''''''''''''''''''''''''''''
- **name**
    The name of the filebucket.
- **path**
    The path to the local filebucket.  If this is
    not specified, then the bucket is remote and *server* must be
    specified.
- **port**
    The port on which the remote server is listening.
    Defaults to the normal Puppet port, 8140.
- **server**
    The server providing the filebucket.  If this is
    not specified, then the bucket is local and *path* must be
    specified.



----------------


group
=========
Manage groups.  This type can only create groups.  Group
membership must be managed on individual users.  This element type
uses the prescribed native tools for creating groups and generally
uses POSIX APIs for retrieving information about them.  It does
not directly modify /etc/group or anything.

For most platforms, the tools used are ``groupadd`` and its ilk;
for Mac OS X, NetInfo is used.  This is currently unconfigurable,
but if you desperately need it to be so, please contact us.


Group Parameters
''''''''''''''''''''''''''''''
- **ensure**
    The basic state that the object should be in.  Valid values are ``absent``, ``present``.
- **gid**
    The group ID.  Must be specified numerically.  If not
    specified, a number will be picked, which can result in ID
    differences across systems and thus is not recommended.  The
    GID is picked according to local system standards.
- **name**
    The group name.  While naming limitations vary by
    system, it is advisable to keep the name to the degenerate
    limitations, which is a maximum of 8 characters beginning with
    a letter.



----------------


host
========
Installs and manages host entries.  For most systems, these
entries will just be in /etc/hosts, but some systems (notably OS X)
will have different solutions.


Host Parameters
''''''''''''''''''''''''''''''
- **alias**
    Any alias the host might have.  Multiple values must be
    specified as an array.  Note that this state has the same name
    as one of the metaparams; using this state to set aliases will
    make those aliases available in your Puppet scripts and also on
    disk.
- **ensure**
    The basic state that the object should be in.  Valid values are ``absent``, ``present``.
- **ip**
    The host's IP address.
- **name**
    The host name.



----------------


mount
=========
Manages mounted mounts, including putting mount
information into the mount table.


Mount Parameters
''''''''''''''''''''''''''''''
- **atboot**
    Whether to mount the mount at boot.  Not all platforms
    support this.
- **blockdevice**
    The the device to fsck.  This is state is only valid
    on Solaris, and in most cases will default to the correct
    value.
- **device**
    The device providing the mount.  This can be whatever
    device is supporting by the mount, including network
    devices or devices specified by UUID rather than device
    path, depending on the operating system.
- **dump**
    Whether to dump the mount.  Not all platforms
    support this.
- **ensure**
    Create, remove, or mount a filesystem mount.  Valid values are ``mounted``, ``absent``, ``present``.
- **fstype**
    The mount type.  Valid values depend on the
    operating system.
- **options**
    Mount options for the mounts, as they would
    appear in the fstab.
- **pass**
    The pass in which the mount is checked.
- **path** (*namevar*)
    The mount path for the mount.



----------------


package
===========
Manage packages.  There is a basic dichotomy in package
support right now:  Some package types (e.g., yum and apt) can
retrieve their own package files, while others (e.g., rpm and
sun) cannot.  For those package formats that cannot retrieve
their own files, you can use the ``source`` parameter to point to
the correct file.

Puppet will automatically guess the packaging format that you are
using based on the platform you are on, but you can override it
using the ``type`` parameter; obviously, if you specify that you
want to use ``rpm`` then the ``rpm`` tools must be available.


Package Parameters
''''''''''''''''''''''''''''''
- **adminfile**
    A file containing package defaults for installing packages.
    This is currently only used on Solaris.  The value will be
    validated according to system rules, which in the case of
    Solaris means that it should either be a fully qualified path
    or it should be in /var/sadm/install/admin.
- **category**
    A read-only parameter set by the package.
- **description**
    A read-only parameter set by the package.
- **ensure**
    What state the package should be in.
    *latest* only makes sense for those packaging formats that can
    retrieve new packages on their own and will throw an error on
    those that cannot.  Valid values are ``absent``, ``latest``, ``present`` (also called ``installed``).
- **instance**
    A read-only parameter set by the package.
- **name**
    The package name.  This is the name that the packaging
    system uses internally, which is sometimes (especially on Solaris)
    a name that is basically useless to humans.  If you want to
    abstract package installation, then you can use aliases to provide
    a common name to packages::
    
        # In the 'openssl' class
        $ssl = $operationgsystem ? {
            solaris => SMCossl,
            default => openssl
        }
    
        # It is not an error to set an alias to the same value as the
        # object name.
        package { $ssl:
            ensure => installed,
            alias => openssl
        }
    
        . etc. .
    
        $ssh = $operationgsystem ? {
            solaris => SMCossh,
            default => openssh
        }
    
        # Use the alias to specify a dependency, rather than
        # having another selector to figure it out again.
        package { $ssh:
            ensure => installed,
            alias => openssh,
            require => package[openssl]
        }
    
- **platform**
    A read-only parameter set by the package.
- **responsefile**
    A file containing any necessary answers to questions asked by
    the package.  This is currently only used on Solaris.  The
    value will be validated according to system rules, but it should
    generally be a fully qualified path.
- **root**
    A read-only parameter set by the package.
- **source**
    From where to retrieve the package.
- **status**
    A read-only parameter set by the package.
- **type**
    The package format.  You will seldom need to specify this --
    Puppet will discover the appropriate format for your platform.
- **vendor**
    A read-only parameter set by the package.
- **version**
    For some platforms this is a read-only parameter set by the
    package, but for others, setting this parameter will cause
    the package of that version to be installed.  It just depends
    on the features of the packaging system.



----------------


port
========
Installs and manages port entries.  For most systems, these
entries will just be in /etc/services, but some systems (notably OS X)
will have different solutions.


Port Parameters
''''''''''''''''''''''''''''''
- **alias**
    Any aliases the port might have.  Multiple values must be
    specified as an array.  Note that this state has the same name as
    one of the metaparams; using this state to set aliases will make
    those aliases available in your Puppet scripts and also on disk.
- **description**
    The port description.
- **ensure**
    The basic state that the object should be in.  Valid values are ``absent``, ``present``.
- **name**
    The port name.
- **number**
    The port number.
- **protocols**
    The protocols the port uses.  Valid values are *udp* and *tcp*.
    Most services have both protocols, but not all.  If you want
    both protocols, you must specify that; Puppet replaces the
    current values, it does not merge with them.  If you specify
    multiple protocols they must be as an array.



----------------


schedule
============
Defined schedules for Puppet.  The important thing to understand
about how schedules are currently implemented in Puppet is that they
can only be used to stop an element from being applied, they never
guarantee that it is applied.

Every time Puppet applies its configuration, it will collect the
list of elements whose schedule does not eliminate them from
running right then, but there is currently no system in place to
guarantee that a given element runs at a given time.  If you
specify a very  restrictive schedule and Puppet happens to run at a
time within that schedule, then the elements will get applied;
otherwise, that work may never get done.

Thus, it behooves you to use wider scheduling (e.g., over a couple of
hours) combined with periods and repetitions.  For instance, if you
wanted to restrict certain elements to only running once, between
the hours of two and 4 AM, then you would use this schedule::
    
    schedule { maint:
        range => "2 - 4",
        period => daily,
        repeat => 1
    }

With this schedule, the first time that Puppet runs between 2 and 4 AM,
all elements with this schedule will get applied, but they won't
get applied again between 2 and 4 because they will have already
run once that day, and they won't get applied outside that schedule
because they will be outside the scheduled range.

Puppet automatically creates a schedule for each valid period with the
same name as that period (e.g., hourly and daily).  Additionally,
a schedule named *puppet* is created and used as the default,
with the following attributes::

    schedule { puppet:
        period => hourly,
        repeat => 2
    }

This will cause elements to be applied every 30 minutes by default.



Schedule Parameters
''''''''''''''''''''''''''''''
- **name**
    The name of the schedule.  This name is used to retrieve the
    schedule when assigning it to an object::
        
        schedule { daily:
            period => daily,
            range => [2, 4]
        }
    
        exec { "/usr/bin/apt-get update":
            schedule => daily
        }
    
- **period**
    The period of repetition for an element.  Choose from among
    a fixed list of *hourly*, *daily*, *weekly*, and *monthly*.
    The default is for an element to get applied every time that
    Puppet runs, whatever that period is.
    
    Note that the period defines how often a given element will get
    applied but not when; if you would like to restrict the hours
    that a given element can be applied (e.g., only at night during
    a maintenance window) then use the ``range`` attribute.
    
    If the provided periods are not sufficient, you can provide a
    value to the *repeat* attribute, which will cause Puppet to
    schedule the affected elements evenly in the period the
    specified number of times.  Take this schedule::
    
        schedule { veryoften:
            period => hourly,
            repeat => 6
        }
    
    This can cause Puppet to apply that element up to every 10 minutes.
    
    At the moment, Puppet cannot guarantee that level of
    repetition; that is, it can run up to every 10 minutes, but
    internal factors might prevent it from actually running that
    often (e.g., long-running Puppet runs will squash conflictingly
    scheduled runs).
    
    See the ``periodmatch`` attribute for tuning whether to match
    times by their distance apart or by their specific value.  Valid values are ``hourly``, ``daily``, ``weekly``, ``monthly``.
- **periodmatch**
    Whether periods should be matched by number (e.g., the two times
    are in the same hour) or by distance (e.g., the two times are
    60 minutes apart). *number*/**distance**  Valid values are ``number``, ``distance``.
- **range**
    The earliest and latest that an element can be applied.  This
    is always a range within a 24 hour period, and hours must be
    specified in numbers between 0 and 23, inclusive.  Minutes and
    seconds can be provided, using the normal colon as a separator.
    For instance::
    
        schedule { maintenance:
            range => "1:30 - 4:30"
        }
    
    This is mostly useful for restricting certain elements to being
    applied in maintenance windows or during off-peak hours.
- **repeat**
    How often the application gets repeated in a given period.
    Defaults to 1.



----------------


service
===========
Manage running services.  Service support unfortunately varies
widely by platform -- some platforms have very little if any
concept of a running service, and some have a very codified and
powerful concept.  Puppet's service support will generally be able
to make up for any inherent shortcomings (e.g., if there is no
'status' command, then Puppet will look in the process table for a
command matching the service name), but the more information you
can provide the better behaviour you will get.  Or, you can just
use a platform that has very good service support.


Service Parameters
''''''''''''''''''''''''''''''
- **binary**
    The path to the daemon.  This is only used for
    systems that do not support init scripts.  This binary will be
    used to start the service if no ``start`` parameter is
    provided.
- **enable**
    Whether a service should be enabled to start at boot.
    This state behaves quite differently depending on the platform;
    wherever possible, it relies on local tools to enable or disable
    a given service.  *true*/*false*/*runlevels*  Valid values are ``true``, ``false``.
- **ensure**
    Whether a service should be running.  **true**/*false*  Valid values are ``running`` (also called ``true``), ``stopped`` (also called ``false``).
- **hasstatus**
    Declare the the service's init script has a
    functional status command.  Based on testing, it was found
    that a large number of init scripts on different platforms do
    not support any kind of status command; thus, you must specify
    manually whether the service you are running has such a
    command (or you can specify a specific command using the
    ``status`` parameter).
    
    If you do not specify anything, then the service name will be
    looked for in the process table.
- **name**
    The name of the service to run.  This name
    is used to find the service in whatever service subsystem it
    is in.
- **path**
    The search path for finding init scripts.
- **pattern**
    The pattern to search for in the process table.
    This is used for stopping services on platforms that do not
    support init scripts, and is also used for determining service
    status on those service whose init scripts do not include a status
    command.
    
    If this is left unspecified and is needed to check the status
    of a service, then the service name will be used instead.
    
    The pattern can be a simple string or any legal Ruby pattern.
- **restart**
    Specify a *restart* command manually.  If left
    unspecified, the service will be stopped and then started.
- **running**
    A place-holder parameter that wraps ``ensure``, because
    ``running`` is deprecated.  You should use ``ensure`` instead
    of this, but using this will still work, albeit with a
    warning.
- **start**
    Specify a *start* command manually.  Most service subsystems
    support a ``start`` command, so this will not need to be
    specified.
- **status**
    Specify a *status* command manually.  If left
    unspecified, the status method will be determined
    automatically, usually by looking for the service in the
    process table.
- **stop**
    Specify a *stop* command manually.
- **type**
    The service type.  For most platforms, it does not make
    sense to set this parameter, as the default is based on
    the builtin service facilities.  The service types available are:
    
    * ``base``: You must specify everything.
    * ``init``: Assumes ``start`` and ``stop`` commands exist, but you
      must specify everything else.
    * ``debian``: Debian's own specific version of ``init``.
    * ``smf``: Solaris 10's new Service Management Facility.
      Valid values are ``base``, ``init``, ``debian``, ``redhat``, ``smf``.



----------------


sshkey
==========
Installs and manages host entries.  For most systems, these
entries will just be in /etc/hosts, but some systems (notably OS X)
will have different solutions.


Sshkey Parameters
''''''''''''''''''''''''''''''
- **alias**
    Any alias the host might have.  Multiple values must be
    specified as an array.  Note that this state has the same name
    as one of the metaparams; using this state to set aliases will
    make those aliases available in your Puppet scripts and also on
    disk.
- **ensure**
    The basic state that the object should be in.  Valid values are ``absent``, ``present``.
- **key**
    The key itself; generally a long string of hex digits.
- **name**
    The host name.
- **type**
    The encryption type used.  Probably ssh-dss or ssh-rsa.



----------------


symlink
===========
Create symbolic links to existing files.  **This type is deprecated;
use file_ instead.**


Symlink Parameters
''''''''''''''''''''''''''''''
- **ensure**
    Create a link to another file.  Currently only symlinks
    are supported, and attempts to replace normal files with
    links will currently fail, while existing but incorrect symlinks
    will be removed.
- **path** (*namevar*)
    The path to the file to manage.  Must be fully qualified.
- **recurse**
    If target is a directory, recursively create
    directories (using `file`'s `source` parameter) and link all
    contained files.  For instance::
    
        # The Solaris Blastwave repository installs everything
        # in /opt/csw; link it into /usr/local
        symlink { "/usr/local":
            ensure => "/opt/csw",
            recurse => true
        }
    
    
    Note that this does not link directories -- any directories
    are created in the destination, and any files are linked over.



----------------


tidy
========
Remove unwanted files based on specific criteria.


Tidy Parameters
''''''''''''''''''''''''''''''
- **age**
    Tidy files whose age is equal to or greater than
    the specified number of days.
- **backup**
    Whether files should be backed up before
    being replaced.  If a filebucket_ is specified, files will be
    backed up there; else, they will be backed up in the same directory
    with a ``.puppet-bak`` extension.
    
    To use filebuckets, you must first create a filebucket in your
    configuration::
        
        filebucket { main:
            server => puppet
        }
    
    ``puppetmasterd`` creates a filebucket by default, so you can
    usually back up to your main server with this configuration.  Once
    you've described the bucket in your configuration, you can use
    it in any file::
    
        file { "/my/file":
            source => "/path/in/nfs/or/something",
            backup => main
        }
    
    This will back the file up to the central server.
    
    At this point, the only benefits to doing so are that you do not
    have backup files lying around on each of your machines, a given
    version of a file is only backed up once, and you can restore
    any given file manually, no matter how old.  Eventually,
    transactional support will be able to automatically restore
    filebucketed files.
- **path** (*namevar*)
    The path to the file or directory to manage.  Must be fully
    qualified.
- **recurse**
    If target is a directory, recursively descend
    into the directory looking for files to tidy.
- **rmdirs**
    Tidy directories in addition to files; that is, remove
    directories whose age is older than the specified criteria.
- **size**
    Tidy files whose size is equal to or greater than
    the specified size.  Unqualified values are in kilobytes, but
    *b*, *k*, and *m* can be appended to specify *bytes*, *kilobytes*,
    and *megabytes*, respectively.  Only the first character is
    significant, so the full word can also be used.
- **type**
    Set the mechanism for determining age.
    **atime**/*mtime*/*ctime*.



----------------


user
========
Manage users.  Currently can create and modify users, but
cannot delete them.  Theoretically all of the parameters are
optional, but if no parameters are specified the comment will
be set to the user name in order to make the internals work out
correctly.

This element type uses the prescribed native tools for creating
groups and generally uses POSIX APIs for retrieving information
about them.  It does not directly modify /etc/passwd or anything.

For most platforms, the tools used are ``useradd`` and its ilk;
for Mac OS X, NetInfo is used.  This is currently unconfigurable,
but if you desperately need it to be so, please contact us.


User Parameters
''''''''''''''''''''''''''''''
- **comment**
    A description of the user.  Generally is a user's full name.
- **ensure**
    The basic state that the object should be in.  Valid values are ``absent``, ``present``.
- **gid**
    The user's primary group.  Can be specified numerically or
    by name.
- **groups**
    The groups of which the user is a member.  The primary
    group should not be listed.  Multiple groups should be
    specified as an array.
- **home**
    The home directory of the user.  The directory must be created
    separately and is not currently checked for existence.
- **membership**
    Whether specified groups should be treated as the only groups
    of which the user is a member or whether they should merely
    be treated as the minimum membership list.  Valid values are ``inclusive``, ``minimum``.
- **name**
    User name.  While limitations are determined for
    each operating system, it is generally a good idea to keep to
    the degenerate 8 characters, beginning with a letter.
- **shell**
    The user's login shell.  The shell must exist and be
    executable.
- **uid**
    The user ID.  Must be specified numerically.  For new users
    being created, if no user ID is specified then one will be
    chosen automatically, which will likely result in the same user
    having different IDs on different systems, which is not
    recommended.



----------------


*This page autogenerated on Wed May 10 11:09:04 CDT 2006*
