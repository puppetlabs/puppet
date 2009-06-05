# Jeff McCune <jeff.mccune@northstarlabs.net>
#
# Demonstration of a custom parser function and erb template within
# a module, working in concert.

class sample-module {
  $fqdn_to_dn = hostname_to_dn($domain)
  $sample_template = template("sample-module/sample.erb")

  notice("hostname_to_dn module function returned: [$fqdn_to_dn]")
  info("sample.erb looks like:\n$sample_template")
}
