---
layout: default
built_from_commit: 942adce0b1b70f696b0f09d7109ded7559f0fa33
title: 'Resource Type: schedule'
canonical: "/puppet/latest/types/schedule.html"
---

# Resource Type: schedule

> **NOTE:** This page was generated from the Puppet source code on 2024-08-28 16:45:59 -0700



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

Allowed values:

* `hourly`
* `daily`
* `weekly`
* `monthly`
* `never`

([↑ Back to schedule attributes](#schedule-attributes))


#### periodmatch {#schedule-attribute-periodmatch}

Whether periods should be matched by a numeric value (for instance,
whether two times are in the same hour) or by their chronological
distance apart (whether two times are 60 minutes apart).

Default: `distance`

Allowed values:

* `number`
* `distance`

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

Default: `1`

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





