Committing changes to Puppet
====

We would like to make it easier for community members to contribute to Puppet
using pull requests, even if it makes the task of reviewing and committing
these changes a little harder.  Pull requests are only ever based on a single
branch, however, we maintain more than one active branch.  As a result
contributors should target their changes at the master branch. This makes the
process of contributing a little easier for the contributor since they don't
need to concern themselves with the question, "What branch do I base my changes
on?"  This is already called out in the [CONTRIBUTING.md](http://goo.gl/XRH2J).

Therefore, it is the responsibility of the committer to re-base the change set
on the appropriate branch which should receive the contribution.

The rest of this document addresses the concerns of the committer.  This
document will help guide the committer decide which branch to base, or re-base
a contribution on top of.  This document also describes our branch management
strategy, which is closely related to the decision of what branch to commit
changes into.

Terminology
====

Many of these terms have more than one meaning.  For the purposes of this
document, the following terms refer to specific things.

**contributor** - A person who makes a change to Puppet and submits a change
set in the form of a pull request.

**change set** - A set of discrete patches which combined together form a
contribution.  A change set takes the form of Git commits and is submitted to
Puppet in the form of a pull request.

**committer** - A person responsible for reviewing a pull request and then
making the decision what base branch to merge the change set into.

**base branch** - A branch in Git that contains an active history of changes
and will eventually be released using semantic version guidelines.  The branch
named master will always exist as a base branch.  All other base branches will
be associated with a specific released version of Puppet, e.g. 2.7.x and 3.0.x.

Committer Guide
====

This section provides a guide to follow while committing change sets to Puppet
base branches.

How to decide what release(s) should be patched
---

This section provides a guide to help a committer decide the specific base
branch that a change set should be merged into.

The latest minor release of a major release is the only base branch that should
be patched. Older minor releases in a major release do not get patched. Before
the switch to [semantic versions](http://semver.org/) committers did not have
to think about the difference between minor and major releases.  Committing to
the latest minor release of a major release is a policy intended to limit the
number of active base branches that must be managed.

Security patches are handled as a special case.  Security patches may be
applied to earlier minor releases of a major release.

How to commit a change set to multiple base branches
---

A change set may apply to multiple releases.  In this situation the change set
needs to be committed to multiple base branches.  This section provides a guide
for how to merge patches across releases, e.g. 2.7 is patched, how should the
changes be applied to 3.0?

First, merge the change set into the lowest numbered base branch, e.g. 2.7.
Next, merge the changed base branch up through all later base branches by using
the `--no-ff --log` git merge options.  We commonly refer to this as our "merge
up process" because we merge in once, then merge up multiple times.

When a new minor release branch is created (e.g. 3.1.x) then the previous one
is deleted (e.g. 3.0.x). Any security or urgent fixes that might have to be
applied to the older code line is done by creating an ad-hoc branch from the
tag of the last patch release of the old minor line.

Code review checklist
---

This section aims to provide a checklist of things to look for when reviewing a
pull request and determining if the change set should be merged into a base
branch:

 * All tests pass
 * Are there any platform gotchas? (Does a change make an assumption about
   platform specific behavior that is incompatible with other platforms?  e.g.
   Windows paths vs. POSIX paths.)
 * Is the change backwards compatible? (It should be)
 * Are there YARD docs for API changes?
 * Does the change set also require documentation changes? If so is the
   documentation being kept up to date?
 * Does the change set include clean code?  (software code that is formatted
   correctly and in an organized manner so that another coder can easily read
   or modify it.)  HINT: `git diff master --check`
 * Does the change set conform to the contributing guide?


Commit citizen guidelines:
---

This section aims to provide guidelines for being a good commit citizen by
paying attention to our automated build tools.

 * Don’t push on a broken build.  (A broken build is defined as a failing job
   in the [Puppet FOSS](https://jenkins.puppetlabs.com/view/Puppet%20FOSS/)
   page.)
 * Watch the build until your changes have gone through green
 * Update the ticket status and target version.  The target version field in
   our issue tracker should be updated to be the next release of Puppet.  For
   example, if the most recent release of Puppet is 3.1.1 and you merge a
   backwards compatible change set into master, then the target version should
   be 3.2.0 in the issue tracker.)
 * Ensure the pull request is closed (Hint: amend your merge commit to contain
   the string `closes: #123` where 123 is the pull request number.

Example Procedure
====

This section helps a committer rebase a contribution onto an earlier base
branch, then merge into the base branch and up through all active base
branches.

Suppose a contributor submits a pull request based on master.  The change set
fixes a bug reported against Puppet 3.1.1 which is the most recently released
version of Puppet.

In this example the committer should rebase the change set onto the 3.1.x
branch since this is a bug rather than new functionality.

First, the committer pulls down the branch using the `hub` gem.  This tool
automates the process of adding the remote repository and creating a local
branch to track the remote branch.

    $ hub checkout https://github.com/puppetlabs/puppet/pull/1234
    Branch jeffmccune-fix_foo_error set up to track remote branch fix_foo_error from jeffmccune.
    Switched to a new branch 'jeffmccune-fix_foo_error'

At this point the topic branch is a descendant of master, but we want it to
descend from 3.1.x.  The committer creates a new branch then re-bases the
change set:

    $ git branch bug/3.1.x/fix_foo_error
    $ git rebase --onto 3.1.x master bug/3.1.x/fix_foo_error
    First, rewinding head to replay your work on top of it...
    Applying: (#23456) Fix FooError that always bites users in 3.1.1

The `git rebase` command may be interpreted as, "First, check out the branch
named `bug/3.1.x/fix_foo_error`, then take the changes that were previously
based on `master` and re-base them onto `3.1.x`.

Now that we have a topic branch containing the change set based on the correct
release branch, the committer merges in:

    $ git checkout 3.1.x
    Switched to branch '3.1.x'
    $ git merge --no-ff --log bug/3.1.x/fix_foo_error
    Merge made by the 'recursive' strategy.
     foo | 0
     1 file changed, 0 insertions(+), 0 deletions(-)
     create mode 100644 foo

Once merged into the first base branch, the committer merges up:

    $ git checkout master
    Switched to branch 'master'
    $ git merge --no-ff --log 3.1.x
    Merge made by the 'recursive' strategy.
     foo | 0
     1 file changed, 0 insertions(+), 0 deletions(-)
     create mode 100644 foo

Once the change set has been merged "in and up." the committer pushes.  (Note,
the checklist should be complete at this point.)  Note that both the 3.1.x and
master branches are being pushed at the same time.

    $ git push puppetlabs master:master 3.1.x:3.1.x

That's it!  The committer then updates the pull request, updates the issue in
our issue tracker, and keeps an eye on the build status.
