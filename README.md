# easy-rgeocode-jpn
Setup MySQL for simple reverse geocoding in Japan using the digital national land information

## はじめに
[国土数値情報](https://nlftp.mlit.go.jp/)（行政区域）と MySQL のGIS機能を利用して、緯度・経度から所在地（都道府県＋市区町村）を求める逆ジオコーディングAPIを自前で構築する手順を示す。

表示例：https://anineco.github.io/easy-rgeocode-jpn/example.html

左上の[⌖]ボタンを押すと中央十字線の緯度、経度を読み取り、逆ジオコーディングを実行して所在地（都道府県＋市区町村）をポップアップ表示する。

## 逆ジオコーディングAPI（試験公開）
```
https://map.jpn.org/share/rg.php?lat=緯度&lon=経度
```
表示例：https://map.jpn.org/share/rg.php?lat=36.405277&lon=139.330562

緯度、経度は世界測地系（WGS84）で、度単位の10進数で与える。結果はJSON形式で返され、次の key-value を含む。
* code: [行政コード](https://nlftp.mlit.go.jp/ksj/gml/codelist/AdminAreaCd.html)
* name: 都道府県名＋市区町村名

## データベースの作成

### STEP 1. 入力データ（SQL）の入手

作成済のデータ（[easy-rgeocode-jpn_200622.zip](https://map.jpn.org/share/easy-rgeocode-jpn_200622.zip)）も公開しているので、これを用いても良い。ダウンロードして適当なディレクトリで解凍すると、
* city.sql
* x_###.sql（### = 000〜016 の連番）

が得られる。

### STEP 2. 入力データ（SQL）の作成
STEP 1. で作成済データを入手した場合は、次の STEP 3. に進む。

入力データ（SQL）は、[国土数値情報](https://nlftp.mlit.go.jp/)（行政区域）から、最新データ（N03-190101_GML.zip）をダウンロードし、付属のスクリプトを用いて、次のコマンドで作成する。
```
$ ./gensql_city.pl > city.sql
$ unzip -p N03-190101_GML.zip '*.geojson' | ./gensql_gyosei.pl | ./bsplit.pl
```
これにより、city.sql と x_###.sql が出力される。なお、各 x_###.sql は、ファイルサイズが32MBを超えないように分割して作成される。この上限は bsplit.pl 内で定数で設定されている。

### STEP 3. テーブルの作成

次の SQL コマンドでテーブルを作成する。
```
CREATE TABLE `city` (
 `code` smallint unsigned NOT NULL COMMENT '行政区域コード',
 `name` varchar(255) NOT NULL COMMENT '都道府県+市区町村名'
);
CREATE TABLE `gyosei` (
 `code` smallint unsigned NOT NULL COMMENT '行政区域コード',
 `area` geometry NOT NULL /*!80003 SRID 4326 */ COMMENT '範囲'
);
```
なお、MySQL 8 の場合は、`area`フィールドに SRID 4326 の設定が必要である（
https://dev.mysql.com/doc/refman/8.0/en/spatial-type-overview.html
）。

### STEP 4. 入力データ（SQL）のインポート

city.sql と x_###.sql の全てを STEP 3. で作成したテーブルにインポートする。phpMyAdmin を用いる場合は、SQLファイルをドラッグ&ドロップでインポートする機能を利用すると便利である。ファイルサイズの上限に制約されてインポートが失敗する場合は、PHP の設定の変更（php.ini の書き換え）を行って
* upload_max_filesize
* post_max_size
* memory_limit

を 32M に引き上げるか、各ファイルサイズを上限より小さくする必要がある。

### STEP 5. インデックスの設定
```
ALTER TABLE city ADD PRIMARY KEY(code);
ALTER TABLE gyosei ADD SPATIAL INDEX (area);

```

### STEP 6. テスト
```
SET @lon=140.084619;
SET @lat=36.104638;
SET @pt=ST_GeomFromText(CONCAT('POINT(',@lon,' ',@lat,')'),4326);
SELECT code,name FROM gyosei LEFT JOIN city USING (code) WHERE ST_Contains(area,@pt) LIMIT 1;
```
注：MySQL8 では、POINT中の@lonと@latの順番が入れ替わる（
https://dev.mysql.com/doc/refman/8.0/en/gis-wkt-functions.html#function_st-geomfromtext
）。 

### STEP 7. API用PHPの設置
init.php にデータベースへアクセスするための情報を記入し、rg.php と共に Webサーバに設置する。MySQL8 の場合、STEP 6. 注と同じ理由により、rg.php の一部を書き換える必要がある。

### 参考URL
* [MySQLでGISデータを扱う](https://qiita.com/onunu/items/59ef2c050b35773ced0d)
