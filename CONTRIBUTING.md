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

    - Make sure you have a [Redmine account](http://projects.puppetlabs.com)

    - Sign the [Contributor License Agreement](https://projects.puppetlabs.com/contributor_licenses/sign)

	- Submit a Redmine ticket for the issue, after confirming one does 
	  not already exist.
	
    - Fork the repository on GitHub.

    - Push your changes to a topic branch in your fork of the
        repository.

    - Submit a pull request to the repository in the puppetlabs
        organization.

The long version
================

  0. Create a Redmine ticket for the change you'd like to make.
     
	 It's very important that there be a Redmine ticket for the change 
	 you are making. Considering the number of contributions which are 
	 submitted, it is crucial that we know we can find the ticket on Redmine.
	
	 Before making a ticket however, be sure that one does not already exist.
	 You can do this by searching Redmine or by trying a Google search which 
	 includes `sites:projects.puppetlabs.com` in addition to some of the keywords 
	 related to your issue. 
	
	 If you do not find a ticket that that accurately describes the work 
	 you're going to be doing, go ahead and create one. But be sure to 
	 look for related tickets and add them to the 'related tickets' section.

  1.  Decide what to base your work on.

	  In general, you should always base your work on the oldest 
	  branch that your change is relevant to, and it will be 
	  eventually merged up. Currently, branches will be merged up as 
	  follows: 
	    2.6.x => 2.7.x => 3.x => master 
	
	  Currently, this is how you should decide where to target your changes: 
	
	  The absolute earliest place something should be targeted is at `2.6.x`, 
	    and these should _only_ be security fixes. Anything else must be
	    targeted at a later branch.
	
	  A bug fix should be based off the the earliest place where it is 
		relevant. If it first appears in `2.7.x`, then it should be 
		targeted here and eventually merged up to `3.x` and master. 
		
	  New features which are _backwards compatible_ should be targeted 
	    at the next release, which currently is `3.x`. 
	
	  New features that are _breaking changes_ should be targeted at 
		`master`.

      Part of deciding what to what your work should be based off of includes naming 
	  your topic branch to reflect this. Your branch name should have the following 
	  format: 
	  		`ticket/target_branch/ticket_number_short_description_of_issuee` 
	
	  For example, if you are fixing a bug relating to the ssl spec, which has Redmine 
	  ticket number 12345, then your branch should be named: 
			`ticket/2.7.x/12345_fix_ssl_spec_tests` 
			
	  There is a good chance that if you submit a pull request _from_ master _to_ master, 
	  Puppet Labs developers will suspect that you're not sure about the process. This is 
	  why clear naming of branches and basing your work off the right place will be 
	  extremely helpful in ensuring that your submission is reviewed and merged. Often times
	  if your change is targeted at the wrong place, we will bounce it back to you and wait 
	  to review it until it has been retargeted. 

  2.  Make separate commits for logically separate changes.

      Please break your commits down into logically consistent units
      which include new or changed tests relevent to the rest of the
      change.  The goal of doing this is to make the diff easier to
      read for whoever is reviewing your code.  In general, the easier
      your diff is to read, the more likely someone will be happy to
      review it and get it into the code base.

      If you're going to refactor a piece of code, please do so as a
      separate commit from your feature or bug fix changes.

      It's crucial that your changes include tests to make
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

      When writing commit messages, please be sure they meet 
	  [these standards](https://github.com/erlang/otp/wiki/Writing-good-commit-messages), and please include the ticket number in your 
	  short summary. It should look something like this: `(#12345) Fix this issue in Puppet`

  3.  Sign the Contributor License Agreement

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

  4.  Sending your patches

      To submit your changes via a GitHub pull request, you must
      have them on a topic branch, instead of directly on "master" 
      or one of the release, or RC branches. It makes things much easier 
      to keep track of, especially if you decide to work on another thing
      before your first change is merged in.

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

  5.  Update the related Redmine ticket.

      You should update the Redmine ticket associated 
      with the change you submitted to include the location of your branch
      on the `branch` field of the ticket, and change the status to 
      "In Topic Branch Pending Review", along with any other commentary 
       you may wish to make.

How to track the status of your change after it's been submitted
================================================================

Shortly after opening a pull request, there should be an automatic 
email sent via GitHub. This notification is used to let the Puppet
development community know about your requested change to give them a
chance to review, test, and comment on the change(s).

We do our best to comment on or merge submitted changes within a about week.
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
