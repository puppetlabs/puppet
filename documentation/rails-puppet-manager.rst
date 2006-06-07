I have begun work on a simplistic web-based Puppet manager based on Rails_,
called PuppetShow.  It's in a very primitive state -- including having no
authentication, so use at your own risk -- but it's a good proof of concept.

To get it working, first check out the code_.  Then set up your apache config
to serve it.  This is what mine looks like::

    <VirtualHost 192.168.0.101:80 192.168.0.102:80 192.168.0.3:80>
        ServerAdmin luke@madstop.com
        SetEnv RAILS_ENV development
        ServerName puppet.madstop.com
        ServerAlias puppet
        DocumentRoot /var/lib/puppetshow/public
        ErrorLog /var/lib/puppetshow/log/apache.log

        <Directory /var/lib/puppetshow/public/>
            Options ExecCGI FollowSymLinks
            AddHandler cgi-script .cgi
            AllowOverride all
            Order allow,deny
            Allow from all
        </Directory>
    </VirtualHost>

Now we just need to get the puppet internal stuff working.  We could use
either ``rake`` or Puppet to do this, but for whatever reason I decided to use
Puppet.  I've created a ``setup.pp`` file in the root of the tree, so you just
need to modify that as appropriate (in particular, I have a Facter lib that
sets ``$home`` for me, so you'll probably need to set that), then run::

    sudo puppet -v setup.pp

At that point you should have a functional app.  Like I said, there's no
navigation at all, so you need to know what's out there.  The first thing you
need to do is start a daemon that this app can connect to.  Pick your victim,
create a namespace auth file (defaults to
``/etc/puppet/namespaceauth.conf``)::
    
    [fileserver]
        allow *.madstop.com

    [puppetmaster]
        allow *.madstop.com

    [pelementserver]
        allow puppet.madstop.com

Then start your client::

    puppetd -v --listen --no-client

Here we're telling it to start the listening daemon but not to run the config.
You can obviously use whatever options you want, though.

Now you should be able to just go to your app.  At this point, you need to
know the name of the machine you want to connect to and the name of a type to
look at.  Say you're connecting to culain (my workstation's name), and you
want to look at users; this would be your URL:
http://puppet.domain.com/remote/culain/user/list

Replace as appropriate for your site.

.. _rails: http://rubyonrails.org
.. _code: https://reductivelabs.com/svn/puppetshow
