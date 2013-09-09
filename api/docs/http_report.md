Report
======
This describes Report Format 3.
Report format 2 is almost identical, the single difference is noted in the documentation of `Puppet::Transaction::Report`.

The `report` endpoint ?? allows clients to send reports to the master, and later retrieve them.

    NOTE ??? Unclear what the endpoint is, and how to retrieve a report.
    
A *report* consists of a `Puppet::Transaction::Report` object which in turn contains a structure of objects with of the following types:

* `Puppet::Util::Log`
* `Puppet::Util::Metric`
* `Puppet::Resource::Status`
* `Puppet::Transaction::Event` 

Reports
-------
There are 5 reports, supporting different means of sending reports.

    NOTE ??? These are found under lib/puppet/report/
    Should they all be documented. The documentation from the source code is included
    below, with some minor corrections, and embedded questions.
    
* http
* log
* rrdgraph
* store
* tagmail

### http

Send reports via HTTP or HTTPS. This report processor submits reports as
POST requests to the address in the `reporturl` setting. The body of each POST
request is the YAML dump of a `Puppet::Transaction::Report` object, and the
Content-Type is set as `application/x-yaml`.

    NOTE ??? (The above is from the existing documentation). Now it is also possible
    to send in pson format. For catalog, the content type is noted as pson or text/pson.
    Does it work the same way for reports?

The send fails if it does not get a HTTP 2xx status back. 

    POST /:environment/report/http

#### Supported HTTP Methods

    POST

#### Supported Format

    Accept: application/x-yaml
    
    NOTE ?? Why does the documentation say "Accept", isn't that what the client accepts in the
    response? (Is this for find/search?). The POST header is probably different...

#### Parameters

    ???

### log

Sends all received logs to the local log destinations.  Usually
the log destination is syslog.

    NOTE ?? The above is from the doc in the source code, and it quite incomprehensible.
    What is "received logs", what is "local log destination"? (local to what). The implementation
    calls Puppet::Util::Log.newmessage(log), for the list of log entries.
    
    Is this part of processing the overall "report" when it processes entries? Does that mean
    log reports from agents end up in the master's host's syslog?

### store

Stores the yaml report on disk. Each host sends its report as a YAML dump
and this just stores the file on disk, in the `reportdir` directory.

These files collect quickly -- one every half hour -- so it is a good idea
to perform some maintenance on them if you use this report (it's the only
default report).

    NOTE ?? What does "perform some maintenance on them" mean? Does this mean manually deleting
    files? Is something else recommended? What does it mean when it says "it's the only default
    report" (is it trying to say "this is the only report that you need to do maintenance on
    unless you have added our own reports?"")
    
    It says "this report just stores them on disk" - what is the relationship between the "http" and
    the "store". (What are "http" and "store" again ? Different reports ???)
    
    What if report is sent in pson format?
    
    NOTE ?? How does the reports end up in PuppetDB ?

### tagmail

This report sends specific log messages to specific email addresses
based on the tags in the log messages.

See the [documentation on tags](http://projects.puppetlabs.com/projects/puppet/wiki/Using_Tags) for more information about tags.

    NOTE ?? There is nothing describing the relationship between setting tags on objects,
    and invoking operations on resources tagged a certain way. The reference above contains
    general information about tags, but not how they apply to reports.
    
To use this report, you must create a `tagmail.conf` file in the location
specified by the `tagmap` setting.  This is a simple file that maps tags to
email addresses:  Any log messages in the report that match the specified
tags will be sent to the specified email addresses.

Lines in the `tagmail.conf` file consist of a comma-separated list
of tags, a colon, and a comma-separated list of email addresses.
Tags can be !negated with a leading exclamation mark, which will
subtract any messages with that tag from the set of events handled
by that line.

Puppet's log levels (`debug`, `info`, `notice`, `warning`, `err`,
`alert`, `emerg`, `crit`, and `verbose`) can also be used as tags,
and there is an `all` tag that will always match all log messages.

An example `tagmail.conf`:

    all: me@domain.com
    webserver, !mailserver: httpadmins@domain.com

This will send all messages to `me@domain.com`, and all messages from
webservers that are not also from mailservers to `httpadmins@domain.com`.

If you are using anti-spam controls such as grey-listing on your mail
server, you should whitelist the sending email address (controlled by
`reportfrom` configuration option) to ensure your email is not discarded as spam.
    
### rrdgraph

