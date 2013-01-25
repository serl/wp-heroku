WP-Heroku
=========

An easy way to deploy WordPress on Heroku platform, using Amazon S3, ClearDB and SendGrid.

How to
------
	./wp-on-heroku.sh [repository name]
Accepts one optional parameter, that will become the subdirectory there all the magic will happens, and the Heroku app name.
It will download and configure WordPress for Heroku, and configure Heroku for WordPress, and deploy WordPress to Heroku.

The only remaining things (random order):
+ Create an Amazon Web Services S3 Bucket and set the requested environment variables on Heroku (the script output specifies which)
+ Add themes/plugins you want, as long as WordPress localization (you MUST do it via git repository!)
+ Now and then, go to update hidden plugins, issuing git pull in every subfolder of wp-contents/mu-plugins

wp-update-cli.php
-----------------
	php wp-update-cli.php [heroku]
This little PHP script is automatically included in your WordPress installation.

It will search for updates in core, themes and plugin (but NOT the ones in mu-plugin).

If you add the 'heroku' parameter, it will ask Heroku the environment variables (needed mainly for database connection), and automatically put your site in maintenance mode. You should then push the changes and disable the maintenance mode.

PAY ATTENTION: If you use it in other contexts (yes, you can! In every WordPress git repository!), know that it will assume that hack in repo: https://nealpoole.com/blog/2010/06/how-to-disable-wordpresss-upgrade-system/.

Known issues
------------
+ Due a bug in WordPress importer and/or WP Read Only, you'll have problems importing. That's because the xml will be saved as txt in S3, so the imported won't able to find it.


Bugs, feature request and so on
-------------------------------
Feel free to contact me: https://github.com/serl/wp-heroku/issues

Terms of use
------------
You use all you can find in this repository at your own risk, blah blah...

TODO
----
+ automatic activation of permalinks

