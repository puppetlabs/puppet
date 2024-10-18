---
layout: default
built_from_commit: 812d7420ea5d7e19e8003b26486a7c8847afdb25
title: 'Resource Type: file'
canonical: "/puppet/latest/types/file.html"
---

# Resource Type: file

> **NOTE:** This page was generated from the Puppet source code on 2024-10-18 17:23:49 +0000



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

Allowed values:

* `absent`
* `false`
* `file`
* `present`
* `directory`
* `link`
* `/./`

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

Default: `false`

([↑ Back to file attributes](#file-attributes))


#### checksum {#file-attribute-checksum}

The checksum type to use when determining whether to replace a file's contents.

The default checksum type is sha256.

Allowed values:

* `sha256`
* `sha256lite`
* `md5`
* `md5lite`
* `sha1`
* `sha1lite`
* `sha512`
* `sha384`
* `sha224`
* `mtime`
* `ctime`
* `none`

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

A read-only state to check the file ctime. On most modern \*nix-like
systems, this is the time of the most recent change to the owner, group,
permissions, or content of the file.

([↑ Back to file attributes](#file-attributes))


#### force {#file-attribute-force}

Perform the file operation even if it will destroy one or more directories.
You must use `force` in order to:

* `purge` subdirectories
* Replace directories with files or links
* Remove a directory when `ensure => absent`

Default: `false`

Allowed values:

* `true`
* `false`
* `yes`
* `no`

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

Default: `manage`

Allowed values:

* `follow`
* `manage`

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

Default: `0`

Allowed values:

* `/^[0-9]+$/`
* `/^-1$/`

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

A read-only state to check the file mtime. On \*nix-like systems, this
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

The specific backend to use for this `file` resource. You will seldom need to specify this --- Puppet will usually discover the appropriate provider for your platform.

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

Default: `false`

Allowed values:

* `true`
* `false`
* `yes`
* `no`

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

Allowed values:

* `true`
* `false`
* `remote`

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

Allowed values:

* `/^[0-9]+$/`

([↑ Back to file attributes](#file-attributes))


#### replace {#file-attribute-replace}

Whether to replace a file or symlink that already exists on the local system but
whose content doesn't match what the `source` or `content` attribute
specifies.  Setting this to false allows file resources to initialize files
without overwriting future changes.  Note that this only affects content;
Puppet will still manage ownership and permissions.

Default: `true`

Allowed values:

* `true`
* `false`
* `yes`
* `no`

([↑ Back to file attributes](#file-attributes))


#### selinux_ignore_defaults {#file-attribute-selinux_ignore_defaults}

If this is set, Puppet will not call the SELinux function selabel_lookup to
supply defaults for the SELinux attributes (seluser, selrole,
seltype, and selrange). In general, you should leave this set at its
default and only set it to true when you need Puppet to not try to fix
SELinux labels automatically.

Default: `false`

Allowed values:

* `true`
* `false`

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

Default: `true`

Allowed values:

* `true`
* `false`
* `yes`
* `no`

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

Default: `ignore`

Allowed values:

* `use`
* `use_when_creating`
* `ignore`

([↑ Back to file attributes](#file-attributes))


#### sourceselect {#file-attribute-sourceselect}

Whether to copy all valid sources, or just the first one.  This parameter
only affects recursive directory copies; by default, the first valid
source is the only one used, but if this parameter is set to `all`, then
all valid sources will have all of their contents copied to the local
system. If a given file exists in more than one source, the version from
the earliest source in the list will be used.

Default: `first`

Allowed values:

* `first`
* `all`

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

Allowed values:

* `notlink`
* `/./`

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

Default: `%`

([↑ Back to file attributes](#file-attributes))


### Providers {#file-providers}

#### posix {#file-provider-posix}

Uses POSIX functionality to manage file ownership and permissions.

* Confined to: `feature == posix`
* Supported features: `manages_symlinks`

#### windows {#file-provider-windows}

Uses Microsoft Windows functionality to manage file ownership and permissions.

* Confined to: `os.name == windows`

### Provider Features {#file-provider-features}

Available features:

* `manages_symlinks` --- The provider can manage symbolic links.

Provider support:

* **posix** - _manages symlinks_
* **windows** - No supported Provider features
  




