Committing changes to Puppet
====

We would like to make it easier for community members to contribute to Puppet
using pull requests, even if it makes the task of reviewing and committing
these changes a little harder.  Pull requests are only ever based on a single
branch, however, we maintain more than one active branch.  As a result
contributors should target their changes at the master branch. This makes the
process of contributing a little easier for the contributor since they don't
need to concern themselves with the question, "What branch do I base my changes
on?"  This is already called out in the [CONTRIBUTING.md](https://goo.gl/XRH2J).

Therefore, it is the responsibility of the committer to re-base the change set
on the appropriate branch which should receive the contribution.

It is also the responsibility of the committer to review the change set in an
effort to make sure the end users must opt-in to new behavior that is
incompatible with previous behavior.  We employ the use of [feature
flags](https://stackoverflow.com/questions/7707383/what-is-a-feature-flag) as
the primary way to achieve this user opt-in behavior.  Finally, it is the
responsibility of the committer to make sure the `master` and `stable` branches
are both clean and working at all times.  Clean means that dead code is not
allowed, everything needs to be usable in some manner at all points in time.
Stable is not an indication of the build status, but rather an expression of
our intent that the `stable` branch does not receive new functionality.

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
named `master` will always exist as a base branch.  The other base branches are
`stable`, and `security` described below.

**master branch** - The branch where new functionality that are not bug fixes
is merged.

**stable branch** - The branch where bug fixes against the latest release or
release candidate are merged.

**security** - Where critical security fixes are merged.  These change sets
will then be merged into release branches independently from one another. (i.e.
no merging up).  Please do not submit pull requests against the security branch
and instead report all security related issues to security@puppetlabs.com as
per our security policy published at
[https://puppetlabs.com/security/](https://puppetlabs.com/security/).

Committer Guide
====

This section provides a guide to follow while committing change sets to Puppet
base branches.

How to decide what release(s) should be patched
---

This section provides a guide to help a committer decide the specific base
branch that a change set should be merged into.

The latest minor release of a major release is the only base branch that should
be patched.  These patches will be merged into `master` if they contain new
functionality.  They will be merged into `stable` and `master` if they fix a
critical bug.  Older minor releases in a major release do not get patched.

Before the switch to [semantic versions](http://semver.org/) committers did not
have to think about the difference between minor and major releases.
Committing to the latest minor release of a major release is a policy intended
to limit the number of active base branches that must be managed.

Security patches are handled as a special case.  Security patches may be
applied to earlier minor releases of a major release, but the patches should
first be merged into the `security` branch.  Security patches should be merged
by Puppet Labs staff members.  Pull requests should not be submitted with the
security branch as the base branch.  Please send all security related
information or patches to security@puppetlabs.com as per our [Security
Policy](https://puppetlabs.com/security/).

The CI systems are configured to run against `master` and `stable`.  Over time,
these branches will refer to different versions, but their name will remain
fixed to avoid having to update CI jobs and tasks as new versions are released.

How to commit a change set to multiple base branches
---

A change set may apply to multiple branches, for example a bug fix should be
applied to the stable release and the development branch.  In this situation
the change set needs to be committed to multiple base branches.  This section
provides a guide for how to merge patches into these branches, e.g.
`stable` is patched, how should the changes be applied to `master`?

First, rebase the change set onto the `stable` branch.  Next, merge the change
set into the `stable` branch using a merge commit.  Once merged into `stable`,
merge the same change set into `master` without doing a rebase as to preserve
the commit identifiers.  This merge strategy follows the [git
flow](http://nvie.com/posts/a-successful-git-branching-model/) model.  Both of
these change set merges should have a merge commit which makes it much easier
to track a set of commits as a logical change set through the history of a
branch.  Merge commits should be created using the `--no-ff --log` git merge
options.

Any merge conflicts should be resolved using the merge commit in order to
preserve the commit identifiers for each individual change.  This ensures `git
branch --contains` will accurately report all of the base branches which
contain a specific patch.

Using this strategy, the stable branch need not be reset.  Both `master` and
`stable` have infinite lifetimes.  Patch versions, also known as bug fix
releases, will be tagged and released directly from the `stable` branch.  Major
and minor versions, also known as feature releases, will be tagged and released
directly from the `master` branch.  Upon release of a new major or minor
version all of the changes in the `master` branch will be merged into the
`stable` branch.

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
   the string `closes #123` where 123 is the pull request number and github
   will automatically close the pull request when the branch is pushed.)

Example Procedure
====

This section helps a committer rebase a contribution onto an earlier base
branch, then merge into the base branch and up through all active base
branches.

Suppose a contributor submits a pull request based on master.  The change set
fixes a bug reported against Puppet 3.1.1 which is the most recently released
version of Puppet.

In this example the committer should rebase the change set onto the `stable`
branch since this is a bug rather than new functionality.

First, the committer pulls down the branch using the `hub` gem.  This tool
automates the process of adding the remote repository and creating a local
branch to track the remote branch.

    $ hub checkout https://github.com/puppetlabs/puppet/pull/1234
    Branch jeffmccune-fix_foo_error set up to track remote branch fix_foo_error from jeffmccune.
    Switched to a new branch 'jeffmccune-fix_foo_error'

At this point the topic branch is a descendant of master, but we want it to
descend from `stable`.  The committer rebases the change set onto `stable`.

    $ git branch bug/stable/fix_foo_error
    $ git rebase --onto stable master bug/stable/fix_foo_error
    First, rewinding head to replay your work on top of it...
    Applying: (#23456) Fix FooError that always bites users in 3.1.1

The `git rebase` command may be interpreted as, "First, check out the branch
named `bug/stable/fix_foo_error`, then take the changes that were previously
based on `master` and re-base them onto `stable`.

Now that we have a topic branch containing the change set based on the `stable`
release branch, the committer merges in:

    $ git checkout stable
    Switched to branch 'stable'
    $ git merge --no-ff --log bug/stable/fix_foo_error
    Merge made by the 'recursive' strategy.
     foo | 0
     1 file changed, 0 insertions(+), 0 deletions(-)
     create mode 100644 foo

Once merged into the first base branch, the committer merges the `stable`
branch into `master`, being careful to preserve the same commit identifiers.

    $ git checkout master
    Switched to branch 'master'
    $ git merge --no-ff --log stable
    Merge made by the 'recursive' strategy.
     foo | 0
     1 file changed, 0 insertions(+), 0 deletions(-)
     create mode 100644 foo

Once the change set has been merged into one base branch, the change set should
not be modified in order to keep the history clean, avoid "double" commits, and
preserve the usefulness of `git branch --contains`.  If there are any merge
conflicts, they are to be resolved in the merge commit itself and not by
re-writing (rebasing) the patches for one base branch, but not another.

Once the change set has been merged into `stable` and into `master`, the
committer pushes.  Please note, the checklist should be complete at this point.
It's helpful to make sure your local branches are up to date to avoid one of
the branches failing to fast forward while the other succeeds.  Both the
`stable` and `master` branches are being pushed at the same time.

    $ git push puppetlabs master:master stable:stable

That's it!  The committer then updates the pull request, updates the issue in
our issue tracker, and keeps an eye on the [build
status](http://jenkins.puppetlabs.com).
