<?php
// we don't want this to be run through the webserver, right?
if (php_sapi_name() != 'cli')
	die("CLI only\n");

$STDIN = fopen('php://stdin', 'r');

$maintenance_command = NULL;
switch(count($argv) >= 2 ? $argv[1] : NULL)
{
	case 'heroku':
		// import the Heroku configuration, if exists.
		exec("heroku config", $herokuConfig, $error);
		if ($error)
			die();
		foreach ($herokuConfig as $line)
		{
			$parts = explode(':', $line, 2);
			if (count($parts) < 2) continue;
			putenv($parts[0] . '=' . trim($parts[1]));
		}
		$maintenance_command = 'heroku maintenance:on';
		break;
}

// now, include the WordPress admin essentials
require_once('wp-load.php');
require_once('wp-admin/includes/admin.php');
require_once(ABSPATH . 'wp-admin/includes/class-wp-upgrader.php');

echo "Ok, we're ready to start. It's hightly recommended (if you'll select to autocommit the changes) that you've the git staging area clean!\nIf you're using Heroku, your site will be put in maintenance mode after the first update confirmation.\n[hit return when ready]";
fgets($STDIN);

$upgrade_dir = 'wp-content/upgrade';

/* USELESS...
function strip_html($in)
{
	var_dump($in);
	return html_entity_decode(strip_tags($in), ENT_QUOTES|ENT_HTML5, 'UTF-8') . "\n";
}
*/

echo "\n";

// first: core upgrade

$core_upgrades = get_core_updates();
$core_real_upgrades = array();

foreach ($core_upgrades as $i => $core_upgrade)
{
	if ($core_upgrade->response == 'upgrade')
		$core_real_upgrades[] = $core_upgrade;
}

if (!count($core_real_upgrades))
	echo "WordPress already up-to-date.\n";
else
{
	echo "WordPress updates (if you can't see your localization, stop and think about your sins):\n";
	foreach ($core_real_upgrades as $i => $core_upgrade)
		echo ($i+1).": WordPress ".$core_upgrade->current." ".$core_upgrade->locale."\n";
	echo "Enter the index to confirm the update, hit return to continue checking plugins and themes: ";
	$resp = strtolower(trim(fgets($STDIN)));
	if (in_array($resp, range(1, count($core_real_upgrades)) ))
	{
		if (!empty($maintenance_command)) system($maintenance_command);
		$selected_upgrade = $core_real_upgrades[$resp-1];
		@unlink($upgrade_dir); //disable the update lock
		
		$upgrader = new Core_Upgrader();
		$upgrader->upgrade($selected_upgrade); //SHIT output, but I cannot use output buffer, WordPress kill that

		@rmdir($upgrade_dir);
		touch($upgrade_dir); //reenable the update lock

		system('git add .');
		echo "\nCommit [Y/n]? ";
		$resp = strtolower(trim(fgets($STDIN)));
		if (empty($resp) || $resp == 'y')
			system('git commit -am '.escapeshellarg('Updated WordPress core to version '.$selected_upgrade->current.'-'.$selected_upgrade->locale));
	}
	else if (!empty($resp))
		echo "Invalid choice, step over\n";
}

// next: plugins and themes upgrade
function ask_and_update($collection)
{
	global $STDIN, $upgrade_dir, $maintenance_command;

	$get_updates = 'get_' . $collection . '_updates';
	if (!function_exists($get_updates))
	{
		echo "\n$collection error, unable to find WordPress functions. API changed?\n";
		return;
	}
	$updates = call_user_func($get_updates);
	if (!count($updates))
		echo "\n".ucfirst($collection)."s already up-to-date.\n";
	else
		foreach ($updates as $itemKey => $item)
		{
			$update = (object)($item->update);
			echo "\n". $item->Name . ' ' . $item->Version . '. Lastest version: ' . $update->new_version . ".\n";
			echo "Update [y/N]? ";
			$resp = strtolower(trim(fgets($STDIN)));
			if (!empty($resp) && $resp == 'y')
			{
				if (!empty($maintenance_command)) system($maintenance_command);
				@unlink($upgrade_dir); //disable the update lock

				$upgrader_class = ucfirst($collection).'_Upgrader'; //as Plugin_Upgrader();
				$upgrader = new $upgrader_class();
				$upgrader->upgrade($itemKey); //SHIT output, but I cannot use output buffer, WordPress kill that

				@rmdir($upgrade_dir);
				touch($upgrade_dir); //reenable the update lock

				system('git add ' . dirname(WP_PLUGIN_DIR . '/' . $itemKey));
				echo "\nCommit [Y/n]? ";
				$resp = strtolower(trim(fgets($STDIN)));
				if (empty($resp) || $resp == 'y')
					system('git commit -am '.escapeshellarg('Updated '.$item->Name.' to version '.$item->update->new_version));
			}
		}
}

ask_and_update('plugin');
ask_and_update('theme');

echo "\nIf you made some modifications, you should INSTANTLY push the result, as we probably touched the production database! Then, if you're on Heroku, do a heroku maintenance:off.\n";

