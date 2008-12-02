# Mac MCX Test

computer { "localhost": }

mcx {
  "/Groups/mcx_dock":
    ensure  => "present",
    content => 'invalid plist'
}
