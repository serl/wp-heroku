#!/bin/sh

#dependancies
which git >/dev/null &&
which wget >/dev/null &&
which heroku >/dev/null ||
echo "missing dependancies. (full list: git, wget, heroku toolbelt)"

rootdir=$(pwd)

reponame="$1"

if [ -z $reponame ]; then
	echo -n "Site/git repo name: "
	read reponame
fi

rollback () {
	if [ "$1" ]; then
		echo "ERROR: $1"
	else
		echo "ERROR!"
	fi
	echo "Rolling back"
	cd "$rootdir"
	rm -rf "$reponame"
	exit 1
}

[ -e "$reponame" ] &&
echo "$reponame exists! exiting..." && exit 1

mkdir "$reponame" &&
cd "$reponame" ||
(echo "unable to create directory" && exit 1)

git init ||
rollback "unable to create git repo"
heroku create $reponame &&
(heroku addons | grep cleardb >/dev/null || heroku addons:add cleardb:ignite) &&
(heroku addons | grep sendgrid >/dev/null || heroku addons:add sendgrid:starter) ||
rollback "unable to create and configure heroku application"

echo
echo "DOWNLOADING WORDPRESS"
wget "http://wordpress.org/latest.tar.gz" &&
echo "DECOMPRESSING..." &&
tar xzf latest.tar.gz &&
mv wordpress/* . &&
rmdir wordpress &&
rm latest.tar.gz ||
rollback "unable to download and decompress wordpress"

echo
#source: https://nealpoole.com/blog/2010/06/how-to-disable-wordpresss-upgrade-system/
echo "DISABLE UPGRADE (keeping the notifications)"
touch "wp-content/upgrade"

echo
echo "CREATING .htaccess"
cat >.htaccess <<EOF
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress

EOF

echo
echo "CREATING wp-config.php"
cat >wp-config.php <<EOF
<?php
/**
 * The base configurations of the WordPress.
 */

 // ** MySQL settings ** //
if (\$db_url = getenv("CLEARDB_DATABASE_URL")) {
 \$db = parse_url(\$db_url);
 define("DB_NAME", trim(\$db["path"],"/"));
 define("DB_USER", \$db["user"]);
 define("DB_PASSWORD", \$db["pass"]);
 define("DB_HOST", \$db["host"]);
 define('DB_CHARSET', 'utf8');
 define('DB_COLLATE', '');
}
else {
 die("CLEARDB_DATABASE_URL does not appear to be correctly specified.");
}

/**
 * Authentication Unique Keys and Salts.
 *
 * You can generate these using the {@link https://api.wordpress.org/secret-key/1.1/salt/ WordPress.org secret-key service}
 * You can change these at any point in time to invalidate all existing cookies. This will force all users to have to log in again.
 *
 * @since 2.6.0
 */
EOF

wget -O - "https://api.wordpress.org/secret-key/1.1/salt/" >> wp-config.php

table_prefix="wp$(date +%N)_"

cat >>wp-config.php <<EOF

\$table_prefix = '$table_prefix';

define('WPLANG', '');

define('WP_DEBUG', false);

define('WP_SITEURL', 'http://' . \$_SERVER['SERVER_NAME']);
define('WP_HOME', 'http://' . \$_SERVER['SERVER_NAME']);

//limit revisions
define('AUTOSAVE_INTERVAL', 120);
define('WP_POST_REVISIONS', 5);

//deny theme and plugins file edits
define('DISALLOW_FILE_EDIT', true);
//and update
define('DISALLOW_FILE_MODS', true);

 // ** WP Mail SMTP configuration ** //
define('WPMS_ON', true);
define('WPMS_MAIL_FROM', 'wordpress@'.\$_SERVER['SERVER_NAME']);
define('WPMS_MAIL_FROM_NAME', 'WordPress');
define('WPMS_SET_RETURN_PATH', 'false'); // Sets $phpmailer->Sender if true
define('WPMS_MAILER', 'smtp');
define('WPMS_SMTP_HOST', 'smtp.sendgrid.net');
define('WPMS_SMTP_PORT', 465);
define('WPMS_SSL', 'ssl');
define('WPMS_SMTP_AUTH', true);
define('WPMS_SMTP_USER', getenv('SENDGRID_USERNAME'));
define('WPMS_SMTP_PASS', getenv('SENDGRID_PASSWORD'));

 // ** WPRO configuration ** //
define('WPRO_ON', true);
define('WPRO_SERVICE', 's3');
define('WPRO_AWS_KEY', getenv('AWS_ACCESS_KEY_ID'));
define('WPRO_AWS_SECRET', getenv('AWS_SECRET_ACCESS_KEY'));
define('WPRO_AWS_BUCKET', getenv('S3_BUCKET_NAME'));
define('WPRO_AWS_ENDPOINT', getenv('S3_ENDPOINT'));
define('WPRO_AWS_VIRTHOST', false);

/* That's all, stop editing! Happy blogging. */

/** Absolute path to the WordPress directory. */
if ( !defined('ABSPATH') )
	define('ABSPATH', dirname(__FILE__) . '/');

/** Sets up WordPress vars and included files. */
require_once(ABSPATH . 'wp-settings.php');

EOF

echo
echo "DONWLOADING PLUGINS"

mkdir -p "wp-content/mu-plugins" &&

cat >wp-content/mu-plugins/load.php <<EOF
<?php // mu-plugins/load.php
require WPMU_PLUGIN_DIR.'/wp-mail-smtp/wp_mail_smtp.php';
require WPMU_PLUGIN_DIR.'/wpro/wpro.php';

EOF

git submodule add "git://github.com/myscienceisbetter/WP-Mail-SMTP.git" "wp-content/mu-plugins/wp-mail-smtp" ||
echo "unable to install WP-Mail-SMTP"

git submodule add "git://github.com/serl/wpro.git" "wp-content/mu-plugins/wpro" ||
echo "unable to install WP-ReadOnly"

echo
echo "GIT COMMIT AND PUSH TO HEROKU"
git add .
git commit -qm 'WordPress installation'
git push heroku master --force

echo
echo "NOW, in order to make uploads working, you have to create a AWS S3 Bucket and set these environment variables on heroku: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, S3_BUCKET_NAME, S3_ENDPOINT (using heroku config:set KEY=VALUE [KEY2=VALUE2])"
echo
echo "S3 endpoints:"
echo "\ts3.amazonaws.com => US East Region (Standard)"
echo "\ts3-us-west-2.amazonaws.com => US West (Oregon) Region"
echo "\ts3-us-west-1.amazonaws.com => US West (Northern California) Region"
echo "\ts3-eu-west-1.amazonaws.com => EU (Ireland) Region"
echo "\ts3-ap-southeast-1.amazonaws.com => Asia Pacific (Singapore) Region"
echo "\ts3-ap-northeast-1.amazonaws.com => Asia Pacific (Tokyo) Region"
echo "\ts3-sa-east-1.amazonaws.com => South America (Sao Paulo) Region"
echo
echo "After that you're free to add themes/plugins/localization locally, do some git commit and git push heroku master."
echo
echo "When you see notifications for updates in WordPress administration, you have to update them in this git repository, and then git push heroku master."
echo "IMPORTANT: WP Read Only and WP Mail SMTP are 'must-use plugins'. So they're automatically active, but hidden on the WordPress panel, so you WON'T SEE any update notification! ...now and then, go in their directories and do a git pull in order to get the lastest version"
