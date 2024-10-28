---
layout: default
built_from_commit: 8fcce5cb0d88b7330540e59817a7e6eae7adcdea
title: 'Man Page: puppet doc'
canonical: "/puppet/latest/man/doc.html"
---

# Man Page: puppet doc

> **NOTE:** This page was generated from the Puppet source code on 2024-10-28 17:40:38 +0000

## NAME
**puppet-doc** - Generate Puppet references

## SYNOPSIS
Generates a reference for all Puppet types. Largely meant for internal
Puppet Inc. use. (Deprecated)

## USAGE
puppet doc \[-h\|\--help\] \[-l\|\--list\] \[-r\|\--reference
*reference-name*\]

## DESCRIPTION
This deprecated command generates a Markdown document to stdout
describing all installed Puppet types or all allowable arguments to
puppet executables. It is largely meant for internal use and is used to
generate the reference document available on the Puppet Inc. web site.

For Puppet module documentation (and all other use cases) this command
has been superseded by the \"puppet-strings\" module - see
https://github.com/puppetlabs/puppetlabs-strings for more information.

This command (puppet-doc) will be removed once the puppetlabs internal
documentation processing pipeline is completely based on puppet-strings.

## OPTIONS
\--help

:   Print this help message

\--reference

:   Build a particular reference. Get a list of references by running
    \'puppet doc \--list\'.

## EXAMPLE

    $ puppet doc -r type > /tmp/type_reference.markdown

## AUTHOR
Luke Kanies

## COPYRIGHT
Copyright (c) 2011 Puppet Inc., LLC Licensed under the Apache 2.0
License
