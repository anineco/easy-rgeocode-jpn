# easy-rgeocode-jpn
Setup MySQL for simple reverse geocoding in Japan using the digital national land information

## はじめに
[国土数値情報](https://nlftp.mlit.go.jp/)（行政区域）とMySQLのGIS機能を利用して、緯度・経度から所在地（都道府県＋市区町村）を求める逆ジオコーディングAPIを自前で構築する手順を示す。

表示例：https://anineco.github.io/easy-rgeocode-jpn/example.html

左上の[⌖]ボタンを押すと中央十字線の緯度、経度を読み取り、逆ジオコーディングを実行して所在地（都道府県＋市区町村）をポップアップ表示する。

## 逆ジオコーディングAPI（試験公開）
```
https://map.jpn.org/share/rg.php?lat=緯度&lon=経度
```
表示例：https://map.jpn.org/share/rg.php?lat=36.405277&lon=139.330562

緯度、経度は世界測地系（WGS84）で、度単位の10進数で与える。結果はJSON形式で返され、次のkey-valueからなる。
* code: [行政コード](https://nlftp.mlit.go.jp/ksj/gml/codelist/AdminAreaCd.html)
* name: 都道府県名＋市区町村名

## データベースの作成

### STEP 1. 入力データ（SQL）の入手
作成済のデータ（[easy-rgeocode-jpn_201010.zip](https://map.jpn.org/share/easy-rgeocode-jpn_201010.zip)）も公開しているので、これを用いても良い。ダウンロードして適当なディレクトリで解凍すると、
* city.sql
* x_NNN.sql（NNN = 000〜012 の連番）

が得られる。

### STEP 2. 入力データ（SQL）の作成
STEP 1.で作成済データを入手した場合は、次のSTEP 3.に進む。

入力データ（SQL）は、国土交通省の[国土数値情報](https://nlftp.mlit.go.jp/)から、GML(JPGIS2.1）シェープファイルで行政区域の全国の最新データ（2020-10-10現在、N03-200101_GML.zip）をダウンロードし、[geojsplit](https://github.com/woodb/geojsplit)と付属のスクリプトを用いて、次のコマンドで作成する。
```
$ ./gensql_city.pl > city.sql
$ unzip N03-200101_GML.zip '*.geojson'
$ mkdir -p temp
$ geojsplit -v -l 6000 -o temp N03-20_200101.geojson
$ ./geojson2sql.pl temp/*.geojson | ./bsplit.pl
```
これにより、city.sqlとx_NNN.sqlが出力される。なお、各x_NNN.sqlは、ファイルサイズが32MBを超えないように分割して作成される。この上限はbsplit.pl内の定数で設定され、適宜変更ができる。

### STEP 3. テーブルの作成

次の SQL コマンドでテーブルを作成する。
```
CREATE TABLE city (
 code SMALLINT UNSIGNED NOT NULL COMMENT '行政区域コード',
 name VARCHAR(255) NOT NULL COMMENT '都道府県+市区町村名'
);
CREATE TABLE gyosei (
 code SMALLINT UNSIGNED NOT NULL COMMENT '行政区域コード',
 area GEOMETRY NOT NULL /*!80003 SRID 4326 */ COMMENT '範囲'
);
```
なお、MySQL8の場合は、areaフィールドにSRID 4326を設定する必要がある（
https://dev.mysql.com/doc/refman/8.0/en/spatial-type-overview.html
）。

### STEP 4. 入力データ（SQL）のインポート
city.sqlとx_NNN.sqlの全てをSTEP 3.で作成したテーブルにインポートする。phpMyAdminを用いる場合は、SQLファイルをドラッグ&ドロップでインポートする機能が便利である。ファイルサイズの上限の制約によりインポートが失敗する場合は、PHPの設定の変更（php.iniの書き換え）を行って
* upload_max_filesize
* post_max_size
* memory_limit

の各パラメータを32Mに引き上げるか、各ファイルサイズを小さくする必要がある。また、MySQL側の設定で、
* max_allowed_packet

も32Mに引き上げる必要がある。

### STEP 5. インデックスの設定
インデックスの作成はインポート後にまとめて行った方が、全体の処理時間が短縮される。
```
ALTER TABLE city ADD PRIMARY KEY (code);
ALTER TABLE gyosei ADD SPATIAL KEY (area);
```

### STEP 6. テスト
```
SET @lon=140.084619;
SET @lat=36.104638;
SET @pt=ST_GeomFromText(CONCAT('POINT(',@lon,' ',@lat,')'),4326);
SELECT code,name FROM gyosei LEFT JOIN city USING (code) WHERE ST_Contains(area,@pt) LIMIT 1;
```
結果が 8220 茨城県つくば市 となればOK。

注：MySQL8では、POINT中の@lonと@latの順番が入れ替わる（
https://dev.mysql.com/doc/refman/8.0/en/gis-wkt-functions.html#function_st-geomfromtext
）。 

### STEP 7. データベースの修正（2020-10-11追記）

gensql_city.pl が参照している行政区域コード（https://nlftp.mlit.go.jp/ksj/gml/codelist/AdminAreaCd.html）の情報が古く、最近の市政施行が反映されていない。次のSQLを実行してデータベースを修正する。
```
UPDATE city SET code=3216,name='岩手県滝沢市' WHERE code=3305; # 岩手県岩手郡滝沢村
UPDATE city SET code=4216,name='宮城県富谷市' WHERE code=4423; # 宮城県黒川郡富谷町
UPDATE city SET code=11246,name='埼玉県白岡市' WHERE code=11445; # 埼玉県南埼玉郡白岡町
UPDATE city SET code=12239,name='千葉県大網白里市' WHERE code=12402; # 千葉県山武郡大網白里町
UPDATE city SET code=40231,name='福岡県那珂川市' WHERE code=40305; # 福岡県筑紫郡那珂川町
```

## API用PHPの設置
init.phpにデータベースへアクセスするための情報を記入し、rg.phpと共にWebサーバに設置する。MySQL8 の場合、STEP 6.の注と同じ理由により、rg.phpの一部を書き換える必要がある。

### 参考URL
* [MySQLでGISデータを扱う](https://qiita.com/onunu/items/59ef2c050b35773ced0d)
