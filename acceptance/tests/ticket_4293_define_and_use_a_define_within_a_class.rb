# 2010-07-22 Jeff McCune <jeff@puppetlabs.com>
#
# AffectedVersion: 2.6.0rc4
# FixedVersion: 2.6.0
#
# Description: using a defined type in the class it's declared in
# causes an error.

tag 'audit:high', # basic language functionality
    'audit:unit',
    'audit:refactor', # Use block style `test_name`
    'audit:delete'

manifest = <<PP
class foo {
  define do_notify($msg) {
    notify { "Message for $name: $msg": }
  }
  foo::do_notify { "test_one": msg => "a_message_for_you" }
}
include foo
PP

agents.each do |host|
  apply_manifest_on(host, manifest) do
    assert_match(/.*?Foo::Do_notify.*?a_message_for_you/, stdout, "the notification didn't show up in stdout on #{host}")
  end
end
