<?php
$cf = parse_ini_file('/home/anineco/.my.cnf'); # 🔖 設定ファイル
$dsn = "mysql:dbname=$cf[database];host=$cf[host];charset=utf8mb4";
$dbh = new PDO($dsn, $cf['user'], $cf['password']);

$lat = filter_input(INPUT_GET, 'lat', FILTER_VALIDATE_FLOAT, [
  'options' => ['min_range' => -90, 'max_range' => 90]
]);
$lon = filter_input(INPUT_GET, 'lon', FILTER_VALIDATE_FLOAT, [
  'options' => [ 'min_range' => -180, 'max_range' => 180]
]);
if (!isset($lat, $lon) || $lat === false || $lon === false) {
  http_response_code(400); # Bad Request
  $dbh = null;
  exit;
}

$sql = <<<'EOS'
SET @pt=ST_GeomFromText(?,4326/*!80003 ,'axis-order=long-lat' */)
EOS;
$sth = $dbh->prepare($sql);
$sth->bindValue(1, "POINT($lon $lat)");
$sth->execute();
$sth = null;

$sql = <<<'EOS'
SELECT code,name,ST_AsGeoJSON(area,8) AS area FROM gyosei
LEFT JOIN city USING (code)
WHERE ST_Contains(area,@pt)
EOS;
$sth = $dbh->query($sql);
$output = $sth->fetchAll(PDO::FETCH_ASSOC);
$sth = null;

header('Content-type: application/json; charset=UTF-8');
header('Cache-Control: no-store, max-age=0');
echo json_encode($output, JSON_UNESCAPED_UNICODE), PHP_EOL;
$dbh = null;
# __END__
