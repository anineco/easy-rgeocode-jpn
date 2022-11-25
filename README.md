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
* code: [行政区域コード](https://nlftp.mlit.go.jp/ksj/gml/codelist/AdminiBoundary_CD.xlsx)
* name: 都道府県名＋市区町村名

## データベースの作成

### STEP 1. 入力データの入手

作成済のデータ（[easy-rgeocode-jpn_20210101.zip](https://map.jpn.org/share/easy-rgeocode-jpn_20210101.zip)）も公開しているので、これを用いても良い。ダウンロードして適当なディレクトリで解凍すると、
* city.sql
* x_NNN.sql（NNN=000〜の連番）
が得られる。

city.sqlは行政区域コードと都道府県+市区町村名をデータベースに挿入するSQLファイルである。

また、x_NNN.sqlは行政区域の範囲のポリゴンデータをデータベースに挿入するSQLファイルである。各SQLファイルは、ファイルサイズが32MB以下になるように分割されているが、データベースの設定や負荷によっては受け付けられない。その場合は、ファイルサイズが16MB以下になるように分割して作成したデータ（[easy-rgeocode-jpn_20210101_small.zip](https://map.jpn.org/share/easy-rgeocode-jpn_20210101_small.zip)）を用意しているので、こちらを用いても良い。

### STEP 2. 入力データの作成

STEP 1.で作成済の入力データを入手した場合は、STEP 3.に進む。以下の作業はmacOSやLinuxのCUIで行う。

まず、国土交通省の[国土数値情報ダウンロードサービス](https://nlftp.mlit.go.jp/ksj/)のページから、データ形式をJPGIS形式GML（JPGIS2.1）シェープファイルとして、行政区域（ポリゴン）のページに入り、全国のデータ（令和3年）
* N03-20210101_GML.zip
をダウンロードする。なお、全国のデータは令和4年のもの（N03-20220101_GML.zip）もあるが、データサイズが大きいため、MySQL に読み込ませるとエラーとなり、現状では使用できない。

次のコマンドを実行して、city.sqlを作成する。
```
./gencsv_city.py > city.csv
```
次に、以下のコマンドを実行して、x_NNN.sql ファイルを作成する。
```
unzip N03-20210101_GML.zip '*.geojson'
SOURCE=N03-20210101_GML/N03-21_210101.geojson
TARGET=easy-rgeocode-jpn_20210101

export NODE_OPTIONS="--max-old-space-size=5000"

rm -rf temp $TARGET
mkdir -p temp $TARGET

geojsplit -v -l 1 -o temp $SOURCE
for i in temp/*.geojson; do
  x=${i%.geojson}
  ./geojson2sql.pl $i > $x.sql
  echo wrote file $x.sql
done
for i in temp/*.sql; do
  cat $i
done | (cd $TARGET; ../bsplit.pl)
```
なお、各 x_NNN.sql は、ファイルサイズが32MBを超えないように分割して作成される。この上限はbsplit.pl内の定数で設定され、適宜変更ができる。

### STEP 3. テーブルの作成

次の SQLコマンドでテーブルを作成する。
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
なお、MySQL8の場合は、areaフィールドにSRID 4326を設定している（
https://dev.mysql.com/doc/refman/8.0/en/spatial-type-overview.html
）。

### STEP 4. 入力データのインポート

STEP 3.で作成したテーブルについて、city.sqlと全てのx_NNN.sqlをインポートする。phpMyAdminを用いると、SQLファイルをドラッグ&ドロップしてインポートすることができ、便利である。ファイルサイズの上限の制約によりインポートが失敗する場合は、PHPの設定の変更（php.iniの書き換え）を行って
* upload_max_filesize
* post_max_size
* memory_limit
の各パラメータを32Mに引き上げるか、各ファイルサイズを小さくする必要がある。また、MySQL側の設定で、
* max_allowed_packet
も32Mに引き上げる必要がある。

### STEP 5. インデックスの設定

データをインポード後に、インデックスの作成を行う。
```
ALTER TABLE city ADD PRIMARY KEY (code);
ALTER TABLE gyosei ADD SPATIAL KEY (area);
```

### STEP 6. テスト

次のSQLを実行する。
```
SET @lon=140.084619;
SET @lat=36.104638;
SET @pt=ST_GeomFromText(CONCAT('POINT(',@lon,' ',@lat,')'),4326);
SELECT code,name FROM gyosei LEFT JOIN city USING (code) WHERE ST_Contains(area,@pt) LIMIT 1;
```
なお、MySQL8では、POINT中の@lonと@latの順番を入れ換える必要があり（
https://dev.mysql.com/doc/refman/8.0/en/gis-wkt-functions.html#function_st-geomfromtext
）、代わりに次のSQLを実行する。
```
SET @lon=140.084619;
SET @lat=36.104638;
SET @pt=ST_GeomFromText(CONCAT('POINT(',@lat,' ',@lon,')'),4326);
SELECT code,name FROM gyosei LEFT JOIN city USING (code) WHERE ST_Contains(area,@pt) LIMIT 1;
```
結果が「8220 茨城県つくば市」と表示されればOK。

## API用PHPの設置

init.phpにデータベースへアクセスするための情報を記入し、rg.phpと共にWebサーバに設置する。MySQL8の場合、STEP 6.の注と同じ理由により、rg.phpの一部を書き換える必要がある。

### 参考URL
* [MySQLでGISデータを扱う](https://qiita.com/onunu/items/59ef2c050b35773ced0d)
