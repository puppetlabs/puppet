0.9.2
-----

- fixed error w/ parsing "!" when whitelisting tags
- fixed parsing of the number 0 (d'oh!)

0.9.1
-----

- added Yecht support (JRuby)
- more bug fixes

0.9.0
-----

- added `whitelist!` method for easily whitelisting tags
- added support for call-specific options
- removed deprecated methods

0.8.6
-----

- fixed bug in float matcher

0.8.5
-----

- performance improvements
- made less verbose by default
- bug fixes

0.8.4
-----

- enhancements to parsing of integers, floats, and dates
- updated built-in whitelist
- more bug fixes

0.8.3
-----

- fixed exception on parsing empty document
- fixed handling of octal & hexadecimal numbers

0.8.2
-----

- bug fixes

0.8.1
-----

- added `:raise_on_unknown_tag` option
- renamed `reset_defaults!` to `restore_defaults!`

0.8
---

- added tag whitelisting
- more API changes

0.7
---

- separated YAML engine support from Ruby version
- added support for binary scalars
- numerous bug fixes and enhancements

0.6
---

- several API changes
- added `SafeYAML::OPTIONS` for specifying default behavior

0.5
---

Added support for dates

0.4
---

- efficiency improvements
- made `YAML.load` use `YAML.safe_load` by default
- made symbol deserialization optional

0.3
---

Added Syck support

0.2
---

Added support for:

- anchors & aliases
- booleans
- nils

0.1
---

Initial release
