---
layout: default
built_from_commit: 8fcce5cb0d88b7330540e59817a7e6eae7adcdea
title: Report Reference
toc: columns
canonical: "/puppet/latest/report.html"
---

# Report Reference

> **NOTE:** This page was generated from the Puppet source code on 2024-10-28 17:40:37 +0000




Puppet can generate a report after applying a catalog. This report includes
events, log messages, resource statuses, and metrics and metadata about the run.
Puppet agent sends its report to a Puppet master server, and Puppet apply
processes its own reports.

Puppet master and Puppet apply will handle every report with a set of report
processors, configurable with the `reports` setting in puppet.conf. This page
documents the built-in report processors.

See [About Reporting](https://puppet.com/docs/puppet/latest/reporting_about.html)
for more details.

http
----
Send reports via HTTP or HTTPS. This report processor submits reports as
POST requests to the address in the `reporturl` setting. When a HTTPS URL
is used, the remote server must present a certificate issued by the Puppet
CA or the connection will fail validation. The body of each POST request
is the YAML dump of a Puppet::Transaction::Report object, and the
Content-Type is set as `application/x-yaml`.

log
---
Send all received logs to the local log destinations.  Usually
the log destination is syslog.

store
-----
Store the yaml report on disk.  Each host sends its report as a YAML dump
and this just stores the file on disk, in the `reportdir` directory.

These files collect quickly -- one every half hour -- so it is a good idea
to perform some maintenance on them if you use this report (it's the only
default report).

