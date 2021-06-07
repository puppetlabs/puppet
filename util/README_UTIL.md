Development Utilities
=====================

The scripts in this directory are utility scripts useful during development.

binary_search_specs.rb
----------------------

This script, written by Nick Lewis, is useful if you encounter a spec failure which only occurs when run in some sequence with other specs.  If you have a spec which passes by itself, but fails when run with the full spec suite, this script will help track it down.

The puppet spec/spec_helper.rb checks for an environment variable LOG_SPEC_ORDER.  If this is present, it will save the current order of the spec files to './spec_order.txt'.

This file is then used by binary_search_specs.rb so that:

    $ ./util/binary_search_specs.rb spec/unit/foo_spec.rb

will begin bisecting runs before and after this spec until it narrows down to a candidate which seems to be effecting foo_spec.rb and causing it to fail.

### with parallel-spec

To get the groups that the parallel task is running, run: be util/rspec_grouper 1000. Then run each spit out file with "be util/rspec_runner <groupfile>". If it fails, rename it to spec_order.txt and run the binary script.

### Curl

For simple cases of testing REST API via curl:

* edit ~/tests/master/:confdir/auth.conf and add `"allow *"` to `"path /"`

Now you should be able to:

```bash
jpartlow@percival:~/work/puppet$ curl -k -H 'Accept: text/pson' https://puppetmaster:8140/main/resource/user/nobody
{"type":"User","title":"nobody","tags":["user","nobody"],"exported":false,"parameters":{"ensure":"present","home":"/nonexistent","uid":65534,"gid":65534,"comment":"nobody","shell":"/bin/sh","groups":[],"expiry":"absent","provider":"useradd","membership":"minimum","role_membership":"minimum","auth_membership":"minimum","profile_membership":"minimum","key_membership":"minimum","attribute_membership":"minimum","loglevel":"notice"}}
```

For more complex authorization cases you will need to reference the agents keys:

```bash
jpartlow@percival:~/work/puppet$ curl -H 'Accept: text/pson' --cert `puppet agent --configprint hostcert` --key `be puppet agent --configprint hostprivkey` --cacert `be puppet agent --configprint localcacert` https://puppetmaster:8140/foo/node/percival.corp.puppetlabs.net
```
