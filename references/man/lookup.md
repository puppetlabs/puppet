---
layout: default
built_from_commit: 6893bdd69ab1291e6e6fcd6b152dda2b48e3cdb2
title: 'Man Page: puppet lookup'
canonical: "/puppet/latest/man/lookup.html"
---

# Man Page: puppet lookup

> **NOTE:** This page was generated from the Puppet source code on 2024-10-17 02:36:47 +0000

NAME
====

**puppet-lookup** - Interactive Hiera lookup

SYNOPSIS
========

Does Hiera lookups from the command line.

Since this command needs access to your Hiera data, make sure to run it
on a node that has a copy of that data. This usually means logging into
a Puppet Server node and running \'puppet lookup\' with sudo.

The most common version of this command is:

\'puppet lookup *KEY* \--node *NAME* \--environment *ENV* \--explain\'

USAGE
=====

puppet lookup \[\--help\] \[\--type *TYPESTRING*\] \[\--merge
first\|unique\|hash\|deep\] \[\--knock-out-prefix *PREFIX-STRING*\]
\[\--sort-merged-arrays\] \[\--merge-hash-arrays\] \[\--explain\]
\[\--environment *ENV*\] \[\--default *VALUE*\] \[\--node *NODE-NAME*\]
\[\--facts *FILE*\] \[\--compile\] \[\--render-as
s\|json\|yaml\|binary\|msgpack\] *keys*

DESCRIPTION
===========

The lookup command is a CLI for Puppet\'s \'lookup()\' function. It
searches your Hiera data and returns a value for the requested lookup
key, so you can test and explore your data. It is a modern replacement
for the \'hiera\' command. Lookup uses the setting for global hiera.yaml
from puppet\'s config, and the environment to find the environment level
hiera.yaml as well as the resulting modulepath for the environment (for
hiera.yaml files in modules). Hiera usually relies on a node\'s facts to
locate the relevant data sources. By default, \'puppet lookup\' uses
facts from the node you run the command on, but you can get data for any
other node with the \'\--node *NAME*\' option. If possible, the lookup
command will use the requested node\'s real stored facts from PuppetDB;
if PuppetDB isn\'t configured or you want to provide arbitrary fact
values, you can pass alternate facts as a JSON or YAML file with
\'\--facts *FILE*\'.

If you\'re debugging your Hiera data and want to see where values are
coming from, use the \'\--explain\' option.

If \'\--explain\' isn\'t specified, lookup exits with 0 if a value was
found and 1 otherwise. With \'\--explain\', lookup always exits with 0
unless there is a major error.

You can provide multiple lookup keys to this command, but it only
returns a value for the first found key, omitting the rest.

For more details about how Hiera works, see the Hiera documentation:
https://puppet.com/docs/puppet/latest/hiera\_intro.html

OPTIONS
=======

-   \--help: Print this help message.

-   \--explain Explain the details of how the lookup was performed and
    where the final value came from (or the reason no value was found).

-   \--node *NODE-NAME* Specify which node to look up data for; defaults
    to the node where the command is run. Since Hiera\'s purpose is to
    provide different values for different nodes (usually based on their
    facts), you\'ll usually want to use some specific node\'s facts to
    explore your data. If the node where you\'re running this command is
    configured to talk to PuppetDB, the command will use the requested
    node\'s most recent facts. Otherwise, you can override facts with
    the \'\--facts\' option.

-   \--facts *FILE* Specify a .json or .yaml file of key =\> value
    mappings to override the facts for this lookup. Any facts not
    specified in this file maintain their original value.

-   \--environment *ENV* Like with most Puppet commands, you can specify
    an environment on the command line. This is important for lookup
    because different environments can have different Hiera data. This
    environment will be always be the one used regardless of any other
    factors.

-   \--merge first\|unique\|hash\|deep: Specify the merge behavior,
    overriding any merge behavior from the data\'s lookup\_options.
    \'first\' returns the first value found. \'unique\' appends
    everything to a merged, deduplicated array. \'hash\' performs a
    simple hash merge by overwriting keys of lower lookup priority.
    \'deep\' performs a deep merge on values of Array and Hash type.
    There are additional options that can be used with \'deep\'.

-   \--knock-out-prefix *PREFIX-STRING* Can be used with the \'deep\'
    merge strategy. Specifies a prefix to indicate a value should be
    removed from the final result.

-   \--sort-merged-arrays Can be used with the \'deep\' merge strategy.
    When this flag is used, all merged arrays are sorted.

-   \--merge-hash-arrays Can be used with the \'deep\' merge strategy.
    When this flag is used, hashes WITHIN arrays are deep-merged with
    their counterparts by position.

-   \--explain-options Explain whether a lookup\_options hash affects
    this lookup, and how that hash was assembled. (lookup\_options is
    how Hiera configures merge behavior in data.)

-   \--default *VALUE* A value to return if Hiera can\'t find a value in
    data. For emulating calls to the \'lookup()\' function that include
    a default.

-   \--type *TYPESTRING*: Assert that the value has the specified type.
    For emulating calls to the \'lookup()\' function that include a data
    type.

-   \--compile Perform a full catalog compilation prior to the lookup.
    If your hierarchy and data only use the \$facts, \$trusted, and
    \$server\_facts variables, you don\'t need this option; however, if
    your Hiera configuration uses arbitrary variables set by a Puppet
    manifest, you might need this option to get accurate data. No
    catalog compilation takes place unless this flag is given.

-   \--render-as s\|json\|yaml\|binary\|msgpack Specify the output
    format of the results; \"s\" means plain text. The default when
    producing a value is yaml and the default when producing an
    explanation is s.

-   

EXAMPLE
=======

To look up \'key\_name\' using the Puppet Server node\'s facts: \$
puppet lookup key\_name

To look up \'key\_name\' using the Puppet Server node\'s arbitrary
variables from a manifest, and classify the node if applicable: \$
puppet lookup key\_name \--compile

To look up \'key\_name\' using the Puppet Server node\'s facts,
overridden by facts given in a file: \$ puppet lookup key\_name \--facts
fact\_file.yaml

To look up \'key\_name\' with agent.local\'s facts: \$ puppet lookup
\--node agent.local key\_name

To get the first value found for \'key\_name\_one\' and
\'key\_name\_two\' with agent.local\'s facts while merging values and
knocking out the prefix \'foo\' while merging: \$ puppet lookup \--node
agent.local \--merge deep \--knock-out-prefix foo key\_name\_one
key\_name\_two

To lookup \'key\_name\' with agent.local\'s facts, and return a default
value of \'bar\' if nothing was found: \$ puppet lookup \--node
agent.local \--default bar key\_name

To see an explanation of how the value for \'key\_name\' would be found,
using agent.local\'s facts: \$ puppet lookup \--node agent.local
\--explain key\_name

COPYRIGHT
=========

Copyright (c) 2015 Puppet Inc., LLC Licensed under the Apache 2.0
License
