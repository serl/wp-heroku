WP-Heroku
=========

an easy way to deploy WordPress on Heroku platform, using Amazon S3, ClearDB and SendGrid.

How to
------
	./wp-on-heroku.sh [repository name]
accepts one optional parameter, that will become the subdirectory there all the magic will happens, and the Heroku app name.
It will download and configure WordPress for Heroku, and configure Heroku for WordPress, and deploy WordPress to Heroku.

The only remaining things (random order):
+ Set AWS S3 environment variables on Heroku (more info in the script output)
+ Add themes/plugins you want, as long as WordPress localization (you MUST do it via git repository!)
+ Now and then, go to update hidden plugins, issuing git pull in every subfolder of wp-contents/mu-plugins

TODO
----
+ automatic activation of permalinks

