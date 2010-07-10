require 'autotest'
require 'autotest/rspec'

Autotest.add_hook :initialize do |at|
  at.clear_mappings

  # the libraries under lib/puppet
  at.add_mapping(%r{^lib/puppet/(.*)\.rb$}) { |filename, m|
    at.files_matching %r!spec/(unit|integration)/#{m[1]}.rb!
  }

  # the actual spec files themselves
  at.add_mapping(%r{^spec/(unit|integration)/.*\.rb$}) { |filename, _|
    filename
  }

  # force a complete re-run for all of these:

  # main puppet lib
  at.add_mapping(%r{^lib/puppet\.rb$}) { |filename, _|
    at.files_matching %r{spec/(unit|integration)/.*\.rb}
  }

  # the spec_helper
  at.add_mapping(%r{^spec/spec_helper\.rb$}) { |filename, _|
    at.files_matching %r{spec/(unit|integration)/.*\.rb}
  }

  # the puppet test libraries
  at.add_mapping(%r{^test/lib/puppettest/.*}) { |filename, _|
    at.files_matching %r{spec/(unit|integration)/.*\.rb}
  }

    # the puppet spec libraries
  at.add_mapping(%r{^spec/lib/spec.*}) { |filename, _|
    at.files_matching %r{spec/(unit|integration)/.*\.rb}
  }

    # the monkey patches for rspec
  at.add_mapping(%r{^spec/lib/monkey_patches/.*}) { |filename, _|
    at.files_matching %r{spec/(unit|integration)/.*\.rb}
  }
end

# a place for overrides when necessary.
class Autotest::PuppetRspec < Autotest::Rspec
  def spec_commands
    ENV["AUTOTEST"] = "true"
    ENV["PATH"].split(File::PATH_SEPARATOR).collect { |dir| File.join(dir, "spec") }
  end
end
