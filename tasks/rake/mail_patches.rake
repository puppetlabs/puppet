desc "Send patch information to the puppet-dev list"
task :mail_patches do
    if Dir.glob("00*.patch").length > 0
        raise "Patches already exist matching '00*.patch'; clean up first"
    end

    unless %x{git status} =~ /On branch (.+)/
        raise "Could not get branch from 'git status'"
    end
    branch = $1

    unless branch =~ %r{^([^\/]+)/([^\/]+)/([^\/]+)$}
        raise "Branch name does not follow <type>/<parent>/<name> model; cannot autodetect parent branch"
    end

    type, parent, name = $1, $2, $3

    # Create all of the patches
    sh "git format-patch -C -M -s -n --subject-prefix='PATCH/puppet' #{parent}..HEAD"

    # And then mail them out.

    # If we've got more than one patch, add --compose
    if Dir.glob("00*.patch").length > 1
        compose = "--compose"
    else
        compose = ""
    end

    # Now send the mail.
    sh "git send-email #{compose} --no-signed-off-by-cc --suppress-from --to puppet-dev@googlegroups.com 00*.patch"

    # Finally, clean up the patches
    sh "rm 00*.patch"
end
