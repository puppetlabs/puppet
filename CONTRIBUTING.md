Checklist (and a short version for the impatient)
=================================================

  * Commits:

    - Make commits of logical units.

    - Check for unnecessary whitespace with "git diff --check" before
      committing.

    - Commit using Unix line endings (check the settings around "crlf" in
      git-config(1)).

    - Do not check in commented out code or unneeded files.

    - The first line of the commit message should be a short
      description (50 characters is the soft limit, excluding ticket
      number(s)), and should skip the full stop.

    - If there is an associated Redmine ticket then the first line
      should include the ticket number in the form "(#XXXX) Rest of
      message".

    - The body should provide a meaningful commit message, which:

      - uses the imperative, present tense: "change", not "changed" or
        "changes".

      - includes motivation for the change, and contrasts its
        implementation with the previous behavior.

    - Make sure that you have tests for the bug you are fixing, or
      feature you are adding.

    - Make sure the test suite passes after your commit (rake spec unit).

  * Submission:

    * Pre-requisites:

      - Make sure you have a [Redmine account](http://projects.puppetlabs.com)

      - Sign the [Contributor License Agreement](https://projects.puppetlabs.com/contributor_licenses/sign)

    * Preferred method:

      - Fork the repository on GitHub.

      - Push your changes to a topic branch in your fork of the
        repository.

      - Submit a pull request to the repository in the puppetlabs
        organization.

    * Alternate methods:

      - Mail patches to puppet-dev mailing list using `rake mail_patches`,
        or `git-format-patch(1)` & `git-send-email(1)`.

      - Attach patches to Redmine ticket.

The long version
================

  0.  Decide what to base your work on.

      In general, you should always base your work on the oldest
      branch that your change is relevant to.

      - A bug fix should be based on the current stable series. If the
        bug is not present in the current stable release, then base it on
        `master`.

      - A new feature should be based on `master`.

      - Security fixes should be based on the current maintenance series
        (that is, the previous stable series).  If the security issue
        was not present in the maintenance series, then it should be
        based on the current stable series if it was introduced there,
        or on `master` if it is not yet present in a stable release.

      The current stable series is 2.7.x, and the current maintenance
      series is 2.6.x.

  1.  Make separate commits for logically separate changes.

      Please break your commits down into logically consistent units
      which include new or changed tests relevent to the rest of the
      change.  The goal of doing this is to make the diff easier to
      read for whoever is reviewing your code.  In general, the easier
      your diff is to read, the more likely someone will be happy to
      review it and get it into the code base.

      If you're going to refactor a piece of code, please do so as a
      separate commit from your feature or bug fix changes.

      We also really appreciate changes that include tests to make
      sure the bug isn't re-introduced, and that the feature isn't
      accidentally broken.

      Describe the technical detail of the change(s).  If your
      description starts to get too long, that's a good sign that you
      probably need to split up your commit into more finely grained
      pieces.

      Commits which plainly describe the the things which help
      reviewers check the patch and future developers understand the
      code are much more likely to be merged in with a minimum of
      bike-shedding or requested changes.  Ideally, the commit message
      would include information, and be in a form suitable for
      inclusion in the release notes for the version of Puppet that
      includes them.

      Please also check that you are not introducing any trailing
      whitespaces or other "whitespace errors".  You can do this by
      running "git diff --check" on your changes before you commit.

  2.  Sign the Contributor License Agreement

      Before we can accept your changes, we do need a signed Puppet
      Labs Contributor License Agreement (CLA).

      You can access the CLA via the
      [Contributor License Agreement link](https://projects.puppetlabs.com/contributor_licenses/sign)
      in the top menu bar of our Redmine instance.  Once you've signed
      the CLA, a badge will show up next to your name on the
      [Puppet Project Overview Page](http://projects.puppetlabs.com/projects/puppet?jump=welcome),
      and your name will be listed under "Contributor License Signers"
      section.

      If you have any questions about the CLA, please feel free to
      contact Puppet Labs via email at cla-submissions@puppetlabs.com.

  3.  Sending your patches

      We accept multiple ways of submitting your changes for
      inclusion.  They are listed below in order of preference.

      Please keep in mind that any method that involves sending email
      to the mailing list directly requires you to be subscribed to
      the mailing list, and that your first post to the list will be
      held in a moderation queue.

      * GitHub Pull Requests

        To submit your changes via a GitHub pull request, we _highly_
        recommend that you have them on a topic branch, instead of
        directly on "master" or one of the release, or RC branches.
        It makes things much easier to keep track of, especially if
        you decide to work on another thing before your first change
        is merged in.

        GitHub has some pretty good
        [general documentation](http://help.github.com/) on using
        their site.  They also have documentation on
        [creating pull requests](http://help.github.com/send-pull-requests/).

        In general, after pushing your topic branch up to your
        repository on GitHub, you'll switch to the branch in the
        GitHub UI and click "Pull Request" towards the top of the page
        in order to open a pull request.

        You'll want to make sure that you have the appropriate
        destination branch in the repository under the puppetlabs
        organization.  This should be the same branch that you based
        your changes off of.

      * Other pull requests

        If you already have a publicly accessible version of the
        repository hosted elsewhere, and don't wish to or cannot use
        GitHub, you can submit your change by requesting that we pull
        the changes from your repository by sending an email to the
        puppet-dev Google Groups mailing list.

        `git-request-pull(1)` provides a handy way to generate the text
        for the email requesting that we pull your changes (and does
        some helpful sanity checks in the process).

      * Mailing patches to the mailing list

        If neither of the previous methods works for you, then you can
        also mail the patches inline to the puppet-dev Google Group
        using either `rake mail_patches`, or by using
        `git-format-patch(1)`, and `git-send-email(1)` directly.

        `rake mail_patches` handles setting the appropriate flags to
        `git-format-patch(1)` and `git-send-email(1)` for you, but
        doesn't allow adding any commentary between the '---', and the
        diffstat in the resulting email.  It also requires that you
        have created your topic branch in the form
        `<type>/<parent>/<name>`.

        If you decide to use `git-format-patch(1)` and
        `git-send-email(1)` directly, please be sure to use the
        following flags for `git-format-patch(1)`: -C -M -s -n
        --subject-prefix='PATCH/puppet'

      * Attaching patches to Redmine

        As a method of last resort you can also directly attach the
        output of `git-format-patch(1)`, or `git-diff(1)` to a Redmine
        ticket.

        If you are generating the diff outside of Git, please be sure
        to generate a unified diff.

  4.  Update the related Redmine ticket.

      If there's a Redmine ticket associated with the change you
      submitted, then you should update the ticket to include the
      location of your branch, and change the status to "In Topic
      Branch Pending Merge", along with any other commentary you may
      wish to make.

How to track the status of your change after it's been submitted
================================================================

Shortly after opening a pull request on GitHub, there should be an
automatic message sent to the puppet-dev Google Groups mailing list
notifying people of this.  This notification is used to let the Puppet
development community know about your requested change to give them a
chance to review, test, and comment on the change(s).

If you submitted your change via manually sending a pull request or
mailing the patches, then we keep track of these using
[patchwork](https://patchwork.puppetlabs.com).  When code is merged
into the project it is automatically removed from patchwork, and the
Redmine ticket is manually updated with the commit SHA1.  In addition,
the ticket status must be updated by the person who merges the topic
branch to a status of "Merged - Pending Release"

We do our best to comment on or merge submitted changes within a week.
However, if there hasn't been any commentary on the pull request or
mailed patches, and it hasn't been merged in after a week, then feel
free to ask for an update by replying on the mailing list to the
automatic notification or mailed patches. It probably wasn't
intentional, and probably just slipped through the cracks.

Additional Resources
====================

* [Getting additional help](http://projects.puppetlabs.com/projects/puppet/wiki/Getting_Help)

* [Writing tests](http://projects.puppetlabs.com/projects/puppet/wiki/Development_Writing_Tests)

* [Bug tracker (Redmine)](http://projects.puppetlabs.com)

* [Patchwork](https://patchwork.puppetlabs.com)

* [Contributor License Agreement](https://projects.puppetlabs.com/contributor_licenses/sign)

* [General GitHub documentation](http://help.github.com/)

* [GitHub pull request documentation](http://help.github.com/send-pull-requests/)

If you have commit access to the repository
===========================================

Even if you have commit access to the repository, you'll still need to
go through the process above, and have someone else review and merge
in your changes.  The rule is that all changes must be reviewed by a
developer on the project (that didn't write the code) to ensure that
all changes go through a code review process.

Having someone other than the author of the topic branch recorded as
performing the merge is the record that they performed the code
review.

  * Merging topic branches

    When merging code from a topic branch into the integration branch
    (Ex: master, 2.7.x, 1.6.x, etc.), there should always be a merge
    commit.  You can accomplish this by always providing the `--no-ff`
    flag to `git merge`.

        git merge --no-ff --log tickets/master/1234-fix-something-broken

    The reason for always forcing this merge commit is that it
    provides a consistent way to look up what changes & commits were
    in a topic branch, whether that topic branch had one, or 500
    commits.  For example, if the merge commit had an abbreviated
    SHA-1 of `coffeebad`, then you could use the following `git log`
    invocation to show you which commits it brought in:

        git log coffeebad^1..coffeebad^2

    The following would show you which changes were made on the topic
    branch:

        git diff coffeebad^1...coffeebad^2

    Because we _always_ merge the topic branch into the integration
    branch the first parent (`^1`) of a merge commit will be the most
    recent commit on the integration branch from just before we merged
    in the topic, and the second parent (`^2`) will always be the most
    recent commit that was made in the topic branch.  This also serves
    as the record of who performed the code review, as mentioned
    above.