Graph all available (time series) data about hosts using the RRD library.  You
must have the Ruby RRDtool library installed to use this report, which
you can get from
[the RubyRRDTool RubyForge page](http://rubyforge.org/projects/rubyrrdtool/).
This package may also be available as `librrd-ruby`, `ruby-rrd`, or `rrdtool-ruby` in your
distribution's package management system.  The library and/or package will both
require the binary `rrdtool` package from your distribution to be installed.

This report will create, manage, and graph RRD database files for each
of the metrics generated during transactions, and it will create a
few simple html files to display the reporting host's graphs.  At this
point, it will not create a common index file to display links to
all hosts.

All RRD files and graphs are created in the `rrddir` directory.  If
you want to serve these publicly, you should be able to just alias that
directory in a web server.

If you really know what you're doing, you can tune the `rrdinterval`,
which defaults to the `runinterval`.

    NOTE ?? Is this really used in the wild? Found a thread from 2011 that suggest it isn't really
    used due to its requirements on installed libraries and that there are better alternatives.
    http://comments.gmane.org/gmane.comp.sysutils.puppet.user/30781
    
    Call for help, like this (from 2012): 
    http://grokbase.com/t/gg/puppet-users/12agrbc2nj/unable-to-create-the-rrd-graph
    goes unanswered. (Also suggests it is not used)
    
    This issue http://projects.reductivelabs.com/issues/2891 is open since 2 years, has attached
    patches and it fizzles after a "code incomplete" status.
    
    
Find
----
    NOTE ?? How do you find a report?

Search
------

    NOTE ?? How do you search for a report?

Objects
=======
Puppet::Transaction::Report
---------------------------
<table>
<tr>
  <th>name</th>
  <th>type</th>
  <th>description</th>
</tr>
<tr>
  <td>host</td>
  <td><code>String</code></td>
  <td>The host that generated the report.</td>
</tr>
<tr>
  <td>time</td>
  <td><code>DateTime</code></td>
  <td>When the run began</td>
</tr>
<tr>
  <td>logs</td>
  <td><code>Array[Puppet::Util::Log]</code></td>
  <td>Zero or more occurances</td>
</tr>
<tr>
  <td>metrics </td>
  <td><code>Hash[String, Puppet::Util::Metric]</code></td>
  <td>Map from metric category string to <code>Metric</code>.
      Failed reports contains no metrics. In an <code>inspect</code> report, there is an additional
      <code>inspect</code> metric in the <code>time</code> category. The particular set of metrics
      in a report os a fixed set. See <code>Puppet::Util::Metric</code> below for more information
      about metrics and its content.
  </td>
</tr>
<tr>
  <td>resource_statuses</td>
  <td><code>Hash[String, Puppet::Resource::Status]</code></td>
  <td>Map from resource name, to <code>Status</code></td>
</tr>
<tr>
  <td>configuration_version</td>
  <td><code>String, Integer</code></td>
  <td>The configuration version of the Puppet run. This is a <code>String</code> if the user
      has specified their own versioning scheme, otherwise an <code>Integer</code> representing
      seconds since the epoch.
  </td>
</tr>
<tr>
  <td>report_format</td>
  <td><code>Integer<code></td>
  <td>3 (<i>the report format version documented in this document</i>)</td>
</tr>
<tr>
  <td>puppet_version</td>
  <td><code>String<code></td>
  <td>The version of the Puppet Agent the report is for.</td>
</tr>
<tr>
  <td>kind</td>
  <td><code>String<code></td>
  <td>Enumerator; one of the values:
    <ul>
      <li><code>"inspect"</code>, if this report came from a <code>puppet inspect</code> run</li>
      <li><code>"apply"</code>, if this report came from a <code>puppet apply</code> run</li>
    </ul>
  </td>
</tr>
<tr>
  <td>status</td>
  <td><code>String<code></td>
  <td>Enumerator; one of the values:
    <ul>
      <li><code>"failed"</code>, if run failed</li>
      <li><code>"changed"</code>, if something changed</li>
      <li><code>"unchanged"</code>, if nothing changed from the previous run</li>
    </ul>
  </td>
</tr>
<tr>
  <td>environment</td>
  <td><code>String<code></td>
  <td>The name of the environment that was used for the puppet run (e.g. <code>"production"</code>).
      (<i>This was added in Report format 3</i>).</td>
</tr>
</table>


Puppet::Util::Log
-----------------
<table>
<tr>
  <th>name</th>
  <th>type</th>
  <th>description</th>
</tr>
<tr>
  <td>file</td>
  <td><code>String</code></td>
  <td>The pathname of the manifest file that triggered the log message. (Not always present in the data).
  </td>
</tr>
<tr>
  <td>line</td>
  <td><code>Integer</code></td>
  <td>The line number in the manifest which triggered the log message. (Not always present in the data).
  </td>
</tr>
<tr>
  <td>level</td>
  <td><code>Symbol</code></td>
  <td>Severity of the message. Possible values are
      <ul>
      <li><code>:debug<code></li>
      <li><code>:info`</li>
      <li><code>:notice</code></li>
      <li><code>:warning</code></li>
      <li><code>:err</code></li>
      <li><code>:emerg</code></li>
      <li><code>:crit</code></li>
      </ul>
      <pre>NOTE: are these described somewhere?</pre></td>
</tr>
<tr>
  <td>message</td>
  <td><code>String</code></td>
  <td>The message itself</td>
</tr>
<tr>
  <td>source</td>
  <td><code>String</code></td>
  <td>The origin of the log message. This could be a resource, a property of the resource or
      the string "Puppet".
      <blockquote>NOTE: ?? In which format is a resource or a property of a resource encoded?? is it
                  File[title]? What a about a property?
      </blockquote>
  </td>
</tr>
<tr>
  <td>tags</td>
  <td><code>Arra[String[, Integer]</code></td>
  <td>An array of tags.
      <blockquote> The tags of what?
      </blockquote>
  </td>
</tr>
<tr>
  <td>time</td>
  <td><code>DateTime<code></td>
  <td>When the message was sent.</td>
</tr>
</table>

Puppet::Util::Metric
--------------------
A `Puppet::Util::Metric` object represents all the metrics in a single *category*. It's name must
correspond to the key it is stored under in the report.
    
<table>
<tr>
  <th>name</th>
  <th>type</th>
  <th>description</th>
</tr>
<tr>
  <td>name</td>
  <td><code>String</code></td>
  <td>The name of the *metric category*. This is the same as they key associated with this
      metric in the hash of the <code>Puppet::Transaction::Report</code>. It is one of
      the values <code>time</code>, <code>resource</code>, or <code>events</code>
      See below for a description of each metrics category.
  </td>
</tr>
<tr>
  <td>label</td>
  <td><code>String</code></td>
  <td>This is the "titleized" version of the name, which means underscores are replaced with spaces
      and the first word is Capitalized.
      <blockquote>The statement is about how this is serialized by the Metric object. More interesting
                  is to know where this is used and how. Must it be set to the "titlelized" version
                  of the name? (Nothing surprises me in Puppet anymore...)
      </blockquote>
  </td>
</tr>
<tr>
  <td>values</td>
  <td><code>Array[Array[String, String, Numeric]]</code></td>
  <td>All the metric values within this category. Each element is on the form
      <code>[name, titleized_name, value]</code>,
      where <code>name</code> is the name of the particular metric, <code>titleized_name</code> is
      the "titleized" name (as described for the attribute <code>label</code>), and value is the quantity
      (an <code>Integer</code>, or a <code>Float</code>)
  </td>
</tr>
</table>

### time category
In the `time` category, there is a metric for every resource type for which there is a least one resource
in the catalog, plus two additional metrics, called `config_retrieval`, and `total`. Each value in the `time` category is a `Float`.

In an `inspect` report, there is an additional `inspect` metric in this category.

### resource category
In the `resource` category, the metrics are `failed`, `out_of_sync`, `changed`, and `total`. Each value
in the category is an `Integer`.

    NOTE: ?? And what does it represent? The number of what? (counts of resource of each metric kind?)

### events category
In the `events` category, there are up to five `Integer` metrics, present if their value is non zero:
* `success`
* `failure`
* `audit`
* `noop`
* `total`, always present

    NOTE?? And what do they represent? Count of resources in the metric?

Puppet::Resource::Status
------------------------
A `Puppet::Resource::Status` object represents the status of a single resource.
    
<table>
<tr>
  <th>name</th>
  <th>type</th>
  <th>description</th>
</tr>
<tr>
  <td>resource_type</td>
  <td><code>String</code></td>
  <td>The resource type, capitalized.</td>
</tr>
<tr>
  <td>title</td>
  <td><code>String</code></td>
  <td>The resource title.</td>
</tr>
<tr>
  <td><del>resource</del></td>
  <td><code>String</code></td>
  <td><i>Deprecated</i><br/>
      The resource name, in the form <code>Type[title]</code>.
      This is always the same as the key corresponding to this  
      <code>Puppet::Resource::Status</code> object in the <code>resource_statuses</code> hash. 
  </td>
</tr>
<tr>
  <td>file</td>
  <td><code>String</code></td>
  <td>The pathname of the manifest file which declared the resource.</td>
</tr>
<tr>
  <td>line</td>
  <td><code>Integer</code></td>
  <td>The line number in the manifest file which declared the resource.</td>
</tr>
<tr>
  <td>evaluation_time</td>
  <td><code>Float</code></td>
  <td>The amount of time, in seconds, taken to evaluate the resource.
      Not present in <code>inspect</code> reports.
  </td>
</tr>
<tr>
  <td>change_count</td>
  <td><code>Integer</code></td>
  <td>The number of properties which changed. Always 0 in <code>inspect</code> reports.</td>
</tr>
<tr>
  <td>out_of_sync_count</td>
  <td><code>Integer</code></td>
  <td>The number of properties which were out of sync. Always 0 in <code>inspect</code> reports.</td>
</tr>
<tr>
  <td>tags</td>
  <td><code>Array[String>]</code></td>
  <td>The strings with which the resource is tagged.</td>
</tr>
<tr>
  <td>time</td>
  <td><code>DateTime</code></td>
  <td>the time at which the resource was evaluated</td>
</tr>
<tr>
  <td>events</td>
  <td><code>Array[Puppet::Transaction::Event]</code></td>
  <td>The <code>Puppet::Transaction::Event</code> objects for the resource.</td>
</tr>
<tr>
  <td><del>out_of_sync</del></td>
  <td><code>Boolean</code></td>
  <td><i>Deprecated</i><br/>
      <code>true</code> if <code>out_of_sync_count</code> &gt; 0, otherwise <code>false</code>.
  </td>
</tr>
<tr>
  <td><del>changed</del></td>
  <td><code>Boolean</code></td>
  <td><i>Deprecated</i><br/>
      <code>true</code> if <code>change_count</code> &gt; 0, otherwise <code>false</code>.
  </td>
</tr>
<tr>
  <td>skipped</td>
  <td><code>Boolean</code></td>
  <td>True if the resource was skipped, otherwise false.</td>
</tr>
<tr>
  <td><del>failed</del></td>
  <td><code>Boolean</code></td>
  <td><i>Deprecated</i><br/>
      True if Puppet experienced an error while evaluating this resource, otherwise false.
  </td>
</tr>
</table>

Puppet::Transaction::Event
--------------------------
A `Puppet::Transaction::Event` object represents a single event for a single resource.

    NOTE ?? The data type of the entries that are String, Array or Hash below is not fully known?
    What can be in the arrays and hashes? Any String, Array, Hash? (to any nesting level?)
    
<table>
<tr>
  <th>name</th>
  <th>type</th>
  <th>description</th>
</tr>
<tr>
  <td>audited</td>
  <td><code>Boolean</code></td>
  <td><code>true</code> if this property is being audited, otherwise <code>false</code>.
      Always <code>true</code> in inspect reports.</td>
</tr>
<tr>
  <td>property</td>
  <td><code>String</code></td>
  <td>The property for which the event occurred.</td>
</tr>
<tr>
  <td>previous_value</td>
  <td><code>String</code>, <code>Array[?]</code>, or <code>Hash[?,?]</code></td>
  <td>The value of the property before the change (if any) was applied.</td>
</tr>
<tr>
  <td>desired_value</td>
  <td><code>String</code>, <code>Array[?]</code>, or <code>Hash[?,?]</code></td>
  <td>The value specified in the manifest. Absent in <code>inspect</code> reports.</td>
</tr>
<tr>
  <td>historical_value</td>
  <td><code>String</code>, <code>Array[?]</code>, or <code>Hash[?,?]</code></td>
  <td>The audited value from a previous run of Puppet, if known. Otherwise <code>nil</code>.
      Absent in <code>inspect</code> reports.
  </td>
</tr>
<tr>
  <td>message</td>
  <td><code>String</code></td>
  <td>The log message generated by this event.</td>
</tr>
<tr>
  <td>name</td>
  <td><code>Symbol</code></td>
  <td>The name of the event. Absent in <code>inspect</code> reports.</td>
</tr>
<tr>
  <td>status</td>
  <td><code>String</code></td>
  <td>One of the following strings (depending on the type of the event (see below)):
      <ul>
      <li><code>success</code></li>
      <li><code>failure</code></li>
      <li><code>noop</code></li>
      <li><code>audit</code></li>
      </ul>
      Always <code>audit</code> in <code>inspect</code> reports.
  </td>
</tr>
<tr>
  <td>time</td>
  <td><code>DateTime</code></td>
  <td>The time at which the property was evaluated.</td>
</tr>
</table>

