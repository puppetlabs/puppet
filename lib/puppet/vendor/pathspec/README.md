pathspec-ruby
=============

Match Path Specifications, such as .gitignore, in Ruby!

Follows .gitignore syntax defined on [gitscm](https://git-scm.com/docs/gitignore)

.gitignore functionality ported from [Python pathspec](https://pypi.python.org/pypi/pathspec/0.2.2) by [@cpburnz](https://github.com/cpburnz/python-path-specification)

[Travis Status](https://travis-ci.org/highb/pathspec-ruby) ![Travis CI Status](https://travis-ci.org/highb/pathspec-ruby.svg?branch=master)

## Build/Install from Rubygems
```shell
gem install pathspec
```

## Usage
```ruby
require 'pathspec'

# Create a .gitignore-style Pathspec by giving it newline separated gitignore
# lines, an array of gitignore lines, or any other enumable object that will
# give strings matching the .gitignore-style (File, etc.)
gitignore = Pathspec.new File.read('.gitignore', 'r')

# Our .gitignore in this example contains:
# !**/important.txt
# abc/**

# true, matches "abc/**"
gitignore.match 'abc/def.rb'

# false, because it has been negated using the line "!**/important.txt"
gitignore.match 'abc/important.txt'

# Give a path somewhere in the filesystem, and the Pathspec will return all
# matching files underneath.
# Returns ['/src/repo/abc/', '/src/repo/abc/123']
gitignore.match_tree '/src/repo'

# Give an enumerable of paths, and Pathspec will return the ones that match.
# Returns ['/abc/123', '/abc/']
gitignore.match_paths ['/abc/123', '/abc/important.txt', '/abc/']
```

## Building/Installing from Source
```shell
git clone git@github.com:highb/pathspec-ruby.git
cd pathspec-ruby && bash ./build_from_source.sh
```

## Contributing
Pull requests, bug reports, and feature requests welcome! :smile: I've tried to write exhaustive tests but who knows what cases I've missed.
