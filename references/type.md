---
layout: default
built_from_commit: 6893bdd69ab1291e6e6fcd6b152dda2b48e3cdb2
title: Resource Type Reference (Single-Page)
canonical: "/puppet/latest/type.html"
toc_levels: 2
toc: columns
---

# Resource Type Reference (Single-Page)

> **NOTE:** This page was generated from the Puppet source code on 2024-10-17 02:37:51 +0000



## About resource types

### Built-in types and custom types

This is the documentation for Puppet's built-in resource types and providers. Additional resource types are distributed in Puppet modules.

You can find and install modules by browsing the
[Puppet Forge](http://forge.puppet.com). See each module's documentation for
information on how to use its custom resource types. For more information about creating custom types, see [Custom resources](/docs/puppet/latest/custom_resources.html).

> As of Puppet 6.0, some resource types were removed from Puppet and repackaged as individual modules. These supported type modules are still included in the `puppet-agent` package, so you don't have to download them from the Forge. See the complete list of affected types in the [supported type modules](#supported-type-modules-in-puppet-agent) section.

### Declaring resources

To manage resources on a target system, declare them in Puppet
manifests. For more details, see
[the resources page of the Puppet language reference.](/docs/puppet/latest/lang_resources.html)

You can also browse and manage resources interactively using the
`puppet resource` subcommand; run `puppet resource --help` for more information.

### Namevars and titles

All types have a special attribute called the _namevar_. This is the attribute
used to uniquely identify a resource on the target system.

Each resource has a specific namevar attribute, which is listed on this page in
each resource's reference. If you don't specify a value for the namevar, its
value defaults to the resource's _title_.

**Example of a title as a default namevar:**

```puppet
file { '/etc/passwd':
  owner => 'root',
  group => 'root',
  mode  => '0644',
}
```

In this code, `/etc/passwd` is the _title_ of the file resource.

The file type's namevar is `path`. Because we didn't provide a `path` value in
this example, the value defaults to the title, `/etc/passwd`.

**Example of a namevar:**

```puppet
file { 'passwords':
  path  => '/etc/passwd',
  owner => 'root',
  group => 'root',
  mode  => '0644',
}
```

This example is functionally similar to the previous example. Its `path`
namevar attribute has an explicitly set value separate from the title, so
its name is still `/etc/passwd`.

Other Puppet code can refer to this resource as `File['/etc/passwd']` to
declare relationships.

### Attributes, parameters, properties

The _attributes_ (sometimes called _parameters_) of a resource determine its
desired state. They either directly modify the system (internally, these are
called "properties") or they affect how the resource behaves (for instance,
adding a search path for `exec` resources or controlling directory recursion
on `file` resources).

### Providers

_Providers_ implement the same resource type on different kinds of systems.
They usually do this by calling out to external commands.

Although Puppet automatically selects an appropriate default provider, you
can override the default with the `provider` attribute. (For example, `package`
resources on Red Hat systems default to the `yum` provider, but you can specify
`provider => gem` to install Ruby libraries with the `gem` command.)

Providers often specify binaries that they require. Fully qualified binary
paths indicate that the binary must exist at that specific path, and
unqualified paths indicate that Puppet searches for the binary using the
shell path.

### Features

_Features_ are abilities that some providers might not support. Generally, a
feature corresponds to some allowed values for a resource attribute.

This is often the case with the `ensure` attribute. In most types, Puppet
doesn't create new resources when omitting `ensure` but still modifies existing
resources to match specifications in the manifest. However, in some types this
isn't always the case, or additional values provide more granular control. For
example, if a `package` provider supports the `purgeable` feature, you can
specify `ensure => purged` to delete configuration files installed by the
package.

Resource types define the set of features they can use, and providers can
declare which features they provide.

## Puppet 6.0 type changes

In Puppet 6.0, we removed some of Puppet's built-in types and moved them into individual modules.

### Supported type modules in `puppet-agent`

The following types are included in supported modules on the Forge. However, they are also included in the `puppet-agent` package, so you do not have to install them separately. See each module's README for detailed information about that type.

- [`augeas`](https://forge.puppet.com/puppetlabs/augeas_core)
- [`cron`](https://forge.puppet.com/puppetlabs/cron_core)
- [`host`](https://forge.puppet.com/puppetlabs/host_core)
- [`mount`](https://forge.puppet.com/puppetlabs/mount_core)
- [`scheduled_task`](https://forge.puppet.com/puppetlabs/scheduled_task)
- [`selboolean`](https://forge.puppet.com/puppetlabs/selinux_core)
- [`selmodule`](https://forge.puppet.com/puppetlabs/selinux_core)
- [`ssh_authorized_key`](https://forge.puppet.com/puppetlabs/sshkeys_core)
- [`sshkey`](https://forge.puppet.com/puppetlabs/sshkeys_core)
- [`yumrepo`](https://forge.puppet.com/puppetlabs/yumrepo_core)
- [`zfs`](https://forge.puppet.com/puppetlabs/zfs_core)
- [`zone`](https://forge.puppet.com/puppetlabs/zone_core)
- [`zpool`](https://forge.puppet.com/puppetlabs/zfs_core)

### Type modules available on the Forge

The following types are contained in modules that are maintained, but are not repackaged into Puppet agent. If you need to use them, you must install the modules separately. 

- [`k5login`](https://forge.puppet.com/puppetlabs/k5login_core)
- [`mailalias`](https://forge.puppet.com/puppetlabs/mailalias_core)
- [`maillist`](https://forge.puppet.com/puppetlabs/maillist_core)

### Deprecated types

The following types were deprecated with Puppet 6.0.0. They are available in modules, but are not updated. If you need to use them, you must install the modules separately.

- [`computer`](https://forge.puppet.com/puppetlabs/macdslocal_core)
- [`interface`](https://github.com/puppetlabs/puppetlabs-network_device_core) (Use the updated [`cisco_ios module`](https://forge.puppet.com/puppetlabs/cisco_ios/readme) instead.
- [`macauthorization`](https://forge.puppet.com/puppetlabs/macdslocal_core)
- [`mcx`](https://forge.puppet.com/puppetlabs/macdslocal_core)
- [The Nagios types](https://forge.puppet.com/puppetlabs/nagios_core)
- [`router`](https://github.com/puppetlabs/puppetlabs-network_device_core) (Use the updated [`cisco_ios module`](https://forge.puppet.com/puppetlabs/cisco_ios/readme) instead.
- [`vlan`](https://github.com/puppetlabs/puppetlabs-network_device_core) (Use the updated [`cisco_ios module`](https://forge.puppet.com/puppetlabs/cisco_ios/readme) instead.

## Puppet core types

For a list of core Puppet types, see the [core types cheat sheet][core-types-cheatsheet].

## exec

* [Attributes](#exec-attributes)
* [Providers](#exec-providers)

### Description {#exec-description}

Executes external commands.

Any command in an `exec` resource **must** be able to run multiple times
without causing harm --- that is, it must be *idempotent*. There are three
main ways for an exec to be idempotent:

* The command itself is already idempotent. (For example, `apt-get update`.)
* The exec has an `onlyif`, `unless`, or `creates` attribute, which prevents
  Puppet from running the command unless some condition is met. The
  `onlyif` and `unless` commands of an `exec` are used in the process of
  determining whether the `exec` is already in sync, therefore they must be run
  during a noop Puppet run.
* The exec has `refreshonly => true`, which allows Puppet to run the
  command only when some other resource is changed. (See the notes on refreshing
  below.)

The state managed by an `exec` resource represents whether the specified command
_needs to be_ executed during the catalog run. The target state is always that
the command does not need to be executed. If the initial state is that the
command _does_ need to be executed, then successfully executing the command
transitions it to the target state.

The `unless`, `onlyif`, and `creates` properties check the initial state of the
resource. If one or more of these properties is specified, the exec might not
need to run. If the exec does not need to run, then the system is already in
the target state. In such cases, the exec is considered successful without
actually executing its command.

A caution: There's a widespread tendency to use collections of execs to
manage resources that aren't covered by an existing resource type. This
works fine for simple tasks, but once your exec pile gets complex enough
that you really have to think to understand what's happening, you should
consider developing a custom resource type instead, as it is much
more predictable and maintainable.

**Duplication:** Even though `command` is the namevar, Puppet allows
multiple `exec` resources with the same `command` value.

**Refresh:** `exec` resources can respond to refresh events (via
`notify`, `subscribe`, or the `~>` arrow). The refresh behavior of execs
is non-standard, and can be affected by the `refresh` and
`refreshonly` attributes:

* If `refreshonly` is set to true, the exec runs _only_ when it receives an
  event. This is the most reliable way to use refresh with execs.
* If the exec has already run and then receives an event, it runs its
  command **up to two times.** If an `onlyif`, `unless`, or `creates` condition
  is no longer met after the first run, the second run does not occur.
* If the exec has already run, has a `refresh` command, and receives an
  event, it runs its normal command. Then, if any `onlyif`, `unless`, or `creates`
  conditions are still met, the exec runs its `refresh` command.
* If the exec has an `onlyif`, `unless`, or `creates` attribute that prevents it
  from running, and it then receives an event, it still will not run.
* If the exec has `noop => true`, would otherwise have run, and receives
  an event from a non-noop resource, it runs once. However, if it has a `refresh`
  command, it runs that instead of its normal command.

In short: If there's a possibility of your exec receiving refresh events,
it is extremely important to make sure the run conditions are restricted.

**Autorequires:** If Puppet is managing an exec's cwd or the executable
file used in an exec's command, the exec resource autorequires those
files. If Puppet is managing the user that an exec should run as, the
exec resource autorequires that user.

### Attributes {#exec-attributes}

<pre><code>exec { 'resource title':
  <a href="#exec-attribute-command">command</a>     =&gt; <em># <strong>(namevar)</strong> The actual command to execute.  Must either be...</em>
  <a href="#exec-attribute-creates">creates</a>     =&gt; <em># A file to look for before running the command...</em>
  <a href="#exec-attribute-cwd">cwd</a>         =&gt; <em># The directory from which to run the command.  If </em>
  <a href="#exec-attribute-environment">environment</a> =&gt; <em># An array of any additional environment variables </em>
  <a href="#exec-attribute-group">group</a>       =&gt; <em># The group to run the command as.  This seems to...</em>
  <a href="#exec-attribute-logoutput">logoutput</a>   =&gt; <em># Whether to log command output in addition to...</em>
  <a href="#exec-attribute-onlyif">onlyif</a>      =&gt; <em># A test command that checks the state of the...</em>
  <a href="#exec-attribute-path">path</a>        =&gt; <em># The search path used for command execution...</em>
  <a href="#exec-attribute-provider">provider</a>    =&gt; <em># The specific backend to use for this `exec...</em>
  <a href="#exec-attribute-refresh">refresh</a>     =&gt; <em># An alternate command to run when the `exec...</em>
  <a href="#exec-attribute-refreshonly">refreshonly</a> =&gt; <em># The command should only be run as a refresh...</em>
  <a href="#exec-attribute-returns">returns</a>     =&gt; <em># The expected exit code(s).  An error will be...</em>
  <a href="#exec-attribute-timeout">timeout</a>     =&gt; <em># The maximum time the command should take.  If...</em>
  <a href="#exec-attribute-tries">tries</a>       =&gt; <em># The number of times execution of the command...</em>
  <a href="#exec-attribute-try_sleep">try_sleep</a>   =&gt; <em># The time to sleep in seconds between...</em>
  <a href="#exec-attribute-umask">umask</a>       =&gt; <em># Sets the umask to be used while executing this...</em>
  <a href="#exec-attribute-unless">unless</a>      =&gt; <em># A test command that checks the state of the...</em>
  <a href="#exec-attribute-user">user</a>        =&gt; <em># The user to run the command as.  > **Note:*...</em>
  # ...plus any applicable <a href="https://puppet.com/docs/puppet/latest/metaparameter.html">metaparameters</a>.
}</code></pre>


#### command {#exec-attribute-command}

_(**Namevar:** If omitted, this attribute's value defaults to the resource's title.)_

The actual command to execute.  Must either be fully qualified
or a search path for the command must be provided.  If the command
succeeds, any output produced will be logged at the instance's
normal log level (usually `notice`), but if the command fails
(meaning its return code does not match the specified code) then
any output is logged at the `err` log level.

Multiple `exec` resources can use the same `command` value; Puppet
only uses the resource title to ensure `exec`s are unique.

On *nix platforms, the command can be specified as an array of
strings and Puppet will invoke it using the more secure method of
parameterized system calls. For example, rather than executing the
malicious injected code, this command will echo it out:

    command => ['/bin/echo', 'hello world; rm -rf /']

([↑ Back to exec attributes](#exec-attributes))


#### creates {#exec-attribute-creates}

A file to look for before running the command. The command will
only run if the file **doesn't exist.**

This parameter doesn't cause Puppet to create a file; it is only
useful if **the command itself** creates a file.

    exec { 'tar -xf /Volumes/nfs02/important.tar':
      cwd     => '/var/tmp',
      creates => '/var/tmp/myfile',
      path    => ['/usr/bin', '/usr/sbin',],
    }

In this example, `myfile` is assumed to be a file inside
`important.tar`. If it is ever deleted, the exec will bring it
back by re-extracting the tarball. If `important.tar` does **not**
actually contain `myfile`, the exec will keep running every time
Puppet runs.

This parameter can also take an array of files, and the command will
not run if **any** of these files exist. Consider this example:

    creates => ['/tmp/file1', '/tmp/file2'],

The command is only run if both files don't exist.

([↑ Back to exec attributes](#exec-attributes))


#### cwd {#exec-attribute-cwd}

The directory from which to run the command.  If
this directory does not exist, the command will fail.

([↑ Back to exec attributes](#exec-attributes))


#### environment {#exec-attribute-environment}

An array of any additional environment variables you want to set for a
command, such as `[ 'HOME=/root', 'MAIL=root@example.com']`.
Note that if you use this to set PATH, it will override the `path`
attribute. Multiple environment variables should be specified as an
array.

([↑ Back to exec attributes](#exec-attributes))


#### group {#exec-attribute-group}

The group to run the command as.  This seems to work quite
haphazardly on different platforms -- it is a platform issue
not a Ruby or Puppet one, since the same variety exists when
running commands as different users in the shell.

([↑ Back to exec attributes](#exec-attributes))


#### logoutput {#exec-attribute-logoutput}

Whether to log command output in addition to logging the
exit code. Defaults to `on_failure`, which only logs the output
when the command has an exit code that does not match any value
specified by the `returns` attribute. As with any resource type,
the log level can be controlled with the `loglevel` metaparameter.

Valid values are `true`, `false`, `on_failure`.

([↑ Back to exec attributes](#exec-attributes))


#### onlyif {#exec-attribute-onlyif}

A test command that checks the state of the target system and restricts
when the `exec` can run. If present, Puppet runs this test command
first, and only runs the main command if the test has an exit code of 0
(success). For example:

    exec { 'logrotate':
      path     => '/usr/bin:/usr/sbin:/bin',
      provider => shell,
      onlyif   => 'test `du /var/log/messages | cut -f1` -gt 100000',
    }

This would run `logrotate` only if that test returns true.

Note that this test command runs with the same `provider`, `path`,
`user`, `cwd`, and `group` as the main command. If the `path` isn't set, you
must fully qualify the command's name.

Since this command is used in the process of determining whether the
`exec` is already in sync, it must be run during a noop Puppet run.

This parameter can also take an array of commands. For example:

    onlyif => ['test -f /tmp/file1', 'test -f /tmp/file2'],

or an array of arrays. For example:

    onlyif => [['test', '-f', '/tmp/file1'], 'test -f /tmp/file2']

This `exec` would only run if every command in the array has an
exit code of 0 (success).

([↑ Back to exec attributes](#exec-attributes))


#### path {#exec-attribute-path}

The search path used for command execution.
Commands must be fully qualified if no path is specified.  Paths
can be specified as an array or as a ':' separated list.

([↑ Back to exec attributes](#exec-attributes))


#### provider {#exec-attribute-provider}

The specific backend to use for this `exec`
resource. You will seldom need to specify this --- Puppet will usually
discover the appropriate provider for your platform.

Available providers are:

* [`posix`](#exec-provider-posix)
* [`shell`](#exec-provider-shell)
* [`windows`](#exec-provider-windows)

([↑ Back to exec attributes](#exec-attributes))


#### refresh {#exec-attribute-refresh}

An alternate command to run when the `exec` receives a refresh event
from another resource. By default, Puppet runs the main command again.
For more details, see the notes about refresh behavior above, in the
description for this resource type.

Note that this alternate command runs with the same `provider`, `path`,
`user`, and `group` as the main command. If the `path` isn't set, you
must fully qualify the command's name.

([↑ Back to exec attributes](#exec-attributes))


#### refreshonly {#exec-attribute-refreshonly}

The command should only be run as a
refresh mechanism for when a dependent object is changed.  It only
makes sense to use this option when this command depends on some
other object; it is useful for triggering an action:

    # Pull down the main aliases file
    file { '/etc/aliases':
      source => 'puppet://server/module/aliases',
    }

    # Rebuild the database, but only when the file changes
    exec { newaliases:
      path        => ['/usr/bin', '/usr/sbin'],
      subscribe   => File['/etc/aliases'],
      refreshonly => true,
    }

Note that only `subscribe` and `notify` can trigger actions, not `require`,
so it only makes sense to use `refreshonly` with `subscribe` or `notify`.

Valid values are `true`, `false`.

([↑ Back to exec attributes](#exec-attributes))


#### returns {#exec-attribute-returns}

_(**Property:** This attribute represents concrete state on the target system.)_

The expected exit code(s).  An error will be returned if the
executed command has some other exit code. Can be specified as an array
of acceptable exit codes or a single value.

On POSIX systems, exit codes are always integers between 0 and 255.

On Windows, **most** exit codes should be integers between 0
and 2147483647.

Larger exit codes on Windows can behave inconsistently across different
tools. The Win32 APIs define exit codes as 32-bit unsigned integers, but
both the cmd.exe shell and the .NET runtime cast them to signed
integers. This means some tools will report negative numbers for exit
codes above 2147483647. (For example, cmd.exe reports 4294967295 as -1.)
Since Puppet uses the plain Win32 APIs, it will report the very large
number instead of the negative number, which might not be what you
expect if you got the exit code from a cmd.exe session.

Microsoft recommends against using negative/very large exit codes, and
you should avoid them when possible. To convert a negative exit code to
the positive one Puppet will use, add it to 4294967296.

([↑ Back to exec attributes](#exec-attributes))


#### timeout {#exec-attribute-timeout}

The maximum time the command should take.  If the command takes
longer than the timeout, the command is considered to have failed
and will be stopped. The timeout is specified in seconds. The default
timeout is 300 seconds and you can set it to 0 to disable the timeout.

([↑ Back to exec attributes](#exec-attributes))


#### tries {#exec-attribute-tries}

The number of times execution of the command should be tried.
This many attempts will be made to execute the command until an
acceptable return code is returned. Note that the timeout parameter
applies to each try rather than to the complete set of tries.

([↑ Back to exec attributes](#exec-attributes))


#### try_sleep {#exec-attribute-try_sleep}

The time to sleep in seconds between 'tries'.

([↑ Back to exec attributes](#exec-attributes))


#### umask {#exec-attribute-umask}

Sets the umask to be used while executing this command

([↑ Back to exec attributes](#exec-attributes))


#### unless {#exec-attribute-unless}

A test command that checks the state of the target system and restricts
when the `exec` can run. If present, Puppet runs this test command
first, then runs the main command unless the test has an exit code of 0
(success). For example:

    exec { '/bin/echo root >> /usr/lib/cron/cron.allow':
      path   => '/usr/bin:/usr/sbin:/bin',
      unless => 'grep ^root$ /usr/lib/cron/cron.allow 2>/dev/null',
    }

This would add `root` to the cron.allow file (on Solaris) unless
`grep` determines it's already there.

Note that this test command runs with the same `provider`, `path`,
`user`, `cwd`, and `group` as the main command. If the `path` isn't set, you
must fully qualify the command's name.

Since this command is used in the process of determining whether the
`exec` is already in sync, it must be run during a noop Puppet run.

This parameter can also take an array of commands. For example:

    unless => ['test -f /tmp/file1', 'test -f /tmp/file2'],

or an array of arrays. For example:

    unless => [['test', '-f', '/tmp/file1'], 'test -f /tmp/file2']

This `exec` would only run if every command in the array has a
non-zero exit code.

([↑ Back to exec attributes](#exec-attributes))


#### user {#exec-attribute-user}

The user to run the command as.

> **Note:** Puppet cannot execute commands as other users on Windows.

Note that if you use this attribute, any error output is not captured
due to a bug within Ruby. If you use Puppet to create this user, the
exec automatically requires the user, as long as it is specified by
name.

The $HOME environment variable is not automatically set when using
this attribute.

([↑ Back to exec attributes](#exec-attributes))


### Providers {#exec-providers}

#### posix {#exec-provider-posix}

Executes external binaries by invoking Ruby's `Kernel.exec`.
When the command is a string, it will be executed directly,
without a shell, if it follows these rules:
 - no meta characters
 - no shell reserved word and no special built-in

When the command is an Array of Strings, passed as `[cmdname, arg1, ...]`
it will be executed directly(the first element is taken as a command name
and the rest are passed as parameters to command with no shell expansion)
This is a safer and more predictable way to execute most commands,
but prevents the use of globbing and shell built-ins (including control
logic like "for" and "if" statements).

If the use of globbing and shell built-ins is desired, please check
the `shell` provider

* Default for `feature` == `posix`.

#### shell {#exec-provider-shell}

Passes the provided command through `/bin/sh`; only available on
POSIX systems. This allows the use of shell globbing and built-ins, and
does not require that the path to a command be fully-qualified. Although
this can be more convenient than the `posix` provider, it also means that
you need to be more careful with escaping; as ever, with great power comes
etc. etc.

This provider closely resembles the behavior of the `exec` type
in Puppet 0.25.x.

#### windows {#exec-provider-windows}

Execute external binaries on Windows systems. As with the `posix`
provider, this provider directly calls the command with the arguments
given, without passing it through a shell or performing any interpolation.
To use shell built-ins --- that is, to emulate the `shell` provider on
Windows --- a command must explicitly invoke the shell:

    exec {'echo foo':
      command => 'cmd.exe /c echo "foo"',
    }

If no extension is specified for a command, Windows will use the `PATHEXT`
environment variable to locate the executable.

**Note on PowerShell scripts:** PowerShell's default `restricted`
execution policy doesn't allow it to run saved scripts. To run PowerShell
scripts, specify the `remotesigned` execution policy as part of the
command:

    exec { 'test':
      path    => 'C:/Windows/System32/WindowsPowerShell/v1.0',
      command => 'powershell -executionpolicy remotesigned -file C:/test.ps1',
    }

* Default for `os.name` == `windows`.




---------

## file

* [Attributes](#file-attributes)
* [Providers](#file-providers)
* [Provider Features](#file-provider-features)

### Description {#file-description}

Manages files, including their content, ownership, and permissions.

The `file` type can manage normal files, directories, and symlinks; the
type should be specified in the `ensure` attribute.

File contents can be managed directly with the `content` attribute, or
downloaded from a remote source using the `source` attribute; the latter
can also be used to recursively serve directories (when the `recurse`
attribute is set to `true` or `local`). On Windows, note that file
contents are managed in binary mode; Puppet never automatically translates
line endings.

**Autorequires:** If Puppet is managing the user or group that owns a
file, the file resource will autorequire them. If Puppet is managing any
parent directories of a file, the file resource autorequires them.

Warning: Enabling `recurse` on directories containing large numbers of
files slows agent runs. To manage file attributes for many files,
consider using alternative methods such as the `chmod_r`, `chown_r`,
 or `recursive_file_permissions` modules from the Forge.

### Attributes {#file-attributes}

<pre><code>file { 'resource title':
  <a href="#file-attribute-path">path</a>                    =&gt; <em># <strong>(namevar)</strong> The path to the file to manage.  Must be fully...</em>
  <a href="#file-attribute-ensure">ensure</a>                  =&gt; <em># Whether the file should exist, and if so what...</em>
  <a href="#file-attribute-backup">backup</a>                  =&gt; <em># Whether (and how) file content should be backed...</em>
  <a href="#file-attribute-checksum">checksum</a>                =&gt; <em># The checksum type to use when determining...</em>
  <a href="#file-attribute-checksum_value">checksum_value</a>          =&gt; <em># The checksum of the source contents. Only md5...</em>
  <a href="#file-attribute-content">content</a>                 =&gt; <em># The desired contents of a file, as a string...</em>
  <a href="#file-attribute-ctime">ctime</a>                   =&gt; <em># A read-only state to check the file ctime. On...</em>
  <a href="#file-attribute-force">force</a>                   =&gt; <em># Perform the file operation even if it will...</em>
  <a href="#file-attribute-group">group</a>                   =&gt; <em># Which group should own the file.  Argument can...</em>
  <a href="#file-attribute-ignore">ignore</a>                  =&gt; <em># A parameter which omits action on files matching </em>
  <a href="#file-attribute-links">links</a>                   =&gt; <em># How to handle links during file actions.  During </em>
  <a href="#file-attribute-max_files">max_files</a>               =&gt; <em># In case the resource is a directory and the...</em>
  <a href="#file-attribute-mode">mode</a>                    =&gt; <em># The desired permissions mode for the file, in...</em>
  <a href="#file-attribute-mtime">mtime</a>                   =&gt; <em># A read-only state to check the file mtime. On...</em>
  <a href="#file-attribute-owner">owner</a>                   =&gt; <em># The user to whom the file should belong....</em>
  <a href="#file-attribute-provider">provider</a>                =&gt; <em># The specific backend to use for this `file...</em>
  <a href="#file-attribute-purge">purge</a>                   =&gt; <em># Whether unmanaged files should be purged. This...</em>
  <a href="#file-attribute-recurse">recurse</a>                 =&gt; <em># Whether to recursively manage the _contents_ of...</em>
  <a href="#file-attribute-recurselimit">recurselimit</a>            =&gt; <em># How far Puppet should descend into...</em>
  <a href="#file-attribute-replace">replace</a>                 =&gt; <em># Whether to replace a file or symlink that...</em>
  <a href="#file-attribute-selinux_ignore_defaults">selinux_ignore_defaults</a> =&gt; <em># If this is set, Puppet will not call the SELinux </em>
  <a href="#file-attribute-selrange">selrange</a>                =&gt; <em># What the SELinux range component of the context...</em>
  <a href="#file-attribute-selrole">selrole</a>                 =&gt; <em># What the SELinux role component of the context...</em>
  <a href="#file-attribute-seltype">seltype</a>                 =&gt; <em># What the SELinux type component of the context...</em>
  <a href="#file-attribute-seluser">seluser</a>                 =&gt; <em># What the SELinux user component of the context...</em>
  <a href="#file-attribute-show_diff">show_diff</a>               =&gt; <em># Whether to display differences when the file...</em>
  <a href="#file-attribute-source">source</a>                  =&gt; <em># A source file, which will be copied into place...</em>
  <a href="#file-attribute-source_permissions">source_permissions</a>      =&gt; <em># Whether (and how) Puppet should copy owner...</em>
  <a href="#file-attribute-sourceselect">sourceselect</a>            =&gt; <em># Whether to copy all valid sources, or just the...</em>
  <a href="#file-attribute-staging_location">staging_location</a>        =&gt; <em># When rendering a file first render it to this...</em>
  <a href="#file-attribute-target">target</a>                  =&gt; <em># The target for creating a link.  Currently...</em>
  <a href="#file-attribute-type">type</a>                    =&gt; <em># A read-only state to check the file...</em>
  <a href="#file-attribute-validate_cmd">validate_cmd</a>            =&gt; <em># A command for validating the file's syntax...</em>
  <a href="#file-attribute-validate_replacement">validate_replacement</a>    =&gt; <em># The replacement string in a `validate_cmd` that...</em>
  # ...plus any applicable <a href="https://puppet.com/docs/puppet/latest/metaparameter.html">metaparameters</a>.
}</code></pre>


#### path {#file-attribute-path}

_(**Namevar:** If omitted, this attribute's value defaults to the resource's title.)_

The path to the file to manage.  Must be fully qualified.

On Windows, the path should include the drive letter and should use `/` as
the separator character (rather than `\\`).

([↑ Back to file attributes](#file-attributes))


#### ensure {#file-attribute-ensure}

_(**Property:** This attribute represents concrete state on the target system.)_

Whether the file should exist, and if so what kind of file it should be.
Possible values are `present`, `absent`, `file`, `directory`, and `link`.

* `present` accepts any form of file existence, and creates a
  normal file if the file is missing. (The file will have no content
  unless the `content` or `source` attribute is used.)
* `absent` ensures the file doesn't exist, and deletes it if necessary.
* `file` ensures it's a normal file, and enables use of the `content` or
  `source` attribute.
* `directory` ensures it's a directory, and enables use of the `source`,
  `recurse`, `recurselimit`, `ignore`, and `purge` attributes.
* `link` ensures the file is a symlink, and **requires** that you also
  set the `target` attribute. Symlinks are supported on all Posix
  systems and on Windows Vista / 2008 and higher. On Windows, managing
  symlinks requires Puppet agent's user account to have the "Create
  Symbolic Links" privilege; this can be configured in the "User Rights
  Assignment" section in the Windows policy editor. By default, Puppet
  agent runs as the Administrator account, which has this privilege.

Puppet avoids destroying directories unless the `force` attribute is set
to `true`. This means that if a file is currently a directory, setting
`ensure` to anything but `directory` or `present` will cause Puppet to
skip managing the resource and log either a notice or an error.

There is one other non-standard value for `ensure`. If you specify the
path to another file as the ensure value, it is equivalent to specifying
`link` and using that path as the `target`:

    # Equivalent resources:

    file { '/etc/inetd.conf':
      ensure => '/etc/inet/inetd.conf',
    }

    file { '/etc/inetd.conf':
      ensure => link,
      target => '/etc/inet/inetd.conf',
    }

However, we recommend using `link` and `target` explicitly, since this
behavior can be harder to read and is
[deprecated](https://docs.puppet.com/puppet/4.3/deprecated_language.html)
as of Puppet 4.3.0.

Valid values are `absent` (also called `false`), `file`, `present`, `directory`, `link`. Values can match `/./`.

([↑ Back to file attributes](#file-attributes))


#### backup {#file-attribute-backup}

Whether (and how) file content should be backed up before being replaced.
This attribute works best as a resource default in the site manifest
(`File { backup => main }`), so it can affect all file resources.

* If set to `false`, file content won't be backed up.
* If set to a string beginning with `.`, such as `.puppet-bak`, Puppet will
  use copy the file in the same directory with that value as the extension
  of the backup. (A value of `true` is a synonym for `.puppet-bak`.)
* If set to any other string, Puppet will try to back up to a filebucket
  with that title. Puppet automatically creates a **local** filebucket
  named `puppet` if one doesn't already exist. See the `filebucket` resource
  type for more details.

Default value: `false`

Backing up to a local filebucket isn't particularly useful. If you want
to make organized use of backups, you will generally want to use the
primary Puppet server's filebucket service. This requires declaring a
filebucket resource and a resource default for the `backup` attribute
in site.pp:

    # /etc/puppetlabs/puppet/manifests/site.pp
    filebucket { 'main':
      path   => false,                # This is required for remote filebuckets.
      server => 'puppet.example.com', # Optional; defaults to the configured primary Puppet server.
    }

    File { backup => main, }

If you are using multiple primary servers, you will want to
centralize the contents of the filebucket. Either configure your load
balancer to direct all filebucket traffic to a single primary server, or use
something like an out-of-band rsync task to synchronize the content on all
primary servers.

> **Note**: Enabling and using the backup option, and by extension the
  filebucket resource, requires appropriate planning and management to ensure
  that sufficient disk space is available for the file backups. Generally, you
  can implement this using one of the following two options:
  - Use a `find` command and `crontab` entry to retain only the last X days
  of file backups. For example:

  ```
  find /opt/puppetlabs/server/data/puppetserver/bucket -type f -mtime +45 -atime +45 -print0 | xargs -0 rm
  ```

  - Restrict the directory to a maximum size after which the oldest items are removed.

([↑ Back to file attributes](#file-attributes))


#### checksum {#file-attribute-checksum}

The checksum type to use when determining whether to replace a file's contents.

The default checksum type is sha256.

Valid values are `sha256`, `sha256lite`, `md5`, `md5lite`, `sha1`, `sha1lite`, `sha512`, `sha384`, `sha224`, `mtime`, `ctime`, `none`.

([↑ Back to file attributes](#file-attributes))


#### checksum_value {#file-attribute-checksum_value}

_(**Property:** This attribute represents concrete state on the target system.)_

The checksum of the source contents. Only md5, sha256, sha224, sha384 and sha512
are supported when specifying this parameter. If this parameter is set,
source_permissions will be assumed to be false, and ownership and permissions
will not be read from source.

([↑ Back to file attributes](#file-attributes))


#### content {#file-attribute-content}

_(**Property:** This attribute represents concrete state on the target system.)_

The desired contents of a file, as a string. This attribute is mutually
exclusive with `source` and `target`.

Newlines and tabs can be specified in double-quoted strings using
standard escaped syntax --- \n for a newline, and \t for a tab.

With very small files, you can construct content strings directly in
the manifest...

    define resolve($nameserver1, $nameserver2, $domain, $search) {
        $str = "search ${search}
            domain ${domain}
            nameserver ${nameserver1}
            nameserver ${nameserver2}
            "

        file { '/etc/resolv.conf':
          content => $str,
        }
    }

...but for larger files, this attribute is more useful when combined with the
[template](https://puppet.com/docs/puppet/latest/function.html#template)
or [file](https://puppet.com/docs/puppet/latest/function.html#file)
function.

([↑ Back to file attributes](#file-attributes))


#### ctime {#file-attribute-ctime}

_(**Property:** This attribute represents concrete state on the target system.)_

A read-only state to check the file ctime. On most modern *nix-like
systems, this is the time of the most recent change to the owner, group,
permissions, or content of the file.

([↑ Back to file attributes](#file-attributes))


#### force {#file-attribute-force}

Perform the file operation even if it will destroy one or more directories.
You must use `force` in order to:

* `purge` subdirectories
* Replace directories with files or links
* Remove a directory when `ensure => absent`

Valid values are `true`, `false`, `yes`, `no`.

([↑ Back to file attributes](#file-attributes))


#### group {#file-attribute-group}

_(**Property:** This attribute represents concrete state on the target system.)_

Which group should own the file.  Argument can be either a group
name or a group ID.

On Windows, a user (such as "Administrator") can be set as a file's group
and a group (such as "Administrators") can be set as a file's owner;
however, a file's owner and group shouldn't be the same. (If the owner
is also the group, files with modes like `"0640"` will cause log churn, as
they will always appear out of sync.)

([↑ Back to file attributes](#file-attributes))


#### ignore {#file-attribute-ignore}

A parameter which omits action on files matching
specified patterns during recursion.  Uses Ruby's builtin globbing
engine, so shell metacharacters such as `[a-z]*` are fully supported.
Matches that would descend into the directory structure are ignored,
such as `*/*`.

([↑ Back to file attributes](#file-attributes))


#### links {#file-attribute-links}

How to handle links during file actions.  During file copying,
`follow` will copy the target file instead of the link and `manage`
will copy the link itself. When not copying, `manage` will manage
the link, and `follow` will manage the file to which the link points.

Valid values are `follow`, `manage`.

([↑ Back to file attributes](#file-attributes))


#### max_files {#file-attribute-max_files}

In case the resource is a directory and the recursion is enabled, puppet will
generate a new resource for each file file found, possible leading to
an excessive number of resources generated without any control.

Setting `max_files` will check the number of file resources that
will eventually be created and will raise a resource argument error if the
limit will be exceeded.

Use value `0` to log a warning instead of raising an error.

Use value `-1` to disable errors and warnings due to max files.

Values can match `/^[0-9]+$/`, `/^-1$/`.

([↑ Back to file attributes](#file-attributes))


#### mode {#file-attribute-mode}

_(**Property:** This attribute represents concrete state on the target system.)_

The desired permissions mode for the file, in symbolic or numeric
notation. This value **must** be specified as a string; do not use
un-quoted numbers to represent file modes.

If the mode is omitted (or explicitly set to `undef`), Puppet does not
enforce permissions on existing files and creates new files with
permissions of `0644`.

The `file` type uses traditional Unix permission schemes and translates
them to equivalent permissions for systems which represent permissions
differently, including Windows. For detailed ACL controls on Windows,
you can leave `mode` unmanaged and use
[the puppetlabs/acl module.](https://forge.puppetlabs.com/puppetlabs/acl)

Numeric modes should use the standard octal notation of
`<SETUID/SETGID/STICKY><OWNER><GROUP><OTHER>` (for example, "0644").

* Each of the "owner," "group," and "other" digits should be a sum of the
  permissions for that class of users, where read = 4, write = 2, and
  execute/search = 1.
* The setuid/setgid/sticky digit is also a sum, where setuid = 4, setgid = 2,
  and sticky = 1.
* The setuid/setgid/sticky digit is optional. If it is absent, Puppet will
  clear any existing setuid/setgid/sticky permissions. (So to make your intent
  clear, you should use at least four digits for numeric modes.)
* When specifying numeric permissions for directories, Puppet sets the search
  permission wherever the read permission is set.

Symbolic modes should be represented as a string of comma-separated
permission clauses, in the form `<WHO><OP><PERM>`:

* "Who" should be any combination of u (user), g (group), and o (other), or a (all)
* "Op" should be = (set exact permissions), + (add select permissions),
  or - (remove select permissions)
* "Perm" should be one or more of:
    * r (read)
    * w (write)
    * x (execute/search)
    * t (sticky)
    * s (setuid/setgid)
    * X (execute/search if directory or if any one user can execute)
    * u (user's current permissions)
    * g (group's current permissions)
    * o (other's current permissions)

Thus, mode `"0664"` could be represented symbolically as either `a=r,ug+w`
or `ug=rw,o=r`.  However, symbolic modes are more expressive than numeric
modes: a mode only affects the specified bits, so `mode => 'ug+w'` will
set the user and group write bits, without affecting any other bits.

See the manual page for GNU or BSD `chmod` for more details
on numeric and symbolic modes.

On Windows, permissions are translated as follows:

* Owner and group names are mapped to Windows SIDs
* The "other" class of users maps to the "Everyone" SID
* The read/write/execute permissions map to the `FILE_GENERIC_READ`,
  `FILE_GENERIC_WRITE`, and `FILE_GENERIC_EXECUTE` access rights; a
  file's owner always has the `FULL_CONTROL` right
* "Other" users can't have any permissions a file's group lacks,
  and its group can't have any permissions its owner lacks; that is, "0644"
  is an acceptable mode, but "0464" is not.

([↑ Back to file attributes](#file-attributes))


#### mtime {#file-attribute-mtime}

_(**Property:** This attribute represents concrete state on the target system.)_

A read-only state to check the file mtime. On *nix-like systems, this
is the time of the most recent change to the content of the file.

([↑ Back to file attributes](#file-attributes))


#### owner {#file-attribute-owner}

_(**Property:** This attribute represents concrete state on the target system.)_

The user to whom the file should belong.  Argument can be a user name or a
user ID.

On Windows, a group (such as "Administrators") can be set as a file's owner
and a user (such as "Administrator") can be set as a file's group; however,
a file's owner and group shouldn't be the same. (If the owner is also
the group, files with modes like `"0640"` will cause log churn, as they
will always appear out of sync.)

([↑ Back to file attributes](#file-attributes))


#### provider {#file-attribute-provider}

The specific backend to use for this `file`
resource. You will seldom need to specify this --- Puppet will usually
discover the appropriate provider for your platform.

Available providers are:

* [`posix`](#file-provider-posix)
* [`windows`](#file-provider-windows)

([↑ Back to file attributes](#file-attributes))


#### purge {#file-attribute-purge}

Whether unmanaged files should be purged. This option only makes
sense when `ensure => directory` and `recurse => true`.

* When recursively duplicating an entire directory with the `source`
  attribute, `purge => true` will automatically purge any files
  that are not in the source directory.
* When managing files in a directory as individual resources,
  setting `purge => true` will purge any files that aren't being
  specifically managed.

If you have a filebucket configured, the purged files will be uploaded,
but if you do not, this will destroy data.

Unless `force => true` is set, purging will **not** delete directories,
although it will delete the files they contain.

If `recurselimit` is set and you aren't using `force => true`, purging
will obey the recursion limit; files in any subdirectories deeper than the
limit will be treated as unmanaged and left alone.

Valid values are `true`, `false`, `yes`, `no`.

([↑ Back to file attributes](#file-attributes))


#### recurse {#file-attribute-recurse}

Whether to recursively manage the _contents_ of a directory. This attribute
is only used when `ensure => directory` is set. The allowed values are:

* `false` --- The default behavior. The contents of the directory will not be
  automatically managed.
* `remote` --- If the `source` attribute is set, Puppet will automatically
  manage the contents of the source directory (or directories), ensuring
  that equivalent files and directories exist on the target system and
  that their contents match.

  Using `remote` will disable the `purge` attribute, but results in faster
  catalog application than `recurse => true`.

  The `source` attribute is mandatory when `recurse => remote`.
* `true` --- If the `source` attribute is set, this behaves similarly to
  `recurse => remote`, automatically managing files from the source directory.

  This also enables the `purge` attribute, which can delete unmanaged
  files from a directory. See the description of `purge` for more details.

  The `source` attribute is not mandatory when using `recurse => true`, so you
  can enable purging in directories where all files are managed individually.

By default, setting recurse to `remote` or `true` will manage _all_
subdirectories. You can use the `recurselimit` attribute to limit the
recursion depth.

Valid values are `true`, `false`, `remote`.

([↑ Back to file attributes](#file-attributes))


#### recurselimit {#file-attribute-recurselimit}

How far Puppet should descend into subdirectories, when using
`ensure => directory` and either `recurse => true` or `recurse => remote`.
The recursion limit affects which files will be copied from the `source`
directory, as well as which files can be purged when `purge => true`.

Setting `recurselimit => 0` is the same as setting `recurse => false` ---
Puppet will manage the directory, but all of its contents will be treated
as unmanaged.

Setting `recurselimit => 1` will manage files and directories that are
directly inside the directory, but will not manage the contents of any
subdirectories.

Setting `recurselimit => 2` will manage the direct contents of the
directory, as well as the contents of the _first_ level of subdirectories.

This pattern continues for each incremental value of `recurselimit`.

Values can match `/^[0-9]+$/`.

([↑ Back to file attributes](#file-attributes))


#### replace {#file-attribute-replace}

Whether to replace a file or symlink that already exists on the local system but
whose content doesn't match what the `source` or `content` attribute
specifies.  Setting this to false allows file resources to initialize files
without overwriting future changes.  Note that this only affects content;
Puppet will still manage ownership and permissions.

Valid values are `true`, `false`, `yes`, `no`.

([↑ Back to file attributes](#file-attributes))


#### selinux_ignore_defaults {#file-attribute-selinux_ignore_defaults}

If this is set, Puppet will not call the SELinux function selabel_lookup to
supply defaults for the SELinux attributes (seluser, selrole,
seltype, and selrange). In general, you should leave this set at its
default and only set it to true when you need Puppet to not try to fix
SELinux labels automatically.

Valid values are `true`, `false`.

([↑ Back to file attributes](#file-attributes))


#### selrange {#file-attribute-selrange}

_(**Property:** This attribute represents concrete state on the target system.)_

What the SELinux range component of the context of the file should be.
Any valid SELinux range component is accepted.  For example `s0` or
`SystemHigh`.  If not specified, it defaults to the value returned by
selabel_lookup for the file, if any exists.  Only valid on systems with
SELinux support enabled and that have support for MCS (Multi-Category
Security).

([↑ Back to file attributes](#file-attributes))


#### selrole {#file-attribute-selrole}

_(**Property:** This attribute represents concrete state on the target system.)_

What the SELinux role component of the context of the file should be.
Any valid SELinux role component is accepted.  For example `role_r`.
If not specified, it defaults to the value returned by selabel_lookup for
the file, if any exists.  Only valid on systems with SELinux support
enabled.

([↑ Back to file attributes](#file-attributes))


#### seltype {#file-attribute-seltype}

_(**Property:** This attribute represents concrete state on the target system.)_

What the SELinux type component of the context of the file should be.
Any valid SELinux type component is accepted.  For example `tmp_t`.
If not specified, it defaults to the value returned by selabel_lookup for
the file, if any exists.  Only valid on systems with SELinux support
enabled.

([↑ Back to file attributes](#file-attributes))


#### seluser {#file-attribute-seluser}

_(**Property:** This attribute represents concrete state on the target system.)_

What the SELinux user component of the context of the file should be.
Any valid SELinux user component is accepted.  For example `user_u`.
If not specified, it defaults to the value returned by selabel_lookup for
the file, if any exists.  Only valid on systems with SELinux support
enabled.

([↑ Back to file attributes](#file-attributes))


#### show_diff {#file-attribute-show_diff}

Whether to display differences when the file changes, defaulting to
true.  This parameter is useful for files that may contain passwords or
other secret data, which might otherwise be included in Puppet reports or
other insecure outputs.  If the global `show_diff` setting
is false, then no diffs will be shown even if this parameter is true.

Valid values are `true`, `false`, `yes`, `no`.

([↑ Back to file attributes](#file-attributes))


#### source {#file-attribute-source}

A source file, which will be copied into place on the local system. This
attribute is mutually exclusive with `content` and `target`. Allowed
values are:

* `puppet:` URIs, which point to files in modules or Puppet file server
mount points.
* Fully qualified paths to locally available files (including files on NFS
shares or Windows mapped drives).
* `file:` URIs, which behave the same as local file paths.
* `http(s):` URIs, which point to files served by common web servers.

The normal form of a `puppet:` URI is:

`puppet:///modules/<MODULE NAME>/<FILE PATH>`

This will fetch a file from a module on the Puppet master (or from a
local module when using Puppet apply). Given a `modulepath` of
`/etc/puppetlabs/code/modules`, the example above would resolve to
`/etc/puppetlabs/code/modules/<MODULE NAME>/files/<FILE PATH>`.

Unlike `content`, the `source` attribute can be used to recursively copy
directories if the `recurse` attribute is set to `true` or `remote`. If
a source directory contains symlinks, use the `links` attribute to
specify whether to recreate links or follow them.

_HTTP_ URIs cannot be used to recursively synchronize whole directory
trees. You cannot use `source_permissions` values other than `ignore`
because HTTP servers do not transfer any metadata that translates to
ownership or permission details.

Puppet determines if file content is synchronized by computing a checksum
for the local file and comparing it against the `checksum_value`
parameter. If the `checksum_value` parameter is not specified for
`puppet` and `file` sources, Puppet computes a checksum based on its
`Puppet[:digest_algorithm]`. For `http(s)` sources, Puppet uses the
first HTTP header it recognizes out of the following list:
`X-Checksum-Sha256`, `X-Checksum-Sha1`, `X-Checksum-Md5` or `Content-MD5`.
If the server response does not include one of these headers, Puppet
defaults to using the `Last-Modified` header. Puppet updates the local
file if the header is newer than the modified time (mtime) of the local
file.

_HTTP_ URIs can include a user information component so that Puppet can
retrieve file metadata and content from HTTP servers that require HTTP Basic
authentication. For example `https://<user>:<pass>@<server>:<port>/path/to/file.`

When connecting to _HTTPS_ servers, Puppet trusts CA certificates in the
puppet-agent certificate bundle and the Puppet CA. You can configure Puppet
to trust additional CA certificates using the `Puppet[:ssl_trust_store]`
setting.

Multiple `source` values can be specified as an array, and Puppet will
use the first source that exists. This can be used to serve different
files to different system types:

    file { '/etc/nfs.conf':
      source => [
        "puppet:///modules/nfs/conf.${host}",
        "puppet:///modules/nfs/conf.${os['name']}",
        'puppet:///modules/nfs/conf'
      ]
    }

Alternately, when serving directories recursively, multiple sources can
be combined by setting the `sourceselect` attribute to `all`.

([↑ Back to file attributes](#file-attributes))


#### source_permissions {#file-attribute-source_permissions}

Whether (and how) Puppet should copy owner, group, and mode permissions from
the `source` to `file` resources when the permissions are not explicitly
specified. (In all cases, explicit permissions will take precedence.)
Valid values are `use`, `use_when_creating`, and `ignore`:

* `ignore` (the default) will never apply the owner, group, or mode from
  the `source` when managing a file. When creating new files without explicit
  permissions, the permissions they receive will depend on platform-specific
  behavior. On POSIX, Puppet will use the umask of the user it is running as.
  On Windows, Puppet will use the default DACL associated with the user it is
  running as.
* `use` will cause Puppet to apply the owner, group,
  and mode from the `source` to any files it is managing.
* `use_when_creating` will only apply the owner, group, and mode from the
  `source` when creating a file; existing files will not have their permissions
  overwritten.

Valid values are `use`, `use_when_creating`, `ignore`.

([↑ Back to file attributes](#file-attributes))


#### sourceselect {#file-attribute-sourceselect}

Whether to copy all valid sources, or just the first one.  This parameter
only affects recursive directory copies; by default, the first valid
source is the only one used, but if this parameter is set to `all`, then
all valid sources will have all of their contents copied to the local
system. If a given file exists in more than one source, the version from
the earliest source in the list will be used.

Valid values are `first`, `all`.

([↑ Back to file attributes](#file-attributes))


#### staging_location {#file-attribute-staging_location}

When rendering a file first render it to this location. The default
location is the same path as the desired location with a unique filename.
This parameter is useful in conjuction with validate_cmd to test a
file before moving the file to it's final location.
WARNING: File replacement is only guaranteed to be atomic if the staging
location is on the same filesystem as the final location.

([↑ Back to file attributes](#file-attributes))


#### target {#file-attribute-target}

_(**Property:** This attribute represents concrete state on the target system.)_

The target for creating a link.  Currently, symlinks are the
only type supported. This attribute is mutually exclusive with `source`
and `content`.

Symlink targets can be relative, as well as absolute:

    # (Useful on Solaris)
    file { '/etc/inetd.conf':
      ensure => link,
      target => 'inet/inetd.conf',
    }

Directories of symlinks can be served recursively by instead using the
`source` attribute, setting `ensure` to `directory`, and setting the
`links` attribute to `manage`.

Valid values are `notlink`. Values can match `/./`.

([↑ Back to file attributes](#file-attributes))


#### type {#file-attribute-type}

_(**Property:** This attribute represents concrete state on the target system.)_

A read-only state to check the file type.

([↑ Back to file attributes](#file-attributes))


#### validate_cmd {#file-attribute-validate_cmd}

A command for validating the file's syntax before replacing it. If
Puppet would need to rewrite a file due to new `source` or `content`, it
will check the new content's validity first. If validation fails, the file
resource will fail.

This command must have a fully qualified path, and should contain a
percent (`%`) token where it would expect an input file. It must exit `0`
if the syntax is correct, and non-zero otherwise. The command will be
run on the target system while applying the catalog, not on the primary Puppet server.

Example:

    file { '/etc/apache2/apache2.conf':
      content      => 'example',
      validate_cmd => '/usr/sbin/apache2 -t -f %',
    }

This would replace apache2.conf only if the test returned true.

Note that if a validation command requires a `%` as part of its text,
you can specify a different placeholder token with the
`validate_replacement` attribute.

([↑ Back to file attributes](#file-attributes))


#### validate_replacement {#file-attribute-validate_replacement}

The replacement string in a `validate_cmd` that will be replaced
with an input file name.

([↑ Back to file attributes](#file-attributes))


### Providers {#file-providers}

#### posix {#file-provider-posix}

Uses POSIX functionality to manage file ownership and permissions.

* Supported features: `manages_symlinks`.

#### windows {#file-provider-windows}

Uses Microsoft Windows functionality to manage file ownership and permissions.

* Supported features: `manages_symlinks`.

### Provider Features {#file-provider-features}

Available features:

* `manages_symlinks` --- The provider can manage symbolic links.

Provider support:

* **posix** - _manages symlinks_
* **windows** - _manages symlinks_
  




---------

## filebucket

* [Attributes](#filebucket-attributes)

### Description {#filebucket-description}

A repository for storing and retrieving file content by cryptographic checksum. Can
be local to each agent node, or centralized on a primary Puppet server. All
puppet servers provide a filebucket service that agent nodes can access
via HTTP, but you must declare a filebucket resource before any agents
will do so.

Filebuckets are used for the following features:

- **Content backups.** If the `file` type's `backup` attribute is set to
  the name of a filebucket, Puppet will back up the _old_ content whenever
  it rewrites a file; see the documentation for the `file` type for more
  details. These backups can be used for manual recovery of content, but
  are more commonly used to display changes and differences in a tool like
  Puppet Dashboard.

To use a central filebucket for backups, you will usually want to declare
a filebucket resource and a resource default for the `backup` attribute
in site.pp:

    # /etc/puppetlabs/puppet/manifests/site.pp
    filebucket { 'main':
      path   => false,                # This is required for remote filebuckets.
      server => 'puppet.example.com', # Optional; defaults to the configured primary server.
    }

    File { backup => main, }

Puppet Servers automatically provide the filebucket service, so
this will work in a default configuration. If you have a heavily
restricted Puppet Server `auth.conf` file, you may need to allow access to the
`file_bucket_file` endpoint.

### Attributes {#filebucket-attributes}

<pre><code>filebucket { 'resource title':
  <a href="#filebucket-attribute-name">name</a>   =&gt; <em># <strong>(namevar)</strong> The name of the...</em>
  <a href="#filebucket-attribute-path">path</a>   =&gt; <em># The path to the _local_ filebucket; defaults to...</em>
  <a href="#filebucket-attribute-port">port</a>   =&gt; <em># The port on which the remote server is...</em>
  <a href="#filebucket-attribute-server">server</a> =&gt; <em># The server providing the remote filebucket...</em>
  # ...plus any applicable <a href="https://puppet.com/docs/puppet/latest/metaparameter.html">metaparameters</a>.
}</code></pre>


#### name {#filebucket-attribute-name}

_(**Namevar:** If omitted, this attribute's value defaults to the resource's title.)_

The name of the filebucket.

([↑ Back to filebucket attributes](#filebucket-attributes))


#### path {#filebucket-attribute-path}

The path to the _local_ filebucket; defaults to the value of the
`clientbucketdir` setting.  To use a remote filebucket, you _must_ set
this attribute to `false`.

([↑ Back to filebucket attributes](#filebucket-attributes))


#### port {#filebucket-attribute-port}

The port on which the remote server is listening.

This setting is _only_ consulted if the `path` attribute is set to `false`.

If this attribute is not specified, the first entry in the `server_list`
configuration setting is used, followed by the value of the `serverport`
setting if `server_list` is not set.

([↑ Back to filebucket attributes](#filebucket-attributes))


#### server {#filebucket-attribute-server}

The server providing the remote filebucket service.

This setting is _only_ consulted if the `path` attribute is set to `false`.

If this attribute is not specified, the first entry in the `server_list`
configuration setting is used, followed by the value of the `server` setting
if `server_list` is not set.

([↑ Back to filebucket attributes](#filebucket-attributes))





---------

## group

* [Attributes](#group-attributes)
* [Providers](#group-providers)
* [Provider Features](#group-provider-features)

### Description {#group-description}

Manage groups. On most platforms this can only create groups.
Group membership must be managed on individual users.

On some platforms such as OS X, group membership is managed as an
attribute of the group, not the user record. Providers must have
the feature 'manages_members' to manage the 'members' property of
a group record.

### Attributes {#group-attributes}

<pre><code>group { 'resource title':
  <a href="#group-attribute-name">name</a>                 =&gt; <em># <strong>(namevar)</strong> The group name. While naming limitations vary by </em>
  <a href="#group-attribute-ensure">ensure</a>               =&gt; <em># Create or remove the group.  Valid values are...</em>
  <a href="#group-attribute-allowdupe">allowdupe</a>            =&gt; <em># Whether to allow duplicate GIDs.  Valid values...</em>
  <a href="#group-attribute-attribute_membership">attribute_membership</a> =&gt; <em># AIX only. Configures the behavior of the...</em>
  <a href="#group-attribute-attributes">attributes</a>           =&gt; <em># Specify group AIX attributes, as an array of...</em>
  <a href="#group-attribute-auth_membership">auth_membership</a>      =&gt; <em># Configures the behavior of the `members...</em>
  <a href="#group-attribute-forcelocal">forcelocal</a>           =&gt; <em># Forces the management of local accounts when...</em>
  <a href="#group-attribute-gid">gid</a>                  =&gt; <em># The group ID.  Must be specified numerically....</em>
  <a href="#group-attribute-ia_load_module">ia_load_module</a>       =&gt; <em># The name of the I&A module to use to manage this </em>
  <a href="#group-attribute-members">members</a>              =&gt; <em># The members of the group. For platforms or...</em>
  <a href="#group-attribute-provider">provider</a>             =&gt; <em># The specific backend to use for this `group...</em>
  <a href="#group-attribute-system">system</a>               =&gt; <em># Whether the group is a system group with lower...</em>
  # ...plus any applicable <a href="https://puppet.com/docs/puppet/latest/metaparameter.html">metaparameters</a>.
}</code></pre>


#### name {#group-attribute-name}

_(**Namevar:** If omitted, this attribute's value defaults to the resource's title.)_

The group name. While naming limitations vary by operating system,
it is advisable to restrict names to the lowest common denominator,
which is a maximum of 8 characters beginning with a letter.

Note that Puppet considers group names to be case-sensitive, regardless
of the platform's own rules; be sure to always use the same case when
referring to a given group.

([↑ Back to group attributes](#group-attributes))


#### ensure {#group-attribute-ensure}

_(**Property:** This attribute represents concrete state on the target system.)_

Create or remove the group.

Valid values are `present`, `absent`.

([↑ Back to group attributes](#group-attributes))


#### allowdupe {#group-attribute-allowdupe}

Whether to allow duplicate GIDs.

Valid values are `true`, `false`, `yes`, `no`.

([↑ Back to group attributes](#group-attributes))


#### attribute_membership {#group-attribute-attribute_membership}

AIX only. Configures the behavior of the `attributes` parameter.

* `minimum` (default) --- The provided list of attributes is partial, and Puppet
  **ignores** any attributes that aren't listed there.
* `inclusive` --- The provided list of attributes is comprehensive, and
  Puppet **purges** any attributes that aren't listed there.

Valid values are `inclusive`, `minimum`.

([↑ Back to group attributes](#group-attributes))


#### attributes {#group-attribute-attributes}

_(**Property:** This attribute represents concrete state on the target system.)_

Specify group AIX attributes, as an array of `'key=value'` strings. This
parameter's behavior can be configured with `attribute_membership`.



Requires features manages_aix_lam.

([↑ Back to group attributes](#group-attributes))


#### auth_membership {#group-attribute-auth_membership}

Configures the behavior of the `members` parameter.

* `false` (default) --- The provided list of group members is partial,
  and Puppet **ignores** any members that aren't listed there.
* `true` --- The provided list of of group members is comprehensive, and
  Puppet **purges** any members that aren't listed there.

Valid values are `true`, `false`, `yes`, `no`.

([↑ Back to group attributes](#group-attributes))


#### forcelocal {#group-attribute-forcelocal}

Forces the management of local accounts when accounts are also
being managed by some other Name Switch Service (NSS). For AIX, refer to the `ia_load_module` parameter.

This option relies on your operating system's implementation of `luser*` commands, such as `luseradd` , `lgroupadd`, and `lusermod`. The `forcelocal` option could behave unpredictably in some circumstances. If the tools it depends on are not available, it might have no effect at all.

Valid values are `true`, `false`, `yes`, `no`.

Requires features manages_local_users_and_groups.

([↑ Back to group attributes](#group-attributes))


#### gid {#group-attribute-gid}

_(**Property:** This attribute represents concrete state on the target system.)_

The group ID.  Must be specified numerically.  If no group ID is
specified when creating a new group, then one will be chosen
automatically according to local system standards. This will likely
result in the same group having different GIDs on different systems,
which is not recommended.

On Windows, this property is read-only and will return the group's security
identifier (SID).

([↑ Back to group attributes](#group-attributes))


#### ia_load_module {#group-attribute-ia_load_module}

The name of the I&A module to use to manage this group.
This should be set to `files` if managing local groups.



Requires features manages_aix_lam.

([↑ Back to group attributes](#group-attributes))


#### members {#group-attribute-members}

_(**Property:** This attribute represents concrete state on the target system.)_

The members of the group. For platforms or directory services where group
membership is stored in the group objects, not the users. This parameter's
behavior can be configured with `auth_membership`.



Requires features manages_members.

([↑ Back to group attributes](#group-attributes))


#### provider {#group-attribute-provider}

The specific backend to use for this `group`
resource. You will seldom need to specify this --- Puppet will usually
discover the appropriate provider for your platform.

Available providers are:

* [`aix`](#group-provider-aix)
* [`directoryservice`](#group-provider-directoryservice)
* [`groupadd`](#group-provider-groupadd)
* [`ldap`](#group-provider-ldap)
* [`pw`](#group-provider-pw)
* [`windows_adsi`](#group-provider-windows_adsi)

([↑ Back to group attributes](#group-attributes))


#### system {#group-attribute-system}

Whether the group is a system group with lower GID.

Valid values are `true`, `false`, `yes`, `no`.

([↑ Back to group attributes](#group-attributes))


### Providers {#group-providers}

#### aix {#group-provider-aix}

Group management for AIX.

* Required binaries: `/usr/bin/chgroup`, `/usr/bin/mkgroup`, `/usr/sbin/lsgroup`, `/usr/sbin/rmgroup`.
* Default for `os.name` == `aix`.
* Supported features: `manages_aix_lam`, `manages_local_users_and_groups`, `manages_members`.

#### directoryservice {#group-provider-directoryservice}

Group management using DirectoryService on OS X.

* Required binaries: `/usr/bin/dscl`.
* Default for `os.name` == `darwin`.
* Supported features: `manages_members`.

#### groupadd {#group-provider-groupadd}

Group management via `groupadd` and its ilk. The default for most platforms.

To use the `forcelocal` parameter, you need to install the `libuser` package (providing
 `/usr/sbin/lgroupadd` and `/usr/sbin/luseradd`).

* Required binaries: `groupadd`, `groupdel`, `groupmod`, `lgroupadd`, `lgroupdel`, `lgroupmod`, `usermod`.
* Supported features: `system_groups`.

#### ldap {#group-provider-ldap}

Group management via LDAP.

This provider requires that you have valid values for all of the
LDAP-related settings in `puppet.conf`, including `ldapbase`.  You will
almost definitely need settings for `ldapuser` and `ldappassword` in order
for your clients to write to LDAP.

Note that this provider will automatically generate a GID for you if you do
not specify one, but it is a potentially expensive operation, as it
iterates across all existing groups to pick the appropriate next one.

#### pw {#group-provider-pw}

Group management via `pw` on FreeBSD and DragonFly BSD.

* Required binaries: `pw`.
* Default for `os.name` == `freebsd, dragonfly`.
* Supported features: `manages_members`.

#### windows_adsi {#group-provider-windows_adsi}

Local group management for Windows. Group members can be both users and groups.
Additionally, local groups can contain domain users.

* Default for `os.name` == `windows`.
* Supported features: `manages_members`.

### Provider Features {#group-provider-features}

Available features:

* `manages_aix_lam` --- The provider can manage AIX Loadable Authentication Module (LAM) system.
* `manages_local_users_and_groups` --- Allows local groups to be managed on systems that also use some other remote Name Switch Service (NSS) method of managing accounts.
* `manages_members` --- For directories where membership is an attribute of groups not users.
* `system_groups` --- The provider allows you to create system groups with lower GIDs.

Provider support:

* **aix** - _manages aix lam, manages local users and groups, manages members_
* **directoryservice** - _manages members_
* **groupadd** - _system groups, libuser_
* **ldap** - No supported Provider features
* **pw** - _manages members_
* **windows_adsi** - _manages members_
  




---------

## notify

* [Attributes](#notify-attributes)

### Description {#notify-description}

Sends an arbitrary message, specified as a string, to the agent run-time log. It's important to note that the notify resource type is not idempotent. As a result, notifications are shown as a change on every Puppet run.

### Attributes {#notify-attributes}

<pre><code>notify { 'resource title':
  <a href="#notify-attribute-name">name</a>     =&gt; <em># <strong>(namevar)</strong> An arbitrary tag for your own reference; the...</em>
  <a href="#notify-attribute-message">message</a>  =&gt; <em># The message to be sent to the log. Note that the </em>
  <a href="#notify-attribute-withpath">withpath</a> =&gt; <em># Whether to show the full object path.  Valid...</em>
  # ...plus any applicable <a href="https://puppet.com/docs/puppet/latest/metaparameter.html">metaparameters</a>.
}</code></pre>


#### name {#notify-attribute-name}

_(**Namevar:** If omitted, this attribute's value defaults to the resource's title.)_

An arbitrary tag for your own reference; the name of the message.

([↑ Back to notify attributes](#notify-attributes))


#### message {#notify-attribute-message}

_(**Property:** This attribute represents concrete state on the target system.)_

The message to be sent to the log. Note that the value specified must be a string.

([↑ Back to notify attributes](#notify-attributes))


#### withpath {#notify-attribute-withpath}

Whether to show the full object path.

Valid values are `true`, `false`.

([↑ Back to notify attributes](#notify-attributes))





---------

## package

* [Attributes](#package-attributes)
* [Providers](#package-providers)
* [Provider Features](#package-provider-features)

### Description {#package-description}

Manage packages.  There is a basic dichotomy in package
support right now:  Some package types (such as yum and apt) can
retrieve their own package files, while others (such as rpm and sun)
cannot.  For those package formats that cannot retrieve their own files,
you can use the `source` parameter to point to the correct file.

Puppet will automatically guess the packaging format that you are
using based on the platform you are on, but you can override it
using the `provider` parameter; each provider defines what it
requires in order to function, and you must meet those requirements
to use a given provider.

You can declare multiple package resources with the same `name` as long
as they have unique titles, and specify different providers and commands.

Note that you must use the _title_ to make a reference to a package
resource; `Package[<NAME>]` is not a synonym for `Package[<TITLE>]` like
it is for many other resource types.

**Autorequires:** If Puppet is managing the files specified as a
package's `adminfile`, `responsefile`, or `source`, the package
resource will autorequire those files.

### Attributes {#package-attributes}

<pre><code>package { 'resource title':
  <a href="#package-attribute-name">name</a>                 =&gt; <em># <strong>(namevar)</strong> The package name.  This is the name that the...</em>
  <a href="#package-attribute-provider">provider</a>             =&gt; <em># <strong>(namevar)</strong> The specific backend to use for this `package...</em>
  <a href="#package-attribute-command">command</a>              =&gt; <em># <strong>(namevar)</strong> The targeted command to use when managing a...</em>
  <a href="#package-attribute-ensure">ensure</a>               =&gt; <em># What state the package should be in. On...</em>
  <a href="#package-attribute-adminfile">adminfile</a>            =&gt; <em># A file containing package defaults for...</em>
  <a href="#package-attribute-allow_virtual">allow_virtual</a>        =&gt; <em># Specifies if virtual package names are allowed...</em>
  <a href="#package-attribute-allowcdrom">allowcdrom</a>           =&gt; <em># Tells apt to allow cdrom sources in the...</em>
  <a href="#package-attribute-category">category</a>             =&gt; <em># A read-only parameter set by the...</em>
  <a href="#package-attribute-configfiles">configfiles</a>          =&gt; <em># Whether to keep or replace modified config files </em>
  <a href="#package-attribute-description">description</a>          =&gt; <em># A read-only parameter set by the...</em>
  <a href="#package-attribute-enable_only">enable_only</a>          =&gt; <em># Tells `dnf module` to only enable a specific...</em>
  <a href="#package-attribute-flavor">flavor</a>               =&gt; <em># OpenBSD and DNF modules support 'flavors', which </em>
  <a href="#package-attribute-install_only">install_only</a>         =&gt; <em># It should be set for packages that should only...</em>
  <a href="#package-attribute-install_options">install_options</a>      =&gt; <em># An array of additional options to pass when...</em>
  <a href="#package-attribute-instance">instance</a>             =&gt; <em># A read-only parameter set by the...</em>
  <a href="#package-attribute-mark">mark</a>                 =&gt; <em># Set to hold to tell Debian apt/Solaris pkg to...</em>
  <a href="#package-attribute-package_settings">package_settings</a>     =&gt; <em># Settings that can change the contents or...</em>
  <a href="#package-attribute-platform">platform</a>             =&gt; <em># A read-only parameter set by the...</em>
  <a href="#package-attribute-reinstall_on_refresh">reinstall_on_refresh</a> =&gt; <em># Whether this resource should respond to refresh...</em>
  <a href="#package-attribute-responsefile">responsefile</a>         =&gt; <em># A file containing any necessary answers to...</em>
  <a href="#package-attribute-root">root</a>                 =&gt; <em># A read-only parameter set by the...</em>
  <a href="#package-attribute-source">source</a>               =&gt; <em># Where to find the package file. This is mostly...</em>
  <a href="#package-attribute-status">status</a>               =&gt; <em># A read-only parameter set by the...</em>
  <a href="#package-attribute-uninstall_options">uninstall_options</a>    =&gt; <em># An array of additional options to pass when...</em>
  <a href="#package-attribute-vendor">vendor</a>               =&gt; <em># A read-only parameter set by the...</em>
  # ...plus any applicable <a href="https://puppet.com/docs/puppet/latest/metaparameter.html">metaparameters</a>.
}</code></pre>


#### name {#package-attribute-name}

_(**Namevar:** If omitted, this attribute's value defaults to the resource's title.)_

The package name.  This is the name that the packaging
system uses internally, which is sometimes (especially on Solaris)
a name that is basically useless to humans.  If a package goes by
several names, you can use a single title and then set the name
conditionally:

    # In the 'openssl' class
    $ssl = $os['name'] ? {
      solaris => SMCossl,
      default => openssl
    }

    package { 'openssl':
      ensure => installed,
      name   => $ssl,
    }

    ...

    $ssh = $os['name'] ? {
      solaris => SMCossh,
      default => openssh
    }

    package { 'openssh':
      ensure  => installed,
      name    => $ssh,
      require => Package['openssl'],
    }

([↑ Back to package attributes](#package-attributes))


#### provider {#package-attribute-provider}

_(**Secondary namevar:** This resource type allows you to manage multiple resources with the same name as long as their providers are different.)_

The specific backend to use for this `package`
resource. You will seldom need to specify this --- Puppet will usually
discover the appropriate provider for your platform.

Available providers are:

* [`aix`](#package-provider-aix)
* [`appdmg`](#package-provider-appdmg)
* [`apple`](#package-provider-apple)
* [`apt`](#package-provider-apt)
* [`aptitude`](#package-provider-aptitude)
* [`aptrpm`](#package-provider-aptrpm)
* [`blastwave`](#package-provider-blastwave)
* [`dnf`](#package-provider-dnf)
* [`dnfmodule`](#package-provider-dnfmodule)
* [`dpkg`](#package-provider-dpkg)
* [`fink`](#package-provider-fink)
* [`freebsd`](#package-provider-freebsd)
* [`gem`](#package-provider-gem)
* [`hpux`](#package-provider-hpux)
* [`macports`](#package-provider-macports)
* [`nim`](#package-provider-nim)
* [`openbsd`](#package-provider-openbsd)
* [`opkg`](#package-provider-opkg)
* [`pacman`](#package-provider-pacman)
* [`pip2`](#package-provider-pip2)
* [`pip3`](#package-provider-pip3)
* [`pip`](#package-provider-pip)
* [`pkg`](#package-provider-pkg)
* [`pkgdmg`](#package-provider-pkgdmg)
* [`pkgin`](#package-provider-pkgin)
* [`pkgng`](#package-provider-pkgng)
* [`pkgutil`](#package-provider-pkgutil)
* [`portage`](#package-provider-portage)
* [`ports`](#package-provider-ports)
* [`portupgrade`](#package-provider-portupgrade)
* [`puppet_gem`](#package-provider-puppet_gem)
* [`puppetserver_gem`](#package-provider-puppetserver_gem)
* [`rpm`](#package-provider-rpm)
* [`rug`](#package-provider-rug)
* [`sun`](#package-provider-sun)
* [`sunfreeware`](#package-provider-sunfreeware)
* [`tdnf`](#package-provider-tdnf)
* [`up2date`](#package-provider-up2date)
* [`urpmi`](#package-provider-urpmi)
* [`windows`](#package-provider-windows)
* [`xbps`](#package-provider-xbps)
* [`yum`](#package-provider-yum)
* [`zypper`](#package-provider-zypper)

([↑ Back to package attributes](#package-attributes))


#### command {#package-attribute-command}

_(**Namevar:** If omitted, this attribute's value defaults to the resource's title.)_

The targeted command to use when managing a package:

  package { 'mysql':
    provider => gem,
  }

  package { 'mysql-opt':
    name     => 'mysql',
    provider => gem,
    command  => '/opt/ruby/bin/gem',
  }

Each provider defines a package management command and uses the first
instance of the command found in the PATH.

Providers supporting the targetable feature allow you to specify the
absolute path of the package management command. Specifying the absolute
path is useful when multiple instances of the command are installed, or
the command is not in the PATH.



Requires features targetable.

([↑ Back to package attributes](#package-attributes))


#### ensure {#package-attribute-ensure}

_(**Property:** This attribute represents concrete state on the target system.)_

What state the package should be in. On packaging systems that can
retrieve new packages on their own, you can choose which package to
retrieve by specifying a version number or `latest` as the ensure
value. On packaging systems that manage configuration files separately
from "normal" system files, you can uninstall config files by
specifying `purged` as the ensure value. This defaults to `installed`.

Version numbers must match the full version to install, including
release if the provider uses a release moniker. For
example, to install the bash package from the rpm
`bash-4.1.2-29.el6.x86_64.rpm`, use the string `'4.1.2-29.el6'`.

On supported providers, version ranges can also be ensured. For example,
inequalities: `<2.0.0`, or intersections: `>1.0.0 <2.0.0`.

Valid values are `present` (also called `installed`), `absent`, `purged`, `disabled`, `latest`. Values can match `/./`.

([↑ Back to package attributes](#package-attributes))


#### adminfile {#package-attribute-adminfile}

A file containing package defaults for installing packages.

This attribute is only used on Solaris. Its value should be a path to a
local file stored on the target system. Solaris's package tools expect
either an absolute file path or a relative path to a file in
`/var/sadm/install/admin`.

The value of `adminfile` will be passed directly to the `pkgadd` or
`pkgrm` command with the `-a <ADMINFILE>` option.

([↑ Back to package attributes](#package-attributes))


#### allow_virtual {#package-attribute-allow_virtual}

Specifies if virtual package names are allowed for install and uninstall.

Valid values are `true`, `false`, `yes`, `no`.

Requires features virtual_packages.

([↑ Back to package attributes](#package-attributes))


#### allowcdrom {#package-attribute-allowcdrom}

Tells apt to allow cdrom sources in the sources.list file.
Normally apt will bail if you try this.

Valid values are `true`, `false`.

([↑ Back to package attributes](#package-attributes))


#### category {#package-attribute-category}

A read-only parameter set by the package.

([↑ Back to package attributes](#package-attributes))


#### configfiles {#package-attribute-configfiles}

Whether to keep or replace modified config files when installing or
upgrading a package. This only affects the `apt` and `dpkg` providers.

Valid values are `keep`, `replace`.

([↑ Back to package attributes](#package-attributes))


#### description {#package-attribute-description}

A read-only parameter set by the package.

([↑ Back to package attributes](#package-attributes))


#### enable_only {#package-attribute-enable_only}

Tells `dnf module` to only enable a specific module, instead
of installing its default profile.

Modules with no default profile will be enabled automatically
without the use of this parameter.

Conflicts with the `flavor` property, which selects a profile
to install.

Valid values are `true`, `false`, `yes`, `no`.

([↑ Back to package attributes](#package-attributes))


#### flavor {#package-attribute-flavor}

_(**Property:** This attribute represents concrete state on the target system.)_

OpenBSD and DNF modules support 'flavors', which are
further specifications for which type of package you want.



Requires features supports_flavors.

([↑ Back to package attributes](#package-attributes))


#### install_only {#package-attribute-install_only}

It should be set for packages that should only ever be installed,
never updated. Kernels in particular fall into this category.

Valid values are `true`, `false`, `yes`, `no`.

Requires features install_only.

([↑ Back to package attributes](#package-attributes))


#### install_options {#package-attribute-install_options}

An array of additional options to pass when installing a package. These
options are package-specific, and should be documented by the software
vendor.  One commonly implemented option is `INSTALLDIR`:

    package { 'mysql':
      ensure          => installed,
      source          => 'N:/packages/mysql-5.5.16-winx64.msi',
      install_options => [ '/S', { 'INSTALLDIR' => 'C:\mysql-5.5' } ],
    }

Each option in the array can either be a string or a hash, where each
key and value pair are interpreted in a provider specific way.  Each
option will automatically be quoted when passed to the install command.

With Windows packages, note that file paths in an install option must
use backslashes. (Since install options are passed directly to the
installation command, forward slashes won't be automatically converted
like they are in `file` resources.) Note also that backslashes in
double-quoted strings _must_ be escaped and backslashes in single-quoted
strings _can_ be escaped.



Requires features install_options.

([↑ Back to package attributes](#package-attributes))


#### instance {#package-attribute-instance}

A read-only parameter set by the package.

([↑ Back to package attributes](#package-attributes))


#### mark {#package-attribute-mark}

_(**Property:** This attribute represents concrete state on the target system.)_

Set to hold to tell Debian apt/Solaris pkg to hold the package version

Valid values are: hold/none
Default is "none". Mark can be specified with or without `ensure`,
if `ensure` is missing will default to "present".

Mark cannot be specified together with "purged", or "absent"
values for `ensure`.

Valid values are `hold`, `none`.

Requires features holdable.

([↑ Back to package attributes](#package-attributes))


#### package_settings {#package-attribute-package_settings}

_(**Property:** This attribute represents concrete state on the target system.)_

Settings that can change the contents or configuration of a package.

The formatting and effects of package_settings are provider-specific; any
provider that implements them must explain how to use them in its
documentation. (Our general expectation is that if a package is
installed but its settings are out of sync, the provider should
re-install that package with the desired settings.)

An example of how package_settings could be used is FreeBSD's port build
options --- a future version of the provider could accept a hash of options,
and would reinstall the port if the installed version lacked the correct
settings.

    package { 'www/apache22':
      package_settings => { 'SUEXEC' => false }
    }

Again, check the documentation of your platform's package provider to see
the actual usage.



Requires features package_settings.

([↑ Back to package attributes](#package-attributes))


#### platform {#package-attribute-platform}

A read-only parameter set by the package.

([↑ Back to package attributes](#package-attributes))


#### reinstall_on_refresh {#package-attribute-reinstall_on_refresh}

Whether this resource should respond to refresh events (via `subscribe`,
`notify`, or the `~>` arrow) by reinstalling the package. Only works for
providers that support the `reinstallable` feature.

This is useful for source-based distributions, where you may want to
recompile a package if the build options change.

If you use this, be careful of notifying classes when you want to restart
services. If the class also contains a refreshable package, doing so could
cause unnecessary re-installs.

Valid values are `true`, `false`.

([↑ Back to package attributes](#package-attributes))


#### responsefile {#package-attribute-responsefile}

A file containing any necessary answers to questions asked by
the package.  This is currently used on Solaris and Debian.  The
value will be validated according to system rules, but it should
generally be a fully qualified path.

([↑ Back to package attributes](#package-attributes))


#### root {#package-attribute-root}

A read-only parameter set by the package.

([↑ Back to package attributes](#package-attributes))


#### source {#package-attribute-source}

Where to find the package file. This is mostly used by providers that don't
automatically download packages from a central repository. (For example:
the `yum` provider ignores this attribute, `apt` provider uses it if present
and the `rpm` and `dpkg` providers require it.)

Different providers accept different values for `source`. Most providers
accept paths to local files stored on the target system. Some providers
may also accept URLs or network drive paths. Puppet will not
automatically retrieve source files for you, and usually just passes the
value of `source` to the package installation command.

You can use a `file` resource if you need to manually copy package files
to the target system.

([↑ Back to package attributes](#package-attributes))


#### status {#package-attribute-status}

A read-only parameter set by the package.

([↑ Back to package attributes](#package-attributes))


#### uninstall_options {#package-attribute-uninstall_options}

An array of additional options to pass when uninstalling a package. These
options are package-specific, and should be documented by the software
vendor.  For example:

    package { 'VMware Tools':
      ensure            => absent,
      uninstall_options => [ { 'REMOVE' => 'Sync,VSS' } ],
    }

Each option in the array can either be a string or a hash, where each
key and value pair are interpreted in a provider specific way.  Each
option will automatically be quoted when passed to the uninstall
command.

On Windows, this is the **only** place in Puppet where backslash
separators should be used.  Note that backslashes in double-quoted
strings _must_ be double-escaped and backslashes in single-quoted
strings _may_ be double-escaped.



Requires features uninstall_options.

([↑ Back to package attributes](#package-attributes))


#### vendor {#package-attribute-vendor}

A read-only parameter set by the package.

([↑ Back to package attributes](#package-attributes))


### Providers {#package-providers}

#### aix {#package-provider-aix}

Installation from an AIX software directory, using the AIX `installp`
command.  The `source` parameter is required for this provider, and should
be set to the absolute path (on the puppet agent machine) of a directory
containing one or more BFF package files.

The `installp` command will generate a table of contents file (named `.toc`)
in this directory, and the `name` parameter (or resource title) that you
specify for your `package` resource must match a package name that exists
in the `.toc` file.

Note that package downgrades are *not* supported; if your resource specifies
a specific version number and there is already a newer version of the package
installed on the machine, the resource will fail with an error message.

* Required binaries: `/usr/bin/lslpp`, `/usr/sbin/installp`.
* Default for `os.name` == `aix`.
* Supported features: `installable`, `uninstallable`, `upgradeable`, `versionable`.

#### appdmg {#package-provider-appdmg}

Package management which copies application bundles to a target.

* Required binaries: `/usr/bin/curl`, `/usr/bin/ditto`, `/usr/bin/hdiutil`.
* Supported features: `installable`.

#### apple {#package-provider-apple}

Package management based on OS X's built-in packaging system.  This is
essentially the simplest and least functional package system in existence --
it only supports installation; no deletion or upgrades.  The provider will
automatically add the `.pkg` extension, so leave that off when specifying
the package name.

* Required binaries: `/usr/sbin/installer`.
* Supported features: `installable`.

#### apt {#package-provider-apt}

Package management via `apt-get`.

This provider supports the `install_options` attribute, which allows command-line flags to be passed to apt-get.
These options should be specified as an array where each element is either a
 string or a hash.

* Required binaries: `/usr/bin/apt-cache`, `/usr/bin/apt-get`, `/usr/bin/apt-mark`, `/usr/bin/debconf-set-selections`.
* Default for `os.family` == `debian`.
* Supported features: `holdable`, `install_options`, `installable`, `purgeable`, `uninstallable`, `upgradeable`, `version_ranges`, `versionable`, `virtual_packages`.

#### aptitude {#package-provider-aptitude}

Package management via `aptitude`.

* Required binaries: `/usr/bin/apt-cache`, `/usr/bin/aptitude`.
* Supported features: `holdable`, `installable`, `purgeable`, `uninstallable`, `upgradeable`, `versionable`.

#### aptrpm {#package-provider-aptrpm}

Package management via `apt-get` ported to `rpm`.

* Required binaries: `apt-cache`, `apt-get`, `rpm`.
* Supported features: `installable`, `purgeable`, `uninstallable`, `upgradeable`, `versionable`.

#### blastwave {#package-provider-blastwave}

Package management using Blastwave.org's `pkg-get` command on Solaris.

* Required binaries: `pkg-get`.
* Supported features: `installable`, `uninstallable`, `upgradeable`.

#### dnf {#package-provider-dnf}

Support via `dnf`.

Using this provider's `uninstallable` feature will not remove dependent packages. To
remove dependent packages with this provider use the `purgeable` feature, but note this
feature is destructive and should be used with the utmost care.

This provider supports the `install_options` attribute, which allows command-line flags to be passed to dnf.
These options should be specified as an array where each element is either
 a string or a hash.

* Required binaries: `dnf`, `rpm`.
* Default for `os.name` == `fedora`. Default for `os.family` == `redhat`. Default for `os.name` == `amazon` and `os.release.major` == `2023`.
* Supported features: `install_only`, `install_options`, `installable`, `purgeable`, `uninstallable`, `upgradeable`, `version_ranges`, `versionable`, `virtual_packages`.

#### dnfmodule {#package-provider-dnfmodule}

* Required binaries: `/usr/bin/dnf`.
* Supported features: `disableable`, `installable`, `purgeable`, `supports_flavors`, `uninstallable`, `upgradeable`, `versionable`.

#### dpkg {#package-provider-dpkg}

Package management via `dpkg`.  Because this only uses `dpkg`
and not `apt`, you must specify the source of any packages you want
to manage.

* Required binaries: `/usr/bin/dpkg-deb`, `/usr/bin/dpkg-query`, `/usr/bin/dpkg`.
* Supported features: `holdable`, `installable`, `purgeable`, `uninstallable`, `upgradeable`, `virtual_packages`.

#### fink {#package-provider-fink}

Package management via `fink`.

* Required binaries: `/sw/bin/apt-cache`, `/sw/bin/apt-get`, `/sw/bin/dpkg-query`, `/sw/bin/fink`.
* Supported features: `holdable`, `installable`, `purgeable`, `uninstallable`, `upgradeable`, `versionable`.

#### freebsd {#package-provider-freebsd}

The specific form of package management on FreeBSD.  This is an
extremely quirky packaging system, in that it freely mixes between
ports and packages.  Apparently all of the tools are written in Ruby,
so there are plans to rewrite this support to directly use those
libraries.

* Required binaries: `/usr/sbin/pkg_add`, `/usr/sbin/pkg_delete`, `/usr/sbin/pkg_info`.
* Supported features: `installable`, `purgeable`, `uninstallable`, `upgradeable`.

#### gem {#package-provider-gem}

Ruby Gem support. If a URL is passed via `source`, then that URL is
appended to the list of remote gem repositories; to ensure that only the
specified source is used, also pass `--clear-sources` via `install_options`.
If source is present but is not a valid URL, it will be interpreted as the
path to a local gem file. If source is not present, the gem will be
installed from the default gem repositories. Note that to modify this for Windows, it has to be a valid URL.

This provider supports the `install_options` and `uninstall_options` attributes,
which allow command-line flags to be passed to the gem command.
These options should be specified as an array where each element is either a
string or a hash.

* Required binaries: `gem`.
* Supported features: `install_options`, `installable`, `targetable`, `uninstall_options`, `uninstallable`, `upgradeable`, `version_ranges`, `versionable`.

#### hpux {#package-provider-hpux}

HP-UX's packaging system.

* Required binaries: `/usr/sbin/swinstall`, `/usr/sbin/swlist`, `/usr/sbin/swremove`.
* Default for `os.name` == `hp-ux`.
* Supported features: `installable`, `uninstallable`.

#### macports {#package-provider-macports}

Package management using MacPorts on OS X.

Supports MacPorts versions and revisions, but not variants.
Variant preferences may be specified using
[the MacPorts variants.conf file](http://guide.macports.org/chunked/internals.configuration-files.html#internals.configuration-files.variants-conf).

When specifying a version in the Puppet DSL, only specify the version, not the revision.
Revisions are only used internally for ensuring the latest version/revision of a port.

* Required binaries: `/opt/local/bin/port`.
* Supported features: `installable`, `uninstallable`, `upgradeable`, `versionable`.

#### nim {#package-provider-nim}

Installation from an AIX NIM LPP source.  The `source` parameter is required
for this provider, and should specify the name of a NIM `lpp_source` resource
that is visible to the puppet agent machine.  This provider supports the
management of both BFF/installp and RPM packages.

Note that package downgrades are *not* supported; if your resource specifies
a specific version number and there is already a newer version of the package
installed on the machine, the resource will fail with an error message.

* Required binaries: `/usr/bin/lslpp`, `/usr/sbin/nimclient`, `rpm`.
* Supported features: `installable`, `uninstallable`, `upgradeable`, `versionable`.

#### openbsd {#package-provider-openbsd}

OpenBSD's form of `pkg_add` support.

This provider supports the `install_options` and `uninstall_options`
attributes, which allow command-line flags to be passed to pkg_add and pkg_delete.
These options should be specified as an array where each element is either a
 string or a hash.

* Required binaries: `pkg_add`, `pkg_delete`, `pkg_info`.
* Default for `os.name` == `openbsd`.
* Supported features: `install_options`, `installable`, `purgeable`, `supports_flavors`, `uninstall_options`, `uninstallable`, `upgradeable`, `versionable`.

#### opkg {#package-provider-opkg}

Opkg packaging support. Common on OpenWrt and OpenEmbedded platforms

* Required binaries: `opkg`.
* Default for `os.name` == `openwrt`.
* Supported features: `installable`, `uninstallable`, `upgradeable`.

#### pacman {#package-provider-pacman}

Support for the Package Manager Utility (pacman) used in Archlinux.

This provider supports the `install_options` attribute, which allows command-line flags to be passed to pacman.
These options should be specified as an array where each element is either a string or a hash.

* Required binaries: `/usr/bin/pacman`.
* Default for `os.name` == `archlinux, manjarolinux, artix`.
* Supported features: `install_options`, `installable`, `purgeable`, `uninstall_options`, `uninstallable`, `upgradeable`, `virtual_packages`.

#### pip {#package-provider-pip}

Python packages via `pip`.

This provider supports the `install_options` attribute, which allows command-line flags to be passed to pip.
These options should be specified as an array where each element is either a string or a hash.

* Supported features: `install_options`, `installable`, `targetable`, `uninstallable`, `upgradeable`, `version_ranges`, `versionable`.

#### pip2 {#package-provider-pip2}

Python packages via `pip2`.

This provider supports the `install_options` attribute, which allows command-line flags to be passed to pip2.
These options should be specified as an array where each element is either a string or a hash.

* Supported features: `install_options`, `installable`, `targetable`, `uninstallable`, `upgradeable`, `versionable`.

#### pip3 {#package-provider-pip3}

Python packages via `pip3`.

This provider supports the `install_options` attribute, which allows command-line flags to be passed to pip3.
These options should be specified as an array where each element is either a string or a hash.

* Supported features: `install_options`, `installable`, `targetable`, `uninstallable`, `upgradeable`, `versionable`.

#### pkg {#package-provider-pkg}

OpenSolaris image packaging system. See pkg(5) for more information.

This provider supports the `install_options` attribute, which allows
command-line flags to be passed to pkg. These options should be specified as an
array where each element is either a string or a hash.

* Required binaries: `/usr/bin/pkg`.
* Default for `kernelrelease` == `5.11, 5.12` and `os.family` == `solaris`.
* Supported features: `holdable`, `install_options`, `installable`, `uninstallable`, `upgradeable`, `versionable`.

#### pkgdmg {#package-provider-pkgdmg}

Package management based on Apple's Installer.app and DiskUtility.app.

This provider works by checking the contents of a DMG image for Apple pkg or
mpkg files. Any number of pkg or mpkg files may exist in the root directory
of the DMG file system, and Puppet will install all of them. Subdirectories
are not checked for packages.

This provider can also accept plain .pkg (but not .mpkg) files in addition
to .dmg files.

Notes:

* The `source` attribute is mandatory. It must be either a local disk path
  or an HTTP, HTTPS, or FTP URL to the package.
* The `name` of the resource must be the filename (without path) of the DMG file.
* When installing the packages from a DMG, this provider writes a file to
  disk at `/var/db/.puppet_pkgdmg_installed_NAME`. If that file is present,
  Puppet assumes all packages from that DMG are already installed.
* This provider is not versionable and uses DMG filenames to determine
  whether a package has been installed. Thus, to install new a version of a
  package, you must create a new DMG with a different filename.

* Required binaries: `/usr/bin/curl`, `/usr/bin/hdiutil`, `/usr/sbin/installer`.
* Default for `os.name` == `darwin`.
* Supported features: `installable`.

#### pkgin {#package-provider-pkgin}

Package management using pkgin, a binary package manager for pkgsrc.

* Required binaries: `pkgin`.
* Default for `os.name` == `smartos, netbsd`.
* Supported features: `installable`, `uninstallable`, `upgradeable`, `versionable`.

#### pkgng {#package-provider-pkgng}

A PkgNG provider for FreeBSD and DragonFly.

* Required binaries: `/usr/local/sbin/pkg`.
* Default for `os.name` == `freebsd, dragonfly`.
* Supported features: `install_options`, `installable`, `uninstallable`, `upgradeable`, `versionable`.

#### pkgutil {#package-provider-pkgutil}

Package management using Peter Bonivart's ``pkgutil`` command on Solaris.

* Required binaries: `pkgutil`.
* Supported features: `installable`, `uninstallable`, `upgradeable`.

#### portage {#package-provider-portage}

Provides packaging support for Gentoo's portage system.

This provider supports the `install_options` and `uninstall_options` attributes, which allows command-line
flags to be passed to emerge. These options should be specified as an array where each element is either a string or a hash.

* Required binaries: `/usr/bin/eix-update`, `/usr/bin/eix`, `/usr/bin/emerge`, `/usr/bin/qatom`.
* Default for `os.family` == `gentoo`.
* Supported features: `install_options`, `installable`, `purgeable`, `reinstallable`, `uninstall_options`, `uninstallable`, `upgradeable`, `versionable`, `virtual_packages`.

#### ports {#package-provider-ports}

Support for FreeBSD's ports.  Note that this, too, mixes packages and ports.

* Required binaries: `/usr/local/sbin/pkg_deinstall`, `/usr/local/sbin/portupgrade`, `/usr/local/sbin/portversion`, `/usr/sbin/pkg_info`.
* Supported features: `installable`, `purgeable`, `uninstallable`, `upgradeable`.

#### portupgrade {#package-provider-portupgrade}

Support for FreeBSD's ports using the portupgrade ports management software.
Use the port's full origin as the resource name. eg (ports-mgmt/portupgrade)
for the portupgrade port.

* Required binaries: `/usr/local/sbin/pkg_deinstall`, `/usr/local/sbin/portinstall`, `/usr/local/sbin/portupgrade`, `/usr/local/sbin/portversion`, `/usr/sbin/pkg_info`.
* Supported features: `installable`, `uninstallable`, `upgradeable`.

#### puppet_gem {#package-provider-puppet_gem}

Puppet Ruby Gem support. This provider is useful for managing
gems needed by the ruby provided in the puppet-agent package.

* Required binaries: `/opt/puppetlabs/puppet/bin/gem`.
* Supported features: `install_options`, `installable`, `uninstall_options`, `uninstallable`, `upgradeable`, `versionable`.

#### puppetserver_gem {#package-provider-puppetserver_gem}

Puppet Server Ruby Gem support. If a URL is passed via `source`, then
that URL is appended to the list of remote gem repositories which by default
contains rubygems.org; To ensure that only the specified source is used also
pass `--clear-sources` in via `install_options`; if a source is present but
is not a valid URL, it will be interpreted as the path to a local gem file.
If source is not present at all, the gem will be installed from the default
gem repositories.

* Required binaries: `/opt/puppetlabs/bin/puppetserver`.
* Supported features: `install_options`, `installable`, `uninstall_options`, `uninstallable`, `upgradeable`, `versionable`.

#### rpm {#package-provider-rpm}

RPM packaging support; should work anywhere with a working `rpm`
binary.

This provider supports the `install_options` and `uninstall_options`
attributes, which allow command-line flags to be passed to rpm.
These options should be specified as an array where each element is either a string or a hash.

* Required binaries: `rpm`.
* Supported features: `install_only`, `install_options`, `installable`, `uninstall_options`, `uninstallable`, `upgradeable`, `versionable`, `virtual_packages`.

#### rug {#package-provider-rug}

Support for suse `rug` package manager.

* Required binaries: `/usr/bin/rug`, `rpm`.
* Supported features: `installable`, `uninstallable`, `upgradeable`, `versionable`.

#### sun {#package-provider-sun}

Sun's packaging system.  Requires that you specify the source for
the packages you're managing.

This provider supports the `install_options` attribute, which allows command-line flags to be passed to pkgadd.
These options should be specified as an array where each element is either a string
 or a hash.

* Required binaries: `/usr/bin/pkginfo`, `/usr/sbin/pkgadd`, `/usr/sbin/pkgrm`.
* Default for `os.family` == `solaris`.
* Supported features: `install_options`, `installable`, `uninstallable`, `upgradeable`.

#### sunfreeware {#package-provider-sunfreeware}

Package management using sunfreeware.com's `pkg-get` command on Solaris.
At this point, support is exactly the same as `blastwave` support and
has not actually been tested.

* Required binaries: `pkg-get`.
* Supported features: `installable`, `uninstallable`, `upgradeable`.

#### tdnf {#package-provider-tdnf}

Support via `tdnf`.

This provider supports the `install_options` attribute, which allows command-line flags to be passed to tdnf.
These options should be spcified as a string (e.g. '--flag'), a hash (e.g. {'--flag' => 'value'}), or an
array where each element is either a string or a hash.

* Required binaries: `rpm`, `tdnf`.
* Default for `os.name` == `PhotonOS`.
* Supported features: `install_options`, `installable`, `purgeable`, `uninstallable`, `upgradeable`, `versionable`, `virtual_packages`.

#### up2date {#package-provider-up2date}

Support for Red Hat's proprietary `up2date` package update
mechanism.

* Required binaries: `/usr/sbin/up2date-nox`.
* Default for `os.distro.release.full` == `2.1, 3, 4` and `os.family` == `redhat`.
* Supported features: `installable`, `uninstallable`, `upgradeable`.

#### urpmi {#package-provider-urpmi}

Support via `urpmi`.

* Required binaries: `rpm`, `urpme`, `urpmi`, `urpmq`.
* Default for `os.name` == `mandriva, mandrake`.
* Supported features: `installable`, `purgeable`, `uninstallable`, `upgradeable`, `versionable`.

#### windows {#package-provider-windows}

Windows package management.

This provider supports either MSI or self-extracting executable installers.

This provider requires a `source` attribute when installing the package.
It accepts paths to local files, mapped drives, or UNC paths.

This provider supports the `install_options` and `uninstall_options`
attributes, which allow command-line flags to be passed to the installer.
These options should be specified as an array where each element is either
a string or a hash.

If the executable requires special arguments to perform a silent install or
uninstall, then the appropriate arguments should be specified using the
`install_options` or `uninstall_options` attributes, respectively.  Puppet
will automatically quote any option that contains spaces.

* Default for `os.name` == `windows`.
* Supported features: `install_options`, `installable`, `uninstall_options`, `uninstallable`, `versionable`.

#### xbps {#package-provider-xbps}

Support for the Package Manager Utility (xbps) used in VoidLinux.

This provider supports the `install_options` attribute, which allows command-line flags to be passed to xbps-install.
These options should be specified as an array where each element is either a string or a hash.

* Required binaries: `/usr/bin/xbps-install`, `/usr/bin/xbps-pkgdb`, `/usr/bin/xbps-query`, `/usr/bin/xbps-remove`.
* Default for `os.name` == `void`.
* Supported features: `holdable`, `install_options`, `installable`, `uninstall_options`, `uninstallable`, `upgradeable`, `virtual_packages`.

#### yum {#package-provider-yum}

Support via `yum`.

Using this provider's `uninstallable` feature will not remove dependent packages. To
remove dependent packages with this provider use the `purgeable` feature, but note this
feature is destructive and should be used with the utmost care.

This provider supports the `install_options` attribute, which allows command-line flags to be passed to yum.
These options should be specified as an array where each element is either a string or a hash.

* Required binaries: `rpm`, `yum`.
* Default for `os.name` == `amazon`. Default for `os.family` == `redhat` and `os.release.major` == `4, 5, 6, 7`.
* Supported features: `install_only`, `install_options`, `installable`, `purgeable`, `uninstallable`, `upgradeable`, `version_ranges`, `versionable`, `virtual_packages`.

#### zypper {#package-provider-zypper}

Support for SuSE `zypper` package manager. Found in SLES10sp2+ and SLES11.

This provider supports the `install_options` attribute, which allows command-line flags to be passed to zypper.
These options should be specified as an array where each element is either a
string or a hash.

* Required binaries: `/usr/bin/zypper`.
* Default for `os.name` == `suse, sles, sled, opensuse`.
* Supported features: `install_options`, `installable`, `uninstallable`, `upgradeable`, `versionable`, `virtual_packages`.

### Provider Features {#package-provider-features}

Available features:

* `disableable` --- The provider can disable packages. This feature is used by specifying `disabled` as the desired value for the package.
* `holdable` --- The provider is capable of placing packages on hold such that they are not automatically upgraded as a result of other package dependencies unless explicit action is taken by a user or another package.
* `install_only` --- The provider accepts options to only install packages never update (kernels, etc.)
* `install_options` --- The provider accepts options to be passed to the installer command.
* `installable` --- The provider can install packages.
* `package_settings` --- The provider accepts package_settings to be ensured for the given package. The meaning and format of these settings is provider-specific.
* `purgeable` --- The provider can purge packages.  This generally means that all traces of the package are removed, including existing configuration files.  This feature is thus destructive and should be used with the utmost care.
* `reinstallable` --- The provider can reinstall packages.
* `supports_flavors` --- The provider accepts flavors, which are specific variants of packages.
* `targetable` --- The provider accepts a targeted package management command.
* `uninstall_options` --- The provider accepts options to be passed to the uninstaller command.
* `uninstallable` --- The provider can uninstall packages.
* `upgradeable` --- The provider can upgrade to the latest version of a package.  This feature is used by specifying `latest` as the desired value for the package.
* `version_ranges` --- The provider can ensure version ranges.
* `versionable` --- The provider is capable of interrogating the package database for installed version(s), and can select which out of a set of available versions of a package to install if asked.
* `virtual_packages` --- The provider accepts virtual package names for install and uninstall.

Provider support:

* **aix** - _installable, uninstallable, upgradeable, versionable_
* **appdmg** - _installable_
* **apple** - _installable_
* **apt** - _holdable, install options, installable, purgeable, uninstallable, upgradeable, version ranges, versionable, virtual packages_
* **aptitude** - _holdable, installable, purgeable, uninstallable, upgradeable, versionable_
* **aptrpm** - _installable, purgeable, uninstallable, upgradeable, versionable_
* **blastwave** - _installable, uninstallable, upgradeable_
* **dnf** - _install only, install options, installable, purgeable, uninstallable, upgradeable, version ranges, versionable, virtual packages_
* **dnfmodule** - _disableable, installable, purgeable, supports flavors, uninstallable, upgradeable, versionable_
* **dpkg** - _holdable, installable, purgeable, uninstallable, upgradeable, virtual packages_
* **fink** - _holdable, installable, purgeable, uninstallable, upgradeable, versionable_
* **freebsd** - _installable, purgeable, uninstallable, upgradeable_
* **gem** - _install options, installable, targetable, uninstall options, uninstallable, upgradeable, version ranges, versionable_
* **hpux** - _installable, uninstallable_
* **macports** - _installable, uninstallable, upgradeable, versionable_
* **nim** - _installable, uninstallable, upgradeable, versionable_
* **openbsd** - _install options, installable, purgeable, supports flavors, uninstall options, uninstallable, upgradeable, versionable_
* **opkg** - _installable, uninstallable, upgradeable_
* **pacman** - _install options, installable, purgeable, uninstall options, uninstallable, upgradeable, virtual packages_
* **pip** - _install options, installable, targetable, uninstallable, upgradeable, version ranges, versionable_
* **pip2** - _install options, installable, targetable, uninstallable, upgradeable, versionable_
* **pip3** - _install options, installable, targetable, uninstallable, upgradeable, versionable_
* **pkg** - _holdable, install options, installable, uninstallable, upgradeable, versionable_
* **pkgdmg** - _installable_
* **pkgin** - _installable, uninstallable, upgradeable, versionable_
* **pkgng** - _install options, installable, uninstallable, upgradeable, versionable_
* **pkgutil** - _installable, uninstallable, upgradeable_
* **portage** - _install options, installable, purgeable, reinstallable, uninstall options, uninstallable, upgradeable, versionable, virtual packages_
* **ports** - _installable, purgeable, uninstallable, upgradeable_
* **portupgrade** - _installable, uninstallable, upgradeable_
* **puppet_gem** - _install options, installable, uninstall options, uninstallable, upgradeable, versionable_
* **puppetserver_gem** - _install options, installable, uninstall options, uninstallable, upgradeable, versionable_
* **rpm** - _install only, install options, installable, uninstall options, uninstallable, upgradeable, versionable, virtual packages_
* **rug** - _installable, uninstallable, upgradeable, versionable_
* **sun** - _install options, installable, uninstallable, upgradeable_
* **sunfreeware** - _installable, uninstallable, upgradeable_
* **tdnf** - _install options, installable, purgeable, uninstallable, upgradeable, versionable, virtual packages_
* **up2date** - _installable, uninstallable, upgradeable_
* **urpmi** - _installable, purgeable, uninstallable, upgradeable, versionable_
* **windows** - _install options, installable, uninstall options, uninstallable, versionable_
* **xbps** - _holdable, install options, installable, uninstall options, uninstallable, upgradeable, virtual packages_
* **yum** - _install only, install options, installable, purgeable, uninstallable, upgradeable, version ranges, versionable, virtual packages_
* **zypper** - _install options, installable, uninstallable, upgradeable, versionable, virtual packages_
  




---------

## resources

* [Attributes](#resources-attributes)

### Description {#resources-description}

This is a metatype that can manage other resource types.  Any
metaparams specified here will be passed on to any generated resources,
so you can purge unmanaged resources but set `noop` to true so the
purging is only logged and does not actually happen.

### Attributes {#resources-attributes}

<pre><code>resources { 'resource title':
  <a href="#resources-attribute-name">name</a>               =&gt; <em># <strong>(namevar)</strong> The name of the type to be...</em>
  <a href="#resources-attribute-purge">purge</a>              =&gt; <em># Whether to purge unmanaged resources.  When set...</em>
  <a href="#resources-attribute-unless_system_user">unless_system_user</a> =&gt; <em># This keeps system users from being purged.  By...</em>
  <a href="#resources-attribute-unless_uid">unless_uid</a>         =&gt; <em># This keeps specific uids or ranges of uids from...</em>
  # ...plus any applicable <a href="https://puppet.com/docs/puppet/latest/metaparameter.html">metaparameters</a>.
}</code></pre>


#### name {#resources-attribute-name}

_(**Namevar:** If omitted, this attribute's value defaults to the resource's title.)_

The name of the type to be managed.

([↑ Back to resources attributes](#resources-attributes))


#### purge {#resources-attribute-purge}

Whether to purge unmanaged resources.  When set to `true`, this will
delete any resource that is not specified in your configuration and is not
autorequired by any managed resources. **Note:** The `ssh_authorized_key`
resource type can't be purged this way; instead, see the `purge_ssh_keys`
attribute of the `user` type.

Valid values are `true`, `false`, `yes`, `no`.

([↑ Back to resources attributes](#resources-attributes))


#### unless_system_user {#resources-attribute-unless_system_user}

This keeps system users from being purged.  By default, it
does not purge users whose UIDs are less than the minimum UID for the system (typically 500 or 1000), but you can specify
a different UID as the inclusive limit.

Valid values are `true`, `false`. Values can match `/^\d+$/`.

([↑ Back to resources attributes](#resources-attributes))


#### unless_uid {#resources-attribute-unless_uid}

This keeps specific uids or ranges of uids from being purged when purge is true.
Accepts integers, integer strings, and arrays of integers or integer strings.
To specify a range of uids, consider using the range() function from stdlib.

([↑ Back to resources attributes](#resources-attributes))





---------

## schedule

* [Attributes](#schedule-attributes)

### Description {#schedule-description}

Define schedules for Puppet. Resources can be limited to a schedule by using the
[`schedule`](https://puppet.com/docs/puppet/latest/metaparameter.html#schedule)
metaparameter.

Currently, **schedules can only be used to stop a resource from being
applied;** they cannot cause a resource to be applied when it otherwise
wouldn't be, and they cannot accurately specify a time when a resource
should run.

Every time Puppet applies its configuration, it will apply the
set of resources whose schedule does not eliminate them from
running right then, but there is currently no system in place to
guarantee that a given resource runs at a given time.  If you
specify a very  restrictive schedule and Puppet happens to run at a
time within that schedule, then the resources will get applied;
otherwise, that work may never get done.

Thus, it is advisable to use wider scheduling (for example, over a couple
of hours) combined with periods and repetitions.  For instance, if you
wanted to restrict certain resources to only running once, between
the hours of two and 4 AM, then you would use this schedule:

    schedule { 'maint':
      range  => '2 - 4',
      period => daily,
      repeat => 1,
    }

With this schedule, the first time that Puppet runs between 2 and 4 AM,
all resources with this schedule will get applied, but they won't
get applied again between 2 and 4 because they will have already
run once that day, and they won't get applied outside that schedule
because they will be outside the scheduled range.

Puppet automatically creates a schedule for each of the valid periods
with the same name as that period (such as hourly and daily).
Additionally, a schedule named `puppet` is created and used as the
default, with the following attributes:

    schedule { 'puppet':
      period => hourly,
      repeat => 2,
    }

This will cause resources to be applied every 30 minutes by default.

The `statettl` setting on the agent affects the ability of a schedule to
determine if a resource has already been checked. If the `statettl` is
set lower than the span of the associated schedule resource, then a
resource could be checked & applied multiple times in the schedule as
the information about when the resource was last checked will have
expired from the cache.

### Attributes {#schedule-attributes}

<pre><code>schedule { 'resource title':
  <a href="#schedule-attribute-name">name</a>        =&gt; <em># <strong>(namevar)</strong> The name of the schedule.  This name is used...</em>
  <a href="#schedule-attribute-period">period</a>      =&gt; <em># The period of repetition for resources on this...</em>
  <a href="#schedule-attribute-periodmatch">periodmatch</a> =&gt; <em># Whether periods should be matched by a numeric...</em>
  <a href="#schedule-attribute-range">range</a>       =&gt; <em># The earliest and latest that a resource can be...</em>
  <a href="#schedule-attribute-repeat">repeat</a>      =&gt; <em># How often a given resource may be applied in...</em>
  <a href="#schedule-attribute-weekday">weekday</a>     =&gt; <em># The days of the week in which the schedule...</em>
  # ...plus any applicable <a href="https://puppet.com/docs/puppet/latest/metaparameter.html">metaparameters</a>.
}</code></pre>


#### name {#schedule-attribute-name}

_(**Namevar:** If omitted, this attribute's value defaults to the resource's title.)_

The name of the schedule.  This name is used when assigning the schedule
to a resource with the `schedule` metaparameter:

    schedule { 'everyday':
      period => daily,
      range  => '2 - 4',
    }

    exec { '/usr/bin/apt-get update':
      schedule => 'everyday',
    }

([↑ Back to schedule attributes](#schedule-attributes))


#### period {#schedule-attribute-period}

The period of repetition for resources on this schedule. The default is
for resources to get applied every time Puppet runs.

Note that the period defines how often a given resource will get
applied but not when; if you would like to restrict the hours
that a given resource can be applied (for instance, only at night
during a maintenance window), then use the `range` attribute.

If the provided periods are not sufficient, you can provide a
value to the *repeat* attribute, which will cause Puppet to
schedule the affected resources evenly in the period the
specified number of times.  Take this schedule:

    schedule { 'veryoften':
      period => hourly,
      repeat => 6,
    }

This can cause Puppet to apply that resource up to every 10 minutes.

At the moment, Puppet cannot guarantee that level of repetition; that
is, the resource can applied _up to_ every 10 minutes, but internal
factors might prevent it from actually running that often (for instance,
if a Puppet run is still in progress when the next run is scheduled to
start, that next run will be suppressed).

See the `periodmatch` attribute for tuning whether to match
times by their distance apart or by their specific value.

> **Tip**: You can use `period => never,` to prevent a resource from being applied
in the given `range`. This is useful if you need to create a blackout window to
perform sensitive operations without interruption.

Valid values are `hourly`, `daily`, `weekly`, `monthly`, `never`.

([↑ Back to schedule attributes](#schedule-attributes))


#### periodmatch {#schedule-attribute-periodmatch}

Whether periods should be matched by a numeric value (for instance,
whether two times are in the same hour) or by their chronological
distance apart (whether two times are 60 minutes apart).

Valid values are `number`, `distance`.

([↑ Back to schedule attributes](#schedule-attributes))


#### range {#schedule-attribute-range}

The earliest and latest that a resource can be applied.  This is
always a hyphen-separated range within a 24 hour period, and hours
must be specified in numbers between 0 and 23, inclusive.  Minutes and
seconds can optionally be provided, using the normal colon as a
separator. For instance:

    schedule { 'maintenance':
      range => '1:30 - 4:30',
    }

This is mostly useful for restricting certain resources to being
applied in maintenance windows or during off-peak hours. Multiple
ranges can be applied in array context. As a convenience when specifying
ranges, you can cross midnight (for example, `range => "22:00 - 04:00"`).

([↑ Back to schedule attributes](#schedule-attributes))


#### repeat {#schedule-attribute-repeat}

How often a given resource may be applied in this schedule's `period`.
Must be an integer.

([↑ Back to schedule attributes](#schedule-attributes))


#### weekday {#schedule-attribute-weekday}

The days of the week in which the schedule should be valid.
You may specify the full day name 'Tuesday', the three character
abbreviation 'Tue', or a number (as a string or as an integer) corresponding to the day of the
week where 0 is Sunday, 1 is Monday, and so on. Multiple days can be specified
as an array. If not specified, the day of the week will not be
considered in the schedule.

If you are also using a range match that spans across midnight
then this parameter will match the day that it was at the start
of the range, not necessarily the day that it is when it matches.
For example, consider this schedule:

    schedule { 'maintenance_window':
      range   => '22:00 - 04:00',
      weekday => 'Saturday',
    }

This will match at 11 PM on Saturday and 2 AM on Sunday, but not
at 2 AM on Saturday.

([↑ Back to schedule attributes](#schedule-attributes))





---------

## service

* [Attributes](#service-attributes)
* [Providers](#service-providers)
* [Provider Features](#service-provider-features)

### Description {#service-description}

Manage running services.  Service support unfortunately varies
widely by platform --- some platforms have very little if any concept of a
running service, and some have a very codified and powerful concept.
Puppet's service support is usually capable of doing the right thing, but
the more information you can provide, the better behaviour you will get.

Puppet 2.7 and newer expect init scripts to have a working status command.
If this isn't the case for any of your services' init scripts, you will
need to set `hasstatus` to false and possibly specify a custom status
command in the `status` attribute. As a last resort, Puppet will attempt to
search the process table by calling whatever command is listed in the `ps`
fact. The default search pattern is the name of the service, but you can
specify it with the `pattern` attribute.

**Refresh:** `service` resources can respond to refresh events (via
`notify`, `subscribe`, or the `~>` arrow). If a `service` receives an
event from another resource, Puppet will restart the service it manages.
The actual command used to restart the service depends on the platform and
can be configured:

* If you set `hasrestart` to true, Puppet will use the init script's restart command.
* You can provide an explicit command for restarting with the `restart` attribute.
* If you do neither, the service's stop and start commands will be used.

### Attributes {#service-attributes}

<pre><code>service { 'resource title':
  <a href="#service-attribute-name">name</a>          =&gt; <em># <strong>(namevar)</strong> The name of the service to run.  This name is...</em>
  <a href="#service-attribute-ensure">ensure</a>        =&gt; <em># Whether a service should be running. Default...</em>
  <a href="#service-attribute-binary">binary</a>        =&gt; <em># The path to the daemon.  This is only used for...</em>
  <a href="#service-attribute-control">control</a>       =&gt; <em># The control variable used to manage services...</em>
  <a href="#service-attribute-enable">enable</a>        =&gt; <em># Whether a service should be enabled to start at...</em>
  <a href="#service-attribute-flags">flags</a>         =&gt; <em># Specify a string of flags to pass to the startup </em>
  <a href="#service-attribute-hasrestart">hasrestart</a>    =&gt; <em># Specify that an init script has a `restart...</em>
  <a href="#service-attribute-hasstatus">hasstatus</a>     =&gt; <em># Declare whether the service's init script has a...</em>
  <a href="#service-attribute-logonaccount">logonaccount</a>  =&gt; <em># Specify an account for service logon    Requires </em>
  <a href="#service-attribute-logonpassword">logonpassword</a> =&gt; <em># Specify a password for service logon. Default...</em>
  <a href="#service-attribute-manifest">manifest</a>      =&gt; <em># Specify a command to config a service, or a path </em>
  <a href="#service-attribute-path">path</a>          =&gt; <em># The search path for finding init scripts....</em>
  <a href="#service-attribute-pattern">pattern</a>       =&gt; <em># The pattern to search for in the process table...</em>
  <a href="#service-attribute-provider">provider</a>      =&gt; <em># The specific backend to use for this `service...</em>
  <a href="#service-attribute-restart">restart</a>       =&gt; <em># Specify a *restart* command manually.  If left...</em>
  <a href="#service-attribute-start">start</a>         =&gt; <em># Specify a *start* command manually.  Most...</em>
  <a href="#service-attribute-status">status</a>        =&gt; <em># Specify a *status* command manually.  This...</em>
  <a href="#service-attribute-stop">stop</a>          =&gt; <em># Specify a *stop* command...</em>
  <a href="#service-attribute-timeout">timeout</a>       =&gt; <em># Specify an optional minimum timeout (in seconds) </em>
  # ...plus any applicable <a href="https://puppet.com/docs/puppet/latest/metaparameter.html">metaparameters</a>.
}</code></pre>


#### name {#service-attribute-name}

_(**Namevar:** If omitted, this attribute's value defaults to the resource's title.)_

The name of the service to run.

This name is used to find the service; on platforms where services
have short system names and long display names, this should be the
short name. (To take an example from Windows, you would use "wuauserv"
rather than "Automatic Updates.")

([↑ Back to service attributes](#service-attributes))


#### ensure {#service-attribute-ensure}

_(**Property:** This attribute represents concrete state on the target system.)_

Whether a service should be running. Default values depend on the platform.

Valid values are `stopped` (also called `false`), `running` (also called `true`).

([↑ Back to service attributes](#service-attributes))


#### binary {#service-attribute-binary}

The path to the daemon.  This is only used for
systems that do not support init scripts.  This binary will be
used to start the service if no `start` parameter is
provided.

([↑ Back to service attributes](#service-attributes))


#### control {#service-attribute-control}

The control variable used to manage services (originally for HP-UX).
Defaults to the upcased service name plus `START` replacing dots with
underscores, for those providers that support the `controllable` feature.

([↑ Back to service attributes](#service-attributes))


#### enable {#service-attribute-enable}

_(**Property:** This attribute represents concrete state on the target system.)_

Whether a service should be enabled to start at boot.
This property behaves differently depending on the platform;
wherever possible, it relies on local tools to enable or disable
a given service. Default values depend on the platform.

If you don't specify a value for the `enable` attribute, Puppet leaves
that aspect of the service alone and your operating system determines
the behavior.

Valid values are `true`, `false`, `manual`, `mask`, `delayed`.

Requires features enableable.

([↑ Back to service attributes](#service-attributes))


#### flags {#service-attribute-flags}

_(**Property:** This attribute represents concrete state on the target system.)_

Specify a string of flags to pass to the startup script.



Requires features flaggable.

([↑ Back to service attributes](#service-attributes))


#### hasrestart {#service-attribute-hasrestart}

Specify that an init script has a `restart` command.  If this is
false and you do not specify a command in the `restart` attribute,
the init script's `stop` and `start` commands will be used.

Valid values are `true`, `false`.

([↑ Back to service attributes](#service-attributes))


#### hasstatus {#service-attribute-hasstatus}

Declare whether the service's init script has a functional status
command. This attribute's default value changed in Puppet 2.7.0.

The init script's status command must return 0 if the service is
running and a nonzero value otherwise. Ideally, these exit codes
should conform to [the LSB's specification][lsb-exit-codes] for init
script status actions, but Puppet only considers the difference
between 0 and nonzero to be relevant.

If a service's init script does not support any kind of status command,
you should set `hasstatus` to false and either provide a specific
command using the `status` attribute or expect that Puppet will look for
the service name in the process table. Be aware that 'virtual' init
scripts (like 'network' under Red Hat systems) will respond poorly to
refresh events from other resources if you override the default behavior
without providing a status command.

Valid values are `true`, `false`.

([↑ Back to service attributes](#service-attributes))


#### logonaccount {#service-attribute-logonaccount}

_(**Property:** This attribute represents concrete state on the target system.)_

Specify an account for service logon



Requires features manages_logon_credentials.

([↑ Back to service attributes](#service-attributes))


#### logonpassword {#service-attribute-logonpassword}

Specify a password for service logon. Default value is an empty string (when logonaccount is specified).



Requires features manages_logon_credentials.

([↑ Back to service attributes](#service-attributes))


#### manifest {#service-attribute-manifest}

Specify a command to config a service, or a path to a manifest to do so.

([↑ Back to service attributes](#service-attributes))


#### path {#service-attribute-path}

The search path for finding init scripts.  Multiple values should
be separated by colons or provided as an array.

([↑ Back to service attributes](#service-attributes))


#### pattern {#service-attribute-pattern}

The pattern to search for in the process table.
This is used for stopping services on platforms that do not
support init scripts, and is also used for determining service
status on those service whose init scripts do not include a status
command.

Defaults to the name of the service. The pattern can be a simple string
or any legal Ruby pattern, including regular expressions (which should
be quoted without enclosing slashes).

([↑ Back to service attributes](#service-attributes))


#### provider {#service-attribute-provider}

The specific backend to use for this `service`
resource. You will seldom need to specify this --- Puppet will usually
discover the appropriate provider for your platform.

Available providers are:

* [`base`](#service-provider-base)
* [`bsd`](#service-provider-bsd)
* [`daemontools`](#service-provider-daemontools)
* [`debian`](#service-provider-debian)
* [`freebsd`](#service-provider-freebsd)
* [`gentoo`](#service-provider-gentoo)
* [`init`](#service-provider-init)
* [`launchd`](#service-provider-launchd)
* [`openbsd`](#service-provider-openbsd)
* [`openrc`](#service-provider-openrc)
* [`openwrt`](#service-provider-openwrt)
* [`rcng`](#service-provider-rcng)
* [`redhat`](#service-provider-redhat)
* [`runit`](#service-provider-runit)
* [`service`](#service-provider-service)
* [`smf`](#service-provider-smf)
* [`src`](#service-provider-src)
* [`systemd`](#service-provider-systemd)
* [`upstart`](#service-provider-upstart)
* [`windows`](#service-provider-windows)

([↑ Back to service attributes](#service-attributes))


#### restart {#service-attribute-restart}

Specify a *restart* command manually.  If left
unspecified, the service will be stopped and then started.

([↑ Back to service attributes](#service-attributes))


#### start {#service-attribute-start}

Specify a *start* command manually.  Most service subsystems
support a `start` command, so this will not need to be
specified.

([↑ Back to service attributes](#service-attributes))


#### status {#service-attribute-status}

Specify a *status* command manually.  This command must
return 0 if the service is running and a nonzero value otherwise.
Ideally, these exit codes should conform to [the LSB's
specification][lsb-exit-codes] for init script status actions, but
Puppet only considers the difference between 0 and nonzero to be
relevant.

If left unspecified, the status of the service will be determined
automatically, usually by looking for the service in the process
table.

[lsb-exit-codes]: http://refspecs.linuxfoundation.org/LSB_4.1.0/LSB-Core-generic/LSB-Core-generic/iniscrptact.html

([↑ Back to service attributes](#service-attributes))


#### stop {#service-attribute-stop}

Specify a *stop* command manually.

([↑ Back to service attributes](#service-attributes))


#### timeout {#service-attribute-timeout}

Specify an optional minimum timeout (in seconds) for puppet to wait when syncing service properties



Requires features configurable_timeout.

([↑ Back to service attributes](#service-attributes))


### Providers {#service-providers}

#### base {#service-provider-base}

The simplest form of Unix service support.

You have to specify enough about your service for this to work; the
minimum you can specify is a binary for starting the process, and this
same binary will be searched for in the process table to stop the
service.  As with `init`-style services, it is preferable to specify start,
stop, and status commands.

* Required binaries: `kill`.
* Supported features: `refreshable`.

#### bsd {#service-provider-bsd}

Generic BSD form of `init`-style service management with `rc.d`.

Uses `rc.conf.d` for service enabling and disabling.

* Supported features: `enableable`, `refreshable`.

#### daemontools {#service-provider-daemontools}

Daemontools service management.

This provider manages daemons supervised by D.J. Bernstein daemontools.
When detecting the service directory it will check, in order of preference:

* `/service`
* `/etc/service`
* `/var/lib/svscan`

The daemon directory should be in one of the following locations:

* `/var/lib/service`
* `/etc`

...or this can be overridden in the resource's attributes:

    service { 'myservice':
      provider => 'daemontools',
      path     => '/path/to/daemons',
    }

This provider supports out of the box:

* start/stop (mapped to enable/disable)
* enable/disable
* restart
* status

If a service has `ensure => "running"`, it will link /path/to/daemon to
/path/to/service, which will automatically enable the service.

If a service has `ensure => "stopped"`, it will only shut down the service, not
remove the `/path/to/service` link.

* Required binaries: `/usr/bin/svc`, `/usr/bin/svstat`.
* Supported features: `enableable`, `refreshable`.

#### debian {#service-provider-debian}

Debian's form of `init`-style management.

The only differences from `init` are support for enabling and disabling
services via `update-rc.d` and the ability to determine enabled status via
`invoke-rc.d`.

* Required binaries: `/usr/sbin/invoke-rc.d`, `/usr/sbin/service`, `/usr/sbin/update-rc.d`.
* Default for `os.name` == `cumuluslinux` and `os.release.major` == `1, 2`. Default for `os.name` == `debian` and `os.release.major` == `5, 6, 7`. Default for `os.name` == `devuan`.
* Supported features: `enableable`, `refreshable`.

#### freebsd {#service-provider-freebsd}

Provider for FreeBSD and DragonFly BSD. Uses the `rcvar` argument of init scripts and parses/edits rc files.

* Default for `os.name` == `freebsd, dragonfly`.
* Supported features: `enableable`, `refreshable`.

#### gentoo {#service-provider-gentoo}

Gentoo's form of `init`-style service management.

Uses `rc-update` for service enabling and disabling.

* Required binaries: `/sbin/rc-update`.
* Supported features: `enableable`, `refreshable`.

#### init {#service-provider-init}

Standard `init`-style service management.

* Supported features: `refreshable`.

#### launchd {#service-provider-launchd}

This provider manages jobs with `launchd`, which is the default service
framework for Mac OS X (and may be available for use on other platforms).

For more information, see the `launchd` man page:

* <https://developer.apple.com/legacy/library/documentation/Darwin/Reference/ManPages/man8/launchd.8.html>

This provider reads plists out of the following directories:

* `/System/Library/LaunchDaemons`
* `/System/Library/LaunchAgents`
* `/Library/LaunchDaemons`
* `/Library/LaunchAgents`

...and builds up a list of services based upon each plist's "Label" entry.

This provider supports:

* ensure => running/stopped,
* enable => true/false
* status
* restart

Here is how the Puppet states correspond to `launchd` states:

* stopped --- job unloaded
* started --- job loaded
* enabled --- 'Disable' removed from job plist file
* disabled --- 'Disable' added to job plist file

Note that this allows you to do something `launchctl` can't do, which is to
be in a state of "stopped/enabled" or "running/disabled".

Note that this provider does not support overriding 'restart'

* Required binaries: `/bin/launchctl`.
* Default for `os.name` == `darwin`.
* Supported features: `enableable`, `refreshable`.

#### openbsd {#service-provider-openbsd}

Provider for OpenBSD's rc.d daemon control scripts

* Required binaries: `/usr/sbin/rcctl`.
* Default for `os.name` == `openbsd`.
* Supported features: `enableable`, `flaggable`, `refreshable`.

#### openrc {#service-provider-openrc}

Support for Gentoo's OpenRC initskripts

Uses rc-update, rc-status and rc-service to manage services.

* Required binaries: `/bin/rc-status`, `/sbin/rc-service`, `/sbin/rc-update`.
* Default for `os.name` == `gentoo`. Default for `os.name` == `funtoo`.
* Supported features: `enableable`, `refreshable`.

#### openwrt {#service-provider-openwrt}

Support for OpenWrt flavored init scripts.

Uses /etc/init.d/service_name enable, disable, and enabled.

* Default for `os.name` == `openwrt`.
* Supported features: `enableable`, `refreshable`.

#### rcng {#service-provider-rcng}

RCng service management with rc.d

* Default for `os.name` == `netbsd, cargos`.
* Supported features: `enableable`, `refreshable`.

#### redhat {#service-provider-redhat}

Red Hat's (and probably many others') form of `init`-style service
management. Uses `chkconfig` for service enabling and disabling.

* Required binaries: `/sbin/chkconfig`, `/sbin/service`.
* Default for `os.name` == `amazon` and `os.release.major` == `2017, 2018`. Default for `os.name` == `redhat` and `os.release.major` == `4, 5, 6`. Default for `os.family` == `suse` and `os.release.major` == `10, 11`.
* Supported features: `enableable`, `refreshable`.

#### runit {#service-provider-runit}

Runit service management.

This provider manages daemons running supervised by Runit.
When detecting the service directory it will check, in order of preference:

* `/service`
* `/etc/service`
* `/var/service`

The daemon directory should be in one of the following locations:

* `/etc/sv`
* `/var/lib/service`

or this can be overridden in the service resource parameters:

    service { 'myservice':
      provider => 'runit',
      path     => '/path/to/daemons',
    }

This provider supports out of the box:

* start/stop
* enable/disable
* restart
* status

* Required binaries: `/usr/bin/sv`.
* Supported features: `enableable`, `refreshable`.

#### service {#service-provider-service}

The simplest form of service support.

* Supported features: `refreshable`.

#### smf {#service-provider-smf}

Support for Sun's new Service Management Framework.

When managing the enable property, this provider will try to preserve
the previous ensure state per the enableable semantics. On Solaris,
enabling a service starts it up while disabling a service stops it. Thus,
there's a chance for this provider to execute two operations when managing
the enable property. For example, if enable is set to true and the ensure
state is stopped, this provider will manage the service using two operations:
one to enable the service which will start it up, and another to stop the
service (without affecting its enabled status).

By specifying `manifest => "/path/to/service.xml"`, the SMF manifest will
be imported if it does not exist.

* Required binaries: `/usr/bin/svcs`, `/usr/sbin/svcadm`, `/usr/sbin/svccfg`.
* Default for `os.family` == `solaris`.
* Supported features: `enableable`, `refreshable`.

#### src {#service-provider-src}

Support for AIX's System Resource controller.

Services are started/stopped based on the `stopsrc` and `startsrc`
commands, and some services can be refreshed with `refresh` command.

Enabling and disabling services is not supported, as it requires
modifications to `/etc/inittab`. Starting and stopping groups of subsystems
is not yet supported.

* Required binaries: `/usr/bin/lssrc`, `/usr/bin/refresh`, `/usr/bin/startsrc`, `/usr/bin/stopsrc`, `/usr/sbin/chitab`, `/usr/sbin/lsitab`, `/usr/sbin/mkitab`, `/usr/sbin/rmitab`.
* Default for `os.name` == `aix`.
* Supported features: `enableable`, `refreshable`.

#### systemd {#service-provider-systemd}

Manages `systemd` services using `systemctl`.

Because `systemd` defaults to assuming the `.service` unit type, the suffix
may be omitted.  Other unit types (such as `.path`) may be managed by
providing the proper suffix.

* Required binaries: `systemctl`.
* Default for `os.family` == `archlinux`. Default for `os.family` == `redhat`. Default for `os.family` == `redhat` and `os.name` == `fedora`. Default for `os.family` == `suse`. Default for `os.family` == `coreos`. Default for `os.family` == `gentoo`. Default for `os.name` == `amazon` and `os.release.major` == `2, 2023`. Default for `os.name` == `debian`. Default for `os.name` == `LinuxMint`. Default for `os.name` == `ubuntu`. Default for `os.name` == `cumuluslinux` and `os.release.major` == `3, 4`. Default for `os.name` == `raspbian` and `os.release.major` == `12`.
* Supported features: `enableable`, `maskable`, `refreshable`.

#### upstart {#service-provider-upstart}

Ubuntu service management with `upstart`.

This provider manages `upstart` jobs on Ubuntu. For `upstart` documentation,
see <http://upstart.ubuntu.com/>.

* Required binaries: `/sbin/initctl`, `/sbin/restart`, `/sbin/start`, `/sbin/status`, `/sbin/stop`.
* Default for `os.name` == `ubuntu` and `os.release.major` == `10.04, 12.04, 14.04, 14.10`. Default for `os.name` == `LinuxMint` and `os.release.major` == `10, 11, 12, 13, 14, 15, 16, 17`.
* Supported features: `enableable`, `refreshable`.

#### windows {#service-provider-windows}

Support for Windows Service Control Manager (SCM). This provider can
start, stop, enable, and disable services, and the SCM provides working
status methods for all services.

Control of service groups (dependencies) is not yet supported, nor is running
services as a specific user.

* Default for `os.name` == `windows`.
* Supported features: `configurable_timeout`, `delayed_startable`, `enableable`, `manages_logon_credentials`, `manual_startable`, `refreshable`.

### Provider Features {#service-provider-features}

Available features:

* `configurable_timeout` --- The provider can specify a minumum timeout for syncing service properties
* `controllable` --- The provider uses a control variable.
* `delayed_startable` --- The provider can set service to delayed start
* `enableable` --- The provider can enable and disable the service.
* `flaggable` --- The provider can pass flags to the service.
* `manages_logon_credentials` --- The provider can specify the logon credentials used for a service
* `manual_startable` --- The provider can set service to manual start
* `maskable` --- The provider can 'mask' the service.
* `refreshable` --- The provider can restart the service.

Provider support:

* **base** - _refreshable_
* **bsd** - _enableable, refreshable_
* **daemontools** - _enableable, refreshable_
* **debian** - _enableable, refreshable_
* **freebsd** - _enableable, refreshable_
* **gentoo** - _enableable, refreshable_
* **init** - _refreshable_
* **launchd** - _enableable, refreshable_
* **openbsd** - _enableable, flaggable, refreshable_
* **openrc** - _enableable, refreshable_
* **openwrt** - _enableable, refreshable_
* **rcng** - _enableable, refreshable_
* **redhat** - _enableable, refreshable_
* **runit** - _enableable, refreshable_
* **service** - _refreshable_
* **smf** - _enableable, refreshable_
* **src** - _enableable, refreshable_
* **systemd** - _enableable, maskable, refreshable_
* **upstart** - _enableable, refreshable_
* **windows** - _configurable timeout, delayed startable, enableable, manages logon credentials, manual startable, refreshable_
  




---------

## stage

* [Attributes](#stage-attributes)

### Description {#stage-description}

A resource type for creating new run stages.  Once a stage is available,
classes can be assigned to it by declaring them with the resource-like syntax
and using
[the `stage` metaparameter](https://puppet.com/docs/puppet/latest/metaparameter.html#stage).

Note that new stages are not useful unless you also declare their order
in relation to the default `main` stage.

A complete run stage example:

    stage { 'pre':
      before => Stage['main'],
    }

    class { 'apt-updates':
      stage => 'pre',
    }

Individual resources cannot be assigned to run stages; you can only set stages
for classes.

### Attributes {#stage-attributes}

<pre><code>stage { 'resource title':
  <a href="#stage-attribute-name">name</a> =&gt; <em># <strong>(namevar)</strong> The name of the stage. Use this as the value for </em>
  # ...plus any applicable <a href="https://puppet.com/docs/puppet/latest/metaparameter.html">metaparameters</a>.
}</code></pre>


#### name {#stage-attribute-name}

_(**Namevar:** If omitted, this attribute's value defaults to the resource's title.)_

The name of the stage. Use this as the value for the `stage` metaparameter
when assigning classes to this stage.

([↑ Back to stage attributes](#stage-attributes))





---------

## tidy

* [Attributes](#tidy-attributes)

### Description {#tidy-description}

Remove unwanted files based on specific criteria.  Multiple
criteria are OR'd together, so a file that is too large but is not
old enough will still get tidied. Ignores managed resources.

If you don't specify either `age` or `size`, then all files will
be removed.

This resource type works by generating a file resource for every file
that should be deleted and then letting that resource perform the
actual deletion.

### Attributes {#tidy-attributes}

<pre><code>tidy { 'resource title':
  <a href="#tidy-attribute-path">path</a>      =&gt; <em># <strong>(namevar)</strong> The path to the file or directory to manage....</em>
  <a href="#tidy-attribute-age">age</a>       =&gt; <em># Tidy files whose age is equal to or greater than </em>
  <a href="#tidy-attribute-backup">backup</a>    =&gt; <em># Whether tidied files should be backed up.  Any...</em>
  <a href="#tidy-attribute-matches">matches</a>   =&gt; <em># One or more (shell type) file glob patterns...</em>
  <a href="#tidy-attribute-max_files">max_files</a> =&gt; <em># In case the resource is a directory and the...</em>
  <a href="#tidy-attribute-recurse">recurse</a>   =&gt; <em># If target is a directory, recursively descend...</em>
  <a href="#tidy-attribute-rmdirs">rmdirs</a>    =&gt; <em># Tidy directories in addition to files; that is...</em>
  <a href="#tidy-attribute-size">size</a>      =&gt; <em># Tidy files whose size is equal to or greater...</em>
  <a href="#tidy-attribute-type">type</a>      =&gt; <em># Set the mechanism for determining age.  Valid...</em>
  # ...plus any applicable <a href="https://puppet.com/docs/puppet/latest/metaparameter.html">metaparameters</a>.
}</code></pre>


#### path {#tidy-attribute-path}

_(**Namevar:** If omitted, this attribute's value defaults to the resource's title.)_

The path to the file or directory to manage.  Must be fully
qualified.

([↑ Back to tidy attributes](#tidy-attributes))


#### age {#tidy-attribute-age}

Tidy files whose age is equal to or greater than
the specified time.  You can choose seconds, minutes,
hours, days, or weeks by specifying the first letter of any
of those words (for example, '1w' represents one week).

Specifying 0 will remove all files.

([↑ Back to tidy attributes](#tidy-attributes))


#### backup {#tidy-attribute-backup}

Whether tidied files should be backed up.  Any values are passed
directly to the file resources used for actual file deletion, so consult
the `file` type's backup documentation to determine valid values.

([↑ Back to tidy attributes](#tidy-attributes))


#### matches {#tidy-attribute-matches}

One or more (shell type) file glob patterns, which restrict
the list of files to be tidied to those whose basenames match
at least one of the patterns specified. Multiple patterns can
be specified using an array.

Example:

    tidy { '/tmp':
      age     => '1w',
      recurse => 1,
      matches => [ '[0-9]pub*.tmp', '*.temp', 'tmpfile?' ],
    }

This removes files from `/tmp` if they are one week old or older,
are not in a subdirectory and match one of the shell globs given.

Note that the patterns are matched against the basename of each
file -- that is, your glob patterns should not have any '/'
characters in them, since you are only specifying against the last
bit of the file.

Finally, note that you must now specify a non-zero/non-false value
for recurse if matches is used, as matches only apply to files found
by recursion (there's no reason to use static patterns match against
a statically determined path).  Requiring explicit recursion clears
up a common source of confusion.

([↑ Back to tidy attributes](#tidy-attributes))


#### max_files {#tidy-attribute-max_files}

In case the resource is a directory and the recursion is enabled, puppet will
generate a new resource for each file file found, possible leading to
an excessive number of resources generated without any control.

Setting `max_files` will check the number of file resources that
will eventually be created and will raise a resource argument error if the
limit will be exceeded.

Use value `0` to disable the check. In this case, a warning is logged if
the number of files exceeds 1000.

Values can match `/^[0-9]+$/`.

([↑ Back to tidy attributes](#tidy-attributes))


#### recurse {#tidy-attribute-recurse}

If target is a directory, recursively descend
into the directory looking for files to tidy. Numeric values
specify a limit for the recursion depth, `true` means
unrestricted recursion.

Valid values are `true`, `false`, `inf`. Values can match `/^[0-9]+$/`.

([↑ Back to tidy attributes](#tidy-attributes))


#### rmdirs {#tidy-attribute-rmdirs}

Tidy directories in addition to files; that is, remove
directories whose age is older than the specified criteria.
This will only remove empty directories, so all contained
files must also be tidied before a directory gets removed.

Valid values are `true`, `false`, `yes`, `no`.

([↑ Back to tidy attributes](#tidy-attributes))


#### size {#tidy-attribute-size}

Tidy files whose size is equal to or greater than
the specified size.  Unqualified values are in kilobytes, but
*b*, *k*, *m*, *g*, and *t* can be appended to specify *bytes*,
*kilobytes*, *megabytes*, *gigabytes*, and *terabytes*, respectively.
Only the first character is significant, so the full word can also
be used.

([↑ Back to tidy attributes](#tidy-attributes))


#### type {#tidy-attribute-type}

Set the mechanism for determining age.

Valid values are `atime`, `mtime`, `ctime`.

([↑ Back to tidy attributes](#tidy-attributes))





---------

## user

* [Attributes](#user-attributes)
* [Providers](#user-providers)
* [Provider Features](#user-provider-features)

### Description {#user-description}

Manage users.  This type is mostly built to manage system
users, so it is lacking some features useful for managing normal
users.

This resource type uses the prescribed native tools for creating
groups and generally uses POSIX APIs for retrieving information
about them.  It does not directly modify `/etc/passwd` or anything.

**Autorequires:** If Puppet is managing the user's primary group (as
provided in the `gid` attribute) or any group listed in the `groups`
attribute then the user resource will autorequire that group. If Puppet
is managing any role accounts corresponding to the user's roles, the
user resource will autorequire those role accounts.

### Attributes {#user-attributes}

<pre><code>user { 'resource title':
  <a href="#user-attribute-name">name</a>                 =&gt; <em># <strong>(namevar)</strong> The user name. While naming limitations vary by...</em>
  <a href="#user-attribute-ensure">ensure</a>               =&gt; <em># The basic state that the object should be in....</em>
  <a href="#user-attribute-allowdupe">allowdupe</a>            =&gt; <em># Whether to allow duplicate UIDs.  Valid values...</em>
  <a href="#user-attribute-attribute_membership">attribute_membership</a> =&gt; <em># Whether specified attribute value pairs should...</em>
  <a href="#user-attribute-attributes">attributes</a>           =&gt; <em># Specify AIX attributes for the user in an array...</em>
  <a href="#user-attribute-auth_membership">auth_membership</a>      =&gt; <em># Whether specified auths should be considered the </em>
  <a href="#user-attribute-auths">auths</a>                =&gt; <em># The auths the user has.  Multiple auths should...</em>
  <a href="#user-attribute-comment">comment</a>              =&gt; <em># A description of the user.  Generally the user's </em>
  <a href="#user-attribute-expiry">expiry</a>               =&gt; <em># The expiry date for this user. Provide as either </em>
  <a href="#user-attribute-forcelocal">forcelocal</a>           =&gt; <em># Forces the management of local accounts when...</em>
  <a href="#user-attribute-gid">gid</a>                  =&gt; <em># The user's primary group.  Can be specified...</em>
  <a href="#user-attribute-groups">groups</a>               =&gt; <em># The groups to which the user belongs.  The...</em>
  <a href="#user-attribute-home">home</a>                 =&gt; <em># The home directory of the user.  The directory...</em>
  <a href="#user-attribute-ia_load_module">ia_load_module</a>       =&gt; <em># The name of the I&A module to use to manage this </em>
  <a href="#user-attribute-iterations">iterations</a>           =&gt; <em># This is the number of iterations of a chained...</em>
  <a href="#user-attribute-key_membership">key_membership</a>       =&gt; <em># Whether specified key/value pairs should be...</em>
  <a href="#user-attribute-keys">keys</a>                 =&gt; <em># Specify user attributes in an array of key ...</em>
  <a href="#user-attribute-loginclass">loginclass</a>           =&gt; <em># The name of login class to which the user...</em>
  <a href="#user-attribute-managehome">managehome</a>           =&gt; <em># Whether to manage the home directory when Puppet </em>
  <a href="#user-attribute-membership">membership</a>           =&gt; <em># If `minimum` is specified, Puppet will ensure...</em>
  <a href="#user-attribute-password">password</a>             =&gt; <em># The user's password, in whatever encrypted...</em>
  <a href="#user-attribute-password_max_age">password_max_age</a>     =&gt; <em># The maximum number of days a password may be...</em>
  <a href="#user-attribute-password_min_age">password_min_age</a>     =&gt; <em># The minimum number of days a password must be...</em>
  <a href="#user-attribute-password_warn_days">password_warn_days</a>   =&gt; <em># The number of days before a password is going to </em>
  <a href="#user-attribute-profile_membership">profile_membership</a>   =&gt; <em># Whether specified roles should be treated as the </em>
  <a href="#user-attribute-profiles">profiles</a>             =&gt; <em># The profiles the user has.  Multiple profiles...</em>
  <a href="#user-attribute-project">project</a>              =&gt; <em># The name of the project associated with a user.  </em>
  <a href="#user-attribute-provider">provider</a>             =&gt; <em># The specific backend to use for this `user...</em>
  <a href="#user-attribute-purge_ssh_keys">purge_ssh_keys</a>       =&gt; <em># Whether to purge authorized SSH keys for this...</em>
  <a href="#user-attribute-role_membership">role_membership</a>      =&gt; <em># Whether specified roles should be considered the </em>
  <a href="#user-attribute-roles">roles</a>                =&gt; <em># The roles the user has.  Multiple roles should...</em>
  <a href="#user-attribute-salt">salt</a>                 =&gt; <em># This is the 32-byte salt used to generate the...</em>
  <a href="#user-attribute-shell">shell</a>                =&gt; <em># The user's login shell.  The shell must exist...</em>
  <a href="#user-attribute-system">system</a>               =&gt; <em># Whether the user is a system user, according to...</em>
  <a href="#user-attribute-uid">uid</a>                  =&gt; <em># The user ID; must be specified numerically. If...</em>
  # ...plus any applicable <a href="https://puppet.com/docs/puppet/latest/metaparameter.html">metaparameters</a>.
}</code></pre>


#### name {#user-attribute-name}

_(**Namevar:** If omitted, this attribute's value defaults to the resource's title.)_

The user name. While naming limitations vary by operating system,
it is advisable to restrict names to the lowest common denominator,
which is a maximum of 8 characters beginning with a letter.

Note that Puppet considers user names to be case-sensitive, regardless
of the platform's own rules; be sure to always use the same case when
referring to a given user.

([↑ Back to user attributes](#user-attributes))


#### ensure {#user-attribute-ensure}

_(**Property:** This attribute represents concrete state on the target system.)_

The basic state that the object should be in.

Valid values are `present`, `absent`, `role`.

([↑ Back to user attributes](#user-attributes))


#### allowdupe {#user-attribute-allowdupe}

Whether to allow duplicate UIDs.

Valid values are `true`, `false`, `yes`, `no`.

([↑ Back to user attributes](#user-attributes))


#### attribute_membership {#user-attribute-attribute_membership}

Whether specified attribute value pairs should be treated as the
**complete list** (`inclusive`) or the **minimum list** (`minimum`) of
attribute/value pairs for the user.

Valid values are `inclusive`, `minimum`.

([↑ Back to user attributes](#user-attributes))


#### attributes {#user-attribute-attributes}

_(**Property:** This attribute represents concrete state on the target system.)_

Specify AIX attributes for the user in an array or hash of attribute = value pairs.

 For example:

 ```
 ['minage=0', 'maxage=5', 'SYSTEM=compat']
 ```

 or

```
attributes => { 'minage' => '0', 'maxage' => '5', 'SYSTEM' => 'compat' }
```



Requires features manages_aix_lam.

([↑ Back to user attributes](#user-attributes))


#### auth_membership {#user-attribute-auth_membership}

Whether specified auths should be considered the **complete list**
(`inclusive`) or the **minimum list** (`minimum`) of auths the user
has. This setting is specific to managing Solaris authorizations.

Valid values are `inclusive`, `minimum`.

([↑ Back to user attributes](#user-attributes))


#### auths {#user-attribute-auths}

_(**Property:** This attribute represents concrete state on the target system.)_

The auths the user has.  Multiple auths should be
specified as an array.



Requires features manages_solaris_rbac.

([↑ Back to user attributes](#user-attributes))


#### comment {#user-attribute-comment}

_(**Property:** This attribute represents concrete state on the target system.)_

A description of the user.  Generally the user's full name.

([↑ Back to user attributes](#user-attributes))


#### expiry {#user-attribute-expiry}

_(**Property:** This attribute represents concrete state on the target system.)_

The expiry date for this user. Provide as either the special
value `absent` to ensure that the account never expires, or as
a zero-padded YYYY-MM-DD format -- for example, 2010-02-19.

Valid values are `absent`. Values can match `/^\d{4}-\d{2}-\d{2}$/`.

Requires features manages_expiry.

([↑ Back to user attributes](#user-attributes))


#### forcelocal {#user-attribute-forcelocal}

Forces the management of local accounts when accounts are also
being managed by some other Name Service Switch (NSS). For AIX, refer to the `ia_load_module` parameter.

This option relies on your operating system's implementation of `luser*` commands, such as `luseradd` , and `lgroupadd`, `lusermod`. The `forcelocal` option could behave unpredictably in some circumstances. If the tools it depends on are not available, it might have no effect at all.

Valid values are `true`, `false`, `yes`, `no`.

Requires features manages_local_users_and_groups.

([↑ Back to user attributes](#user-attributes))


#### gid {#user-attribute-gid}

_(**Property:** This attribute represents concrete state on the target system.)_

The user's primary group.  Can be specified numerically or by name.

This attribute is not supported on Windows systems; use the `groups`
attribute instead. (On Windows, designating a primary group is only
meaningful for domain accounts, which Puppet does not currently manage.)

([↑ Back to user attributes](#user-attributes))


#### groups {#user-attribute-groups}

_(**Property:** This attribute represents concrete state on the target system.)_

The groups to which the user belongs.  The primary group should
not be listed, and groups should be identified by name rather than by
GID.  Multiple groups should be specified as an array.

([↑ Back to user attributes](#user-attributes))


#### home {#user-attribute-home}

_(**Property:** This attribute represents concrete state on the target system.)_

The home directory of the user.  The directory must be created
separately and is not currently checked for existence.

([↑ Back to user attributes](#user-attributes))


#### ia_load_module {#user-attribute-ia_load_module}

The name of the I&A module to use to manage this user.
This should be set to `files` if managing local users.



Requires features manages_aix_lam.

([↑ Back to user attributes](#user-attributes))


#### iterations {#user-attribute-iterations}

_(**Property:** This attribute represents concrete state on the target system.)_

This is the number of iterations of a chained computation of the
[PBKDF2 password hash](https://en.wikipedia.org/wiki/PBKDF2). This parameter
is used in OS X, and is required for managing passwords on OS X 10.8 and
newer.



Requires features manages_password_salt.

([↑ Back to user attributes](#user-attributes))


#### key_membership {#user-attribute-key_membership}

Whether specified key/value pairs should be considered the
**complete list** (`inclusive`) or the **minimum list** (`minimum`) of
the user's attributes.

Valid values are `inclusive`, `minimum`.

([↑ Back to user attributes](#user-attributes))


#### keys {#user-attribute-keys}

_(**Property:** This attribute represents concrete state on the target system.)_

Specify user attributes in an array of key = value pairs.



Requires features manages_solaris_rbac.

([↑ Back to user attributes](#user-attributes))


#### loginclass {#user-attribute-loginclass}

_(**Property:** This attribute represents concrete state on the target system.)_

The name of login class to which the user belongs.



Requires features manages_loginclass.

([↑ Back to user attributes](#user-attributes))


#### managehome {#user-attribute-managehome}

Whether to manage the home directory when Puppet creates or removes the user.
This creates the home directory if Puppet also creates the user account, and deletes the
home directory if Puppet also removes the user account.

This parameter has no effect unless Puppet is also creating or removing the user in the
resource at the same time. For instance, Puppet creates a home directory for a managed
user if `ensure => present` and the user does not exist at the time of the Puppet run.
If the home directory is then deleted manually, Puppet will not recreate it on the next
run.

Note that on Windows, this manages creation/deletion of the user profile instead of the
home directory. The user profile is stored in the `C:\Users\<username>` directory.

Valid values are `true`, `false`, `yes`, `no`.

([↑ Back to user attributes](#user-attributes))


#### membership {#user-attribute-membership}

If `minimum` is specified, Puppet will ensure that the user is a
member of all specified groups, but will not remove any other groups
that the user is a part of.

If `inclusive` is specified, Puppet will ensure that the user is a
member of **only** specified groups.

Valid values are `inclusive`, `minimum`.

([↑ Back to user attributes](#user-attributes))


#### password {#user-attribute-password}

_(**Property:** This attribute represents concrete state on the target system.)_

The user's password, in whatever encrypted format the local system
requires. Consult your operating system's documentation for acceptable password
encryption formats and requirements.

* Mac OS X 10.5 and 10.6, and some older Linux distributions, use salted SHA1
  hashes. You can use Puppet's built-in `sha1` function to generate a salted SHA1
  hash from a password.
* Mac OS X 10.7 (Lion), and many recent Linux distributions, use salted SHA512
  hashes. The Puppet Labs [stdlib][] module contains a `str2saltedsha512` function
  which can generate password hashes for these operating systems.
* OS X 10.8 and higher use salted SHA512 PBKDF2 hashes. When managing passwords
  on these systems, the `salt` and `iterations` attributes need to be specified as
  well as the password.
* macOS 10.15 and later require the salt to be 32 bytes. Because Puppet's user
  resource requires the value to be hex encoded, the length of the salt's
  string must be 64.
* Windows passwords can be managed only in cleartext, because there is no Windows
  API for setting the password hash.

[stdlib]: https://github.com/puppetlabs/puppetlabs-stdlib/

Enclose any value that includes a dollar sign ($) in single quotes (') to avoid
accidental variable interpolation.

To redact passwords from reports to PuppetDB, use the `Sensitive` data type. For
example, this resource protects the password:

```puppet
user { 'foo':
  ensure   => present,
  password => Sensitive("my secret password")
}
```

This results in the password being redacted from the report, as in the
`previous_value`, `desired_value`, and `message` fields below.

```yaml
    events:
    - !ruby/object:Puppet::Transaction::Event
      audited: false
      property: password
      previous_value: "[redacted]"
      desired_value: "[redacted]"
      historical_value:
      message: changed [redacted] to [redacted]
      name: :password_changed
      status: success
      time: 2017-05-17 16:06:02.934398293 -07:00
      redacted: true
      corrective_change: false
    corrective_change: false
```



Requires features manages_passwords.

([↑ Back to user attributes](#user-attributes))


#### password_max_age {#user-attribute-password_max_age}

_(**Property:** This attribute represents concrete state on the target system.)_

The maximum number of days a password may be used before it must be changed.



Requires features manages_password_age.

([↑ Back to user attributes](#user-attributes))


#### password_min_age {#user-attribute-password_min_age}

_(**Property:** This attribute represents concrete state on the target system.)_

The minimum number of days a password must be used before it may be changed.



Requires features manages_password_age.

([↑ Back to user attributes](#user-attributes))


#### password_warn_days {#user-attribute-password_warn_days}

_(**Property:** This attribute represents concrete state on the target system.)_

The number of days before a password is going to expire (see the maximum password age) during which the user should be warned.



Requires features manages_password_age.

([↑ Back to user attributes](#user-attributes))


#### profile_membership {#user-attribute-profile_membership}

Whether specified roles should be treated as the **complete list**
(`inclusive`) or the **minimum list** (`minimum`) of roles
of which the user is a member.

Valid values are `inclusive`, `minimum`.

([↑ Back to user attributes](#user-attributes))


#### profiles {#user-attribute-profiles}

_(**Property:** This attribute represents concrete state on the target system.)_

The profiles the user has.  Multiple profiles should be
specified as an array.



Requires features manages_solaris_rbac.

([↑ Back to user attributes](#user-attributes))


#### project {#user-attribute-project}

_(**Property:** This attribute represents concrete state on the target system.)_

The name of the project associated with a user.



Requires features manages_solaris_rbac.

([↑ Back to user attributes](#user-attributes))


#### provider {#user-attribute-provider}

The specific backend to use for this `user`
resource. You will seldom need to specify this --- Puppet will usually
discover the appropriate provider for your platform.

Available providers are:

* [`aix`](#user-provider-aix)
* [`directoryservice`](#user-provider-directoryservice)
* [`hpuxuseradd`](#user-provider-hpuxuseradd)
* [`ldap`](#user-provider-ldap)
* [`openbsd`](#user-provider-openbsd)
* [`pw`](#user-provider-pw)
* [`user_role_add`](#user-provider-user_role_add)
* [`useradd`](#user-provider-useradd)
* [`windows_adsi`](#user-provider-windows_adsi)

([↑ Back to user attributes](#user-attributes))


#### purge_ssh_keys {#user-attribute-purge_ssh_keys}

Whether to purge authorized SSH keys for this user if they are not managed
with the `ssh_authorized_key` resource type. This parameter is a noop if the
ssh_authorized_key type is not available.

Allowed values are:

* `false` (default) --- don't purge SSH keys for this user.
* `true` --- look for keys in the `.ssh/authorized_keys` file in the user's
  home directory. Purge any keys that aren't managed as `ssh_authorized_key`
  resources.
* An array of file paths --- look for keys in all of the files listed. Purge
  any keys that aren't managed as `ssh_authorized_key` resources. If any of
  these paths starts with `~` or `%h`, that token will be replaced with
  the user's home directory.

Valid values are `true`, `false`.

([↑ Back to user attributes](#user-attributes))


#### role_membership {#user-attribute-role_membership}

Whether specified roles should be considered the **complete list**
(`inclusive`) or the **minimum list** (`minimum`) of roles the user
has.

Valid values are `inclusive`, `minimum`.

([↑ Back to user attributes](#user-attributes))


#### roles {#user-attribute-roles}

_(**Property:** This attribute represents concrete state on the target system.)_

The roles the user has.  Multiple roles should be
specified as an array.



Requires features manages_roles.

([↑ Back to user attributes](#user-attributes))


#### salt {#user-attribute-salt}

_(**Property:** This attribute represents concrete state on the target system.)_

This is the 32-byte salt used to generate the PBKDF2 password used in
OS X. This field is required for managing passwords on OS X >= 10.8.



Requires features manages_password_salt.

([↑ Back to user attributes](#user-attributes))


#### shell {#user-attribute-shell}

_(**Property:** This attribute represents concrete state on the target system.)_

The user's login shell.  The shell must exist and be
executable.

This attribute cannot be managed on Windows systems.



Requires features manages_shell.

([↑ Back to user attributes](#user-attributes))


#### system {#user-attribute-system}

Whether the user is a system user, according to the OS's criteria;
on most platforms, a UID less than or equal to 500 indicates a system
user. This parameter is only used when the resource is created and will
not affect the UID when the user is present.

Valid values are `true`, `false`, `yes`, `no`.

([↑ Back to user attributes](#user-attributes))


#### uid {#user-attribute-uid}

_(**Property:** This attribute represents concrete state on the target system.)_

The user ID; must be specified numerically. If no user ID is
specified when creating a new user, then one will be chosen
automatically. This will likely result in the same user having
different UIDs on different systems, which is not recommended. This is
especially noteworthy when managing the same user on both Darwin and
other platforms, since Puppet does UID generation on Darwin, but
the underlying tools do so on other platforms.

On Windows, this property is read-only and will return the user's
security identifier (SID).

([↑ Back to user attributes](#user-attributes))


### Providers {#user-providers}

#### aix {#user-provider-aix}

User management for AIX.

* Required binaries: `/bin/chpasswd`, `/usr/bin/chuser`, `/usr/bin/mkuser`, `/usr/sbin/lsuser`, `/usr/sbin/rmuser`.
* Default for `os.name` == `aix`.
* Supported features: `manages_aix_lam`, `manages_expiry`, `manages_homedir`, `manages_local_users_and_groups`, `manages_password_age`, `manages_passwords`, `manages_shell`.

#### directoryservice {#user-provider-directoryservice}

User management on OS X.

* Required binaries: `/usr/bin/dscacheutil`, `/usr/bin/dscl`, `/usr/bin/dsimport`, `/usr/bin/uuidgen`.
* Default for `os.name` == `darwin`.
* Supported features: `manages_password_salt`, `manages_passwords`, `manages_shell`.

#### hpuxuseradd {#user-provider-hpuxuseradd}

User management for HP-UX. This provider uses the undocumented `-F`
switch to HP-UX's special `usermod` binary to work around the fact that
its standard `usermod` cannot make changes while the user is logged in.
New functionality provides for changing trusted computing passwords and
resetting password expirations under trusted computing.

* Required binaries: `/usr/sam/lbin/useradd.sam`, `/usr/sam/lbin/userdel.sam`, `/usr/sam/lbin/usermod.sam`.
* Default for `os.name` == `hp-ux`.
* Supported features: `allows_duplicates`, `manages_homedir`, `manages_passwords`.

#### ldap {#user-provider-ldap}

User management via LDAP.

This provider requires that you have valid values for all of the
LDAP-related settings in `puppet.conf`, including `ldapbase`.  You will
almost definitely need settings for `ldapuser` and `ldappassword` in order
for your clients to write to LDAP.

Note that this provider will automatically generate a UID for you if
you do not specify one, but it is a potentially expensive operation,
as it iterates across all existing users to pick the appropriate next one.

* Supported features: `manages_passwords`, `manages_shell`.

#### openbsd {#user-provider-openbsd}

User management via `useradd` and its ilk for OpenBSD. Note that you
will need to install Ruby's shadow password library (package known as
`ruby-shadow`) if you wish to manage user passwords.

* Required binaries: `passwd`, `useradd`, `userdel`, `usermod`.
* Default for `os.name` == `openbsd`.
* Supported features: `manages_expiry`, `manages_homedir`, `manages_shell`, `system_users`.

#### pw {#user-provider-pw}

User management via `pw` on FreeBSD and DragonFly BSD.

* Required binaries: `pw`.
* Default for `os.name` == `freebsd, dragonfly`.
* Supported features: `allows_duplicates`, `manages_expiry`, `manages_homedir`, `manages_passwords`, `manages_shell`.

#### user_role_add {#user-provider-user_role_add}

User and role management on Solaris, via `useradd` and `roleadd`.

* Required binaries: `passwd`, `roleadd`, `roledel`, `rolemod`, `useradd`, `userdel`, `usermod`.
* Default for `os.family` == `solaris`.
* Supported features: `allows_duplicates`, `manages_homedir`, `manages_password_age`, `manages_passwords`, `manages_roles`, `manages_shell`, `manages_solaris_rbac`.

#### useradd {#user-provider-useradd}

User management via `useradd` and its ilk.  Note that you will need to
install Ruby's shadow password library (often known as `ruby-libshadow`)
if you wish to manage user passwords.

To use the `forcelocal` parameter, you need to install the `libuser` package (providing
`/usr/sbin/lgroupadd` and `/usr/sbin/luseradd`).

* Required binaries: `chage`, `chpasswd`, `lchage`, `luseradd`, `luserdel`, `lusermod`, `useradd`, `userdel`, `usermod`.
* Supported features: `allows_duplicates`, `manages_expiry`, `manages_homedir`, `manages_shell`, `system_users`.

#### windows_adsi {#user-provider-windows_adsi}

Local user management for Windows.

* Default for `os.name` == `windows`.
* Supported features: `manages_homedir`, `manages_passwords`, `manages_roles`.

### Provider Features {#user-provider-features}

Available features:

* `allows_duplicates` --- The provider supports duplicate users with the same UID.
* `manages_aix_lam` --- The provider can manage AIX Loadable Authentication Module (LAM) system.
* `manages_expiry` --- The provider can manage the expiry date for a user.
* `manages_homedir` --- The provider can create and remove home directories.
* `manages_local_users_and_groups` --- Allows local users to be managed on systems that also use some other remote Name Service Switch (NSS) method of managing accounts.
* `manages_loginclass` --- The provider can manage the login class for a user.
* `manages_password_age` --- The provider can set age requirements and restrictions for passwords.
* `manages_password_salt` --- The provider can set a password salt. This is for providers that implement PBKDF2 passwords with salt properties.
* `manages_passwords` --- The provider can modify user passwords, by accepting a password hash.
* `manages_roles` --- The provider can manage roles
* `manages_shell` --- The provider allows for setting shell and validates if possible
* `manages_solaris_rbac` --- The provider can manage normal users
* `system_users` --- The provider allows you to create system users with lower UIDs.

Provider support:

* **aix** - _manages aix lam, manages expiry, manages homedir, manages local users and groups, manages password age, manages passwords, manages shell_
* **directoryservice** - _manages password salt, manages passwords, manages shell_
* **hpuxuseradd** - _allows duplicates, manages homedir, manages passwords_
* **ldap** - _manages passwords, manages shell_
* **openbsd** - _manages expiry, manages homedir, manages shell, system users, manages passwords, manages loginclass_
* **pw** - _allows duplicates, manages expiry, manages homedir, manages passwords, manages shell_
* **user_role_add** - _allows duplicates, manages homedir, manages password age, manages passwords, manages roles, manages shell, manages solaris rbac_
* **useradd** - _allows duplicates, manages expiry, manages homedir, manages shell, system users, manages passwords, manages password age, libuser_
* **windows_adsi** - _manages homedir, manages passwords, manages roles_
  




