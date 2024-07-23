<?php

$path_to_settings_file = "{$argv[1]}/.settings.php";

$data = require_once $path_to_settings_file;

$db_name = $data['connections']['value']['default']['database'];
$db_user = $data['connections']['value']['default']['login'];

echo "$db_name\n";
echo "$db_user\n";
