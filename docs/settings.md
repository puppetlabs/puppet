Settings
========

<!-- markdown-toc start - Don't edit this section. Run M-x markdown-toc-refresh-toc -->
**Table of Contents**

- [Definitions](#definitions)
- [Sections](#sections)
- [Initialization](#initialization)
- [Dashes & Underscores](#dashes--underscores)
- [Setting Types](#setting-types)
- [Setting Values](#setting-values)
    - [Duration & TTL Settings](#duration--ttl-settings)
    - [File/Directory Settings](#filedirectory-settings)
- [Hooks](#hooks)
- [Run Mode](#run-mode)
    - [Preferred Run Mode](#preferred-run-mode)
- [Precedence](#precedence)
- [File Watcher](#file-watcher)
- [RSpec](#rspec)

<!-- markdown-toc end -->

Puppet can be configured via settings. All settings are defined in
`lib/puppet/defaults.rb`. All settings have a type, value, description, etc.
Settings can come from multiple sources such as the command line, configuration
file, programmatically, etc, and are looked up in a specific order, so that the
command line takes precedence over what's specified in puppet.conf.

Puppet settings can be looked up using `Puppet[:name]` and set using
`Puppet[:name] = 'value'`.

# Definitions

Settings are defined using `Puppet::Settings#define_settings`. The method takes
a section name, setting name and a hash describing the setting, e.g. its type,
description, etc.

# Sections

Puppet settings can be specified in INI file format based on a section, for example:

```inifile
[main]
strict=true
```

Comments and whitespace are ignored. A setting may be configured in any section,
even if it wasn't defined in that section. For example, the `strict` setting is
defined in `main`:

```ruby
settings.define_setting(:main, strict: { ... })
```

But it can be configured in any section, so this is legal:

```inifile
[server]
strict = true
```

The purpose of the section name is when applying a settings catalog, see
'File/Directory Settings' below.

Puppet predefines section names like `main`, `user`, `agent` and `server`. Only
these sections are allowed in `puppet.conf`.

# Initialization

The entry point for initializing settings is `Puppet.initialize_settings`. It is
possible to pass in command line arguments, as well as inject dependencies, such
as an alternate facter implementation.

Puppet initializes its settings in three phases: global options, loading its
`puppet.conf`, and application options.

First, puppet parses command line arguments using our vendored trollop library.
Any argument with the same name as a puppet setting is automatically set. The
argument and its optional value are "consumed" and unknown arguments are
ignored. Puppet handles boolean arguments specially, so it's possible to pass
`--onetime` or `--no-onetime`, and puppet will set the value to `true` or
`false`, respectively.

Second, puppet loads `puppet.conf` from a predefined location depending on
whether it's running privileged or not. See
[https://github.com/puppetlabs/puppet-specifications/blob/master/file_paths.md](https://github.com/puppetlabs/puppet-specifications/blob/master/file_paths.md
). Assuming puppet is running an application like `puppet agent`, then
the application parses unconsumed arguments using Ruby's builtin
`OptionParser`.

Third, the application parses any application-specific options using the same
`OptionParser` instance from above. If the application defines an option with
the same name as a setting, the application's option handler will be called
last, so it "wins".

# Dashes & Underscores

Puppet settings are always defined using underscores, but application options
should always be defined using dashes, e.g. `option("--job-id ID")`

As long as you're using Ruby 2.5 or above, `OptionParser` will automatically
convert underscores to dashes, so your option handler will always be called
even if the setting is specified using underscores in `puppet.conf` or on the
command line.

# Setting Types

By default, settings are assumed to contain a string value. It is possible to
specify another type when the setting is defined, such as `:type => :integer`. Each
type maps to a subclass of `Puppet::Settings::BaseSetting`. In general, try to
reuse an existing type instead of creating one subclass for every setting.

When creating a new setting type, you may need to implement the `munge` method
to convert the external representation (the string "42") to its internal
representation (the integer 42).

You may also want to implement the `print` method, which is invoked when running
`puppet config print <name>`.

# Setting Values

Puppet defines several "root" settings that must be defined, such as `confdir`.
These settings default to directories based on whether puppet is running as a
privileged user and is running on Windows or not.

Non-root settings may be defined in terms of other settings. For example, the
`ssldir` setting's value is defined to be `"$confdir/ssl"`. So in order to
resolve the value of the `ssldir`, puppet will recursively resolve `confdir`.
Puppet supports multiple levels of recursion, but will raise if it detects a
cycle.

## Duration & TTL Settings

Puppet's duration and ttl-based settings assume the value is specified in
seconds unless units are specified, such as `5m`, `1h`, etc.

## File/Directory Settings

The `file` and `directory` settings are handled specially, because puppet will
compile an internal "settings" catalog and apply it, to ensure they match the
desired state. So whenever `Puppet.settings.use(:main, etc)` is called, then all
file and directory-based settings in the `main`, etc sections will be added to
the settings catalog.

It is possible to specify the `owner` and/or `group` for these types of
settings. The special `service` account means use whatever user/group puppet is
configured to run under, as specified as `Puppet[:user]`/`Puppet[:group]`. For
example, when puppet is a library within puppetserver, `Puppet[:user]` is set
to the `puppet` user. This way puppetserver, not running as root, can access
files that puppet creates.

It is also possible for a user to specify `owner`, `group` or `mode` metadata in
`puppet.conf` by appending a hash after the value:

```inifile
ssldir = "$confdir/ssl" { owner=root,group=root,mode=0750 }
```

See also the `settings_catalog` and `manage_internal_file_permissions` settings,
which can disable these behaviors.

# Hooks

It is possible to add a hook to a setting. The hook will be called at various
times whenever the value is set. The hook may be called multiple times. Hook
behavior is confusing and surprising! If you must define a new hook, use
`on_initialize_and_write`. The other types of hooks won't be called if the
setting is defined in a section that doesn't match the current run_mode.

If a setting's default value interpolates another base setting, then the hook
will **not** be called if the base setting changes. So try to avoid mixing hooks
and interpolated default values.

# Run Mode

Puppet can be configured to run in different "modes". The default run mode is
`:user`, but can be switched to `:agent` or `:server`. If the run mode is
switched, then it changes how settings are resolved. For example, given
`puppet.conf` containing:

```inifile
[server]
node_terminus=exec
```
Then calling `Puppet[:node_terminus]` will return either `nil` or `exec`
depending on the current run mode.

## Preferred Run Mode

Settings and run mode have a circular dependency. We need to know the run mode
in order to load settings. However, puppet applications are defined in modules.
So we need to resolve the `modulepath` setting to find the application, and then
the application can change the run mode.

To break the dependency, puppet's preferred run mode is the mode it initially
starts in, though it may change later on.

# Precedence

Puppet settings can be defined in multiple sources (command line, puppet.conf,
etc). When looking up a value, puppet searches based on the precedence of each
source, roughly in order of high to low:

* memory
* command line
* current environment.conf
* section for the current run mode
* main section
* defaults

It is important to note that both the current environment and run mode change
how the value is resolved.

# File Watcher

When running as a daemon, puppet will watch its `puppet.conf` and reload its
configuration if it changes.

# RSpec

To avoid order-dependent test failures, puppet's rspec tests create unique
"root" directories for each rspec example. For example, you can safely mutate
settings in a test `Puppet[:strict] = true` or modify the contents of the
`confdir` without affecting other tests.
