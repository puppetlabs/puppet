function environment::data() {
  {
     a => 'This is A',
     b => 'This is B',
     c => "This is ${if $cx == undef { 'C from data.pp' } else { $cx }}",
     lookup_options => {
        a => 'first'
     }
  }
}
