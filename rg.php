<?php
require_once './init.php';
$cf = set_init();
$dsn = "mysql:dbname=$cf[database];host=$cf[host];charset=utf8mb4";
#$dsn = "mysql:dbname=$cf[database];unix_socket=$cf[socket];charset=utf8mb4";

$dbh = new PDO($dsn, $cf['user'], $cf['password']);
$type = !empty($_POST) ? INPUT_POST : INPUT_GET;
$lon = filter_input($type, 'lon');
$lat = filter_input($type, 'lat');

# MySQL8
$sql = <<<'EOS'
SET @pt=ST_GeomFromText(CONCAT('POINT(',?,' ',?,')'),4326,'axis-order=long-lat')
EOS;
# MySQL5/MariaDB10
#$sql = <<<'EOS'
#SET @pt=ST_GeomFromText(CONCAT('POINT(',?,' ',?,')'),4326)
#EOS;

$sth = $dbh->prepare($sql);
$sth->bindValue(1, $lon, PDO::PARAM_STR);
$sth->bindValue(2, $lat, PDO::PARAM_STR);
$sth->execute();
$sth = null;
$sql = <<<'EOS'
SELECT code,name,ST_AsGeoJSON(area,14) AS a
FROM gyosei JOIN city USING (code)
WHERE ST_Contains(area,@pt) LIMIT 1
EOS;
$sth = $dbh->prepare($sql);
$sth->execute();
$code = 0;
$name = 'unknown';
$area = '';
while ($row = $sth->fetch(PDO::FETCH_OBJ)) {
  $code = $row->code;
  $name = $row->name;
  $area = $row->a;
}
$sth = null;
$output = array( 'code' => $code, 'name' => $name, 'area' => $area );
header('Content-type: application/json; charset=UTF-8');
echo json_encode($output, JSON_UNESCAPED_UNICODE), PHP_EOL;
$dbh = null;
