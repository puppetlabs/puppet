# 2010-07-22 Jeff McCune <jeff@puppetlabs.com>
#
# AffectedVersion: 2.6.0rc4
# FixedVersion: 2.6.0
#
# Description: using a defined type in the class it's declared in
# causes an error.

manifest = <<PP
class foo {
  define do_notify($msg) {
    notify { "Message for $name: $msg": }
  }
  do_notify { "test_one": msg => "a_message_for_you" }
}
include foo
PP

apply_manifest_on(agents, manifest) do
  stdout =~ /notice.*?Foo::Do_notify.*?a_message_for_you/ or
    fail_test("the notification didn't show up in stdout")
end
