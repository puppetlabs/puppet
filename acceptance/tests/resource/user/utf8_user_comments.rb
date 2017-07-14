# Ensure a user can be managed with UTF-8 comment value. The comment value is
# normally used for "Full Name" so this is important in a UTF-8 context.
# We should be able to:
# - create a new user with a UTF-8 comment
# - modify an existing UTF-8 comment to a new UTF-8 comment
# - modify an existing UTF-8 comment to an ASCII comment
# - create a new user with an ASCII comment
# - modify an existing ASCII comment to a UTF-8 one
# Where applicable, we should be able to do this in different locales
test_name 'PUP-6777 Manage users with UTF-8 comments' do

  tag 'audit:high',
      'audit:acceptance' # Could be done as integration tests, but would
                         # require changing the system running the test
                         # in ways that might require special permissions
                         # or be harmful to the system running the test

  # PUP-7049 / ARISTA-42 - user provider bug on Arista
  # AIX providers are separate from most other platforms,
  # and have not been made unicode-aware yet.
  confine :except, :platform => /^(eos|aix)-/

  user0 = "foo#{rand(99999).to_i}"
  user1 = "bar#{rand(99999).to_i}"
  user2 = "baz#{rand(99999).to_i}"
  user3 = "qux#{rand(99999).to_i}"
  user4 = "ris#{rand(99999).to_i}"
  osx_agents = agents.select { |a| a[:platform] =~ /osx/ } || []
  windows_agents = agents.select { |a| a[:platform] =~ /windows/ } || []

  # different UTF-8 widths
  # 1-byte A
  # 2-byte ۿ - http://www.fileformat.info/info/unicode/char/06ff/index.htm - 0xDB 0xBF / 219 191
  # 3-byte ᚠ - http://www.fileformat.info/info/unicode/char/16A0/index.htm - 0xE1 0x9A 0xA0 / 225 154 160
  # 4-byte 𠜎 - http://www.fileformat.info/info/unicode/char/2070E/index.htm - 0xF0 0xA0 0x9C 0x8E / 240 160 156 142
  mixed_utf8_0 = "A\u06FF"
  reported_mixed_utf8_0 = '\'A\u{6FF}\''
  mixed_utf8_1 = "\u16A0\u{2070E}"
  reported_mixed_utf8_1 = '\'\u{16A0}\u{2070E}\''

  teardown do
    # remove user on all agents
    teardown_manifest = <<-EOF
      user { ['#{user0}','#{user1}','#{user2}','#{user3}','#{user4}']: ensure => absent }
    EOF
    apply_manifest_on(agents, teardown_manifest, :environment => {:LANG => "en_US.UTF-8"})
  end

  step "ensure user can be created with UTF-8 comment (with UTF-8 environment on *nix)" do
    create_user = <<-EOF
      user { '#{user0}':
        ensure  => present,
        comment => '#{mixed_utf8_0}',
      }
    EOF
    # Note setting LANG='<encoding>' environment like this has no effect on Windows agents.
    apply_manifest_on(agents, create_user, :expect_changes => true, :environment => {:LANG => "en_US.UTF-8"})
  end

  step "ensure UTF-8 comment can be changed (with UTF-8 environment on *nix)" do
    set_comment_utf8 = <<-EOF
      user { '#{user0}':
        comment => '#{mixed_utf8_1}',
      }
    EOF
    # Note setting LANG='<encoding>' environment like this has no effect on Windows agents.
    apply_manifest_on(agents, set_comment_utf8, :expect_changes => true, :environment => {:LANG => "en_US.UTF-8"}) do |result|
      assert_match(/changed #{reported_mixed_utf8_0} to #{reported_mixed_utf8_1}/, result.stdout, "failed to modify UTF-8 user comment in UTF-8 environment")
    end
  end

  # *NIX and OSX should also work with ISO-8859-1 (at least, let's make sure we don't regress)
  step "ensure user can be created with UTF-8 comment (with ISO-8859-1 environment on *nix)" do
    create_user = <<-EOF
      user { '#{user1}':
        ensure  => present,
        comment => '#{mixed_utf8_0}',
      }
    EOF
    # Since LANG=<'encoding'> has no effect, this test is redundant on Windows - exclude it.
    apply_manifest_on(agents - windows_agents, create_user, :expect_changes => true, :environment => {:LANG => "en_US.ISO8859-1"})
  end

  step "ensure UTF-8 comment can be changed (with ISO-8859-1 environment on *nix)" do
    set_comment_utf8 = <<-EOF
      user { '#{user1}':
        comment => '#{mixed_utf8_1}',
      }
    EOF
    # Since LANG=<'encoding'> has no effect, this test is redundant on Windows - exclude it.
    apply_manifest_on(agents - windows_agents, set_comment_utf8, :expect_changes => true, :environment => {:LANG => "en_US.ISO8859-1"}) do |result|
      assert_match(/changed #{reported_mixed_utf8_0} to #{reported_mixed_utf8_1}/, result.stdout, "failed to modify UTF-8 user comment in ISO-8859-1 environment")
    end
  end

  step "ensure user can be created with UTF-8 comment (with POSIX locale on *nix)" do
    create_user = <<-EOF
      user { '#{user2}':
        ensure  => present,
        comment => '#{mixed_utf8_0}',
      }
    EOF
    # OS X is known broken in POSIX locale with UTF-8 chars on OS X, so exclude OS X here.
    # Also since LANG=<'encoding'> has no effect, this test is redundant on Windows - exclude it.
    apply_manifest_on(agents - osx_agents - windows_agents, create_user, :expect_changes => true, :environment => {:LANG => "POSIX"})
  end

  step "ensure UTF-8 comment can be modifed (with POSIX locale on *nix)" do
    set_comment_utf8 = <<-EOF
      user { '#{user2}':
        ensure  => present,
        comment => '#{mixed_utf8_1}',
      }
    EOF
    # OS X is known broken in POSIX locale with UTF-8 chars on OS X, so exclude OS X here.
    # Also since LANG=<'encoding'> has no effect, this test is redundant on Windows - exclude it.
    apply_manifest_on(agents - osx_agents - windows_agents, set_comment_utf8, :expect_changes => true, :environment => {:LANG => "POSIX"}) do |result|
      assert_match(/changed #{reported_mixed_utf8_0} to #{reported_mixed_utf8_1}/, result.stdout, "failed to modify UTF-8 user comment with POSIX environment")
    end
  end

  step "ensure user can be created with ASCII comment (with POSIX locale on *nix)" do
    create_user = <<-EOF
      user { '#{user3}':
        ensure => present,
        comment => 'bar',
      }
    EOF

    # While setting LANG='<encoding>' environment like this has no effect on
    # Windows agents, we still want to run this and the following tests on Windows
    # because we want to ensure we can set create/modify ASCII comments to UTF-8
    # and back.
    # OS X is known broken in POSIX locale with UTF-8 chars on OS X, so exclude OS X here.
    apply_manifest_on(agents - osx_agents, create_user, :expect_changes => true, :environment => {:LANG => "POSIX"})
  end


  # This test is important because of ruby's Etc.getpwnam behavior which returns
  # strings in current locale if compatible - make sure we can get a system
  # value in POSIX and compare it to incoming from puppet in UTF-8.
  step "ensure ASCII comment can be modified to UTF-8 comment (with POSIX locale on *nix)" do
    set_comment_utf8 = <<-EOF
      user { '#{user3}':
        comment => '#{mixed_utf8_0}',
      }
    EOF
    # While setting LANG='<encoding>' environment like this has no effect on
    # Windows agents, we still want to run this and the following tests on Windows
    # because we want to ensure we can set create/modify ASCII comments to UTF-8
    # and back.
    # OS X is known broken in POSIX locale with UTF-8 chars on OS X, so exclude OS X here.
    apply_manifest_on(agents - osx_agents, set_comment_utf8, :expect_changes => true, :environment => {:LANG => "POSIX"}) do |result|
      assert_match(/changed 'bar' to #{reported_mixed_utf8_0}/, result.stdout, "failed to modify user ASCII comment to UTF-8 comment with POSIX locale")
    end
  end

  step "create another user with UTF-8 comment (with POSIX locale on *nix)" do
    create_user = <<-EOF
      user { '#{user4}':
        ensure => present,
        comment => '#{mixed_utf8_0}',
      }
    EOF
    # While setting LANG='<encoding>' environment like this has no effect on
    # Windows agents, we still want to run this and the following tests on Windows
    # because we want to ensure we can set create/modify ASCII comments to UTF-8
    # and back.
    # OS X is known broken in POSIX locale with UTF-8 chars on OS X, so exclude OS X here.
    apply_manifest_on(agents - osx_agents, create_user, :expect_changes => true, :environment => {:LANG => "POSIX"})
  end


  step "ensure UTF-8 comment can be modified to ASCII comment (with POSIX locale on *nix)" do
    set_comment_ascii = <<-EOF
      user { '#{user4}':
        comment => 'bar',
      }
    EOF
    # While setting LANG='<encoding>' environment like this has no effect on
    # Windows agents, we still want to run this on Windows because we want to
    # ensure we can set create/modify ASCII comments to UTF-8 and back.
    # OS X is known broken in POSIX locale with UTF-8 chars, so exclude OS X here
    apply_manifest_on(agents - osx_agents, set_comment_ascii, :expect_changes => true, :environment => {:LANG => "POSIX"}) do |result|
      assert_match(/changed #{reported_mixed_utf8_0} to 'bar'/, result.stdout, "failed to modify user UTF-8 comment to ASCII comment with POSIX locale")
    end
  end
end
