import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:external_path/external_path.dart';
import 'package:carrier_info/carrier_info.dart';
import 'package:geolocator/geolocator.dart';
import 'map.dart';
import 'package:nr_cellinfo/cellResponse.dart';
import 'package:nr_cellinfo/simInfoResponse.dart';
import 'package:nr_cellinfo/nr_cellinfo.dart';
import 'package:nr_cellinfo/models/common/cell_type.dart';

const imgUrl ="your server URL"; 
const T= 200;//何秒ダウンロードするか
var dio = Dio();
const NUM = 1;

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    // MaterialAppで画面のテーマ等を設定できる.(GoogleのUIっぽいデザインを返す)
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'スループット計測アプリ'),
    );
  }
}

// StatefulWidgetを継承したクラス
class MyHomePage extends StatefulWidget {
  // コンストラクト
  MyHomePage({Key? key,required this.title}) : super(key: key);
  // 定数定義
  final String title;
  // アロー関数を用いて、MyHomePageStateを呼ぶ
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

// Widgetから呼ばれるStateクラス
class _MyHomePageState extends State<MyHomePage> { //_MyHomePageメソッド
  //変数定義
  final double fileSize=1.3*8;
  var _timeMsec = 0; //Requestにかかった時間を格納
  double _timeSec=0;
  // ignore: non_constant_identifier_names
  double Mbps=0;
  double throughput=0;
  final myController = TextEditingController(); // 入力された内容をこのコントローラを使用して取り出します。
  var formattedDate = "none"; //string型に変更した時間
  var formattedDate1 = "none"; //string型に変更した時間
  var formattedDate2 = "none"; //string型に変更した時間
  Stopwatch s=Stopwatch();//時間の計測を行う
  var dataset={}; //時間(s)と帯域(Mbps)を保存する関数
  List<double> dataList = [];
  List<double> dataListNeighbor = [];
  List<int> dataListNeighborLength = [];
  int firstTime=0;
  var filename= "null";
  double timecount = 0;
  var CellId = "Null";
  String Latitude = "Null";
  String Longitude = "Null";
  double RSSI = 0;
  double RSRP = 0;
  double SINR = 0;

  // androidアプリのフォルダにアクセスを許可する関数
  void getPermission() async {
    print("getPermission");
    await [Permission.storage].request();
  }
  CellsResponse? _cellsResponse;
  @override
  void initState() {
    getPermission();
    super.initState();
  }

  //Datetimeをstringで取得する関数
  formatTimeGet(time){
    formattedDate = DateFormat('yyyy-MM-dd-kk:mm:ss:SSS').format(time);//String型に変換
    return formattedDate;
  }
  String currentDBM = "";

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;
    // 位置情報サービスが有効かどうかをテスト
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // 位置情報サービスを有効にするようアプリに要請
      return Future.error('Location services are disabled.');
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // ユーザーに位置情報を許可してもらう
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // 拒否された場合エラーを返す
        return Future.error('Location permissions are denied');
      }
    }
    // 永久に拒否されている場合のエラーを返す
    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }
    // デバイスの位置情報を返す。
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  //画像のダウンロードを行いスループットを求める関数
  Future download2(Dio dio, String url) async {
    DateTime timeBeforeReq = new DateTime.now();//ダウンロード前の時間取得
    formattedDate1 = formatTimeGet(timeBeforeReq);//String型に変換
    //ダウンロード開始
    try {
      await dio.get(
        url,
      );
    } catch (e) {
      print(e);
    }
    DateTime timeAfterRes = new DateTime.now();//ダウンロード後の時間取得
    formattedDate2 = formatTimeGet(timeAfterRes);//String型に変換
    int sinceEpochBeforeReq = timeBeforeReq.millisecondsSinceEpoch; //mmsecondに変換
    int sinceEpochAfterRes = timeAfterRes.millisecondsSinceEpoch; //mmsecondに変換
    _timeMsec = sinceEpochAfterRes - sinceEpochBeforeReq; //ダウンロードにかかった時間の代入(ms)
    _timeSec=_timeMsec/1000;//msをsに変換
    Mbps=fileSize/_timeSec;//throughput(Mbps) = Datasize(Mbps)/Time(s)
    Mbps=((Mbps*100).floor())/100;//(小数点2桁まで表示)
    setState(() {  // 画面の更新のため、setStateでフィールドを変更
      throughput=Mbps;
      }
    );
  }

  //タイムスタンプを起動する関数
  void start_stopwatch(){
    s.start();//計測開始
  }

  // 経過時間を取得する関数
  nowTime(){
    return (s.elapsedMilliseconds);
  }

  getNeighbor() async {
    CellsResponse? cellsResponse;
    String platformVersion = (await NrCellinfo.getCellInfo) ?? "";
    final body = json.decode(platformVersion);
    cellsResponse = CellsResponse.fromJson(body);
    int? neighbor = cellsResponse.neighboringCellList?.length;
    //print(neighbor);
    dataListNeighborLength.add(neighbor!);
    for(int i = 0; i < neighbor; i++) {
      CellType currentCellInFirstChipNeighbor = cellsResponse.neighboringCellList![i];
      dataListNeighbor.add(currentCellInFirstChipNeighbor.lte!.signalLTE!.rssi!.toDouble());
      dataListNeighbor.add(currentCellInFirstChipNeighbor.lte!.signalLTE!.rsrp!.toDouble());
    }
  }

  //求めたスループットを保存する関数
  repetition(fileName) async{
    dataListNeighbor.clear();
    dataListNeighborLength.clear();
    dataList.clear();
    start_stopwatch();
    await download2(dio,imgUrl);
    firstTime=nowTime();
    //セルID取得
    int? carrierInfo = await CarrierInfo.cid;
    double cid = carrierInfo!.toDouble();
    //緯度と経度を求める
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    double ido = position.latitude.toDouble();
    ido = ((ido*10000).floor())/10000;//(小数点4桁)
    double keido = position.longitude.toDouble();
    keido = ((keido*10000).floor())/10000;//(小数点4桁)
    Latitude = ido.toString();
    Longitude = keido.toString();
    //通信品質を求める
    CellsResponse? cellsResponse;
    try {
      String platformVersion = (await NrCellinfo.getCellInfo) ?? "";
      final body = json.decode(platformVersion);
      cellsResponse = CellsResponse.fromJson(body);
      CellType currentCellInFirstChip = cellsResponse.primaryCellList![0];
      RSSI = currentCellInFirstChip.lte!.signalLTE!.rssi!.toDouble();
      RSRP = currentCellInFirstChip.lte!.signalLTE!.rsrp!.toDouble();
      SINR = currentCellInFirstChip.lte!.signalLTE!.snr!.toDouble();
      if (currentCellInFirstChip.type == "LT  E") {
        currentDBM = "LTE dbm = " +
            currentCellInFirstChip.lte!.signalLTE!.dbm.toString();
      } else if (currentCellInFirstChip.type == "NR") {
        currentDBM =
            "NR dbm = " + currentCellInFirstChip.nr!.signalNR!.dbm.toString();
      } else if (currentCellInFirstChip.type == "WCDMA") {
        currentDBM = "WCDMA dbm = " +
            currentCellInFirstChip.wcdma!.signalWCDMA!.dbm.toString();
        //print('currentDBM = ' + currentDBM);
      }
    } on PlatformException {
      _cellsResponse = null;
    }

    dataListNeighbor.add(0.00);
    getNeighbor();
    dataset[0.00]='$throughput';
    dataList.add(0.00);
    dataList.add(throughput);
    dataList.add(cid);
    dataList.add(RSSI);
    dataList.add(RSRP);
    dataList.add(SINR);

    for (int i = 0; i < 100000; i++) {
      int j = 0;
      await download2(dio, imgUrl);
      //セルID取得
      int? carrierInfo2 = await CarrierInfo.cid;
      double cid2 = carrierInfo2!.toDouble();
      CellId = carrierInfo2.toString();
      j = (nowTime() - firstTime);
      double x = j / 1000 ;
      x = double.parse(x.toStringAsFixed(2));
      timecount = x;
      if(x>T){
        s.stop();//ストップウォッチを停止する
        s.reset();
        break;
      }
      //RSRPを求める
      CellsResponse? cellsResponse;
      try {
        String platformVersion = (await NrCellinfo.getCellInfo) ?? "";
        final body = json.decode(platformVersion);
        cellsResponse = CellsResponse.fromJson(body);
        CellType currentCellInFirstChip = cellsResponse.primaryCellList![0];
        RSSI = currentCellInFirstChip.lte!.signalLTE!.rssi!.toDouble();
        RSRP = currentCellInFirstChip.lte!.signalLTE!.rsrp!.toDouble();
        SINR = currentCellInFirstChip.lte!.signalLTE!.snr!.toDouble();
        if (currentCellInFirstChip.type == "LT  E") {
          currentDBM = "LTE dbm = " +
              currentCellInFirstChip.lte!.signalLTE!.dbm.toString();
        } else if (currentCellInFirstChip.type == "NR") {
          currentDBM =
              "NR dbm = " + currentCellInFirstChip.nr!.signalNR!.dbm.toString();
        } else if (currentCellInFirstChip.type == "WCDMA") {
          currentDBM = "WCDMA dbm = " +
              currentCellInFirstChip.wcdma!.signalWCDMA!.dbm.toString();
          //print('currentDBM = ' + currentDBM);
        }
      } on PlatformException {
        _cellsResponse = null;
      }
      if (!mounted) return;
      setState(() {
        _cellsResponse = cellsResponse;
      });
      dataListNeighbor.add(x);
      getNeighbor();
      dataset[x] = '$throughput';
      dataList.add(x);
      dataList.add(throughput);
      dataList.add(cid2);
      dataList.add(RSSI);
      dataList.add(RSRP);
      dataList.add(SINR);
      //緯度と経度を求める
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      double ido = position.latitude.toDouble();
      ido = ((ido*10000).floor())/10000;//(小数点4桁)
      double keido = position.longitude.toDouble();
      keido = ((keido*10000).floor())/10000;//(小数点4桁)
      Latitude = ido.toString();
      Longitude = keido.toString();
    }
  }//ストップウォッチをリセット

  //取得したデータを画面に表示する関数
  void indicateData() {
    dataset.forEach((key, value) {
      print('$key   $value');
      }
    );
    print("$dataList");
  }

  //ログファイルを作成しandroidに保存
  Future<void>  makeTxt(myFile) async{
    String results = "";
    for (var i = 0; i < dataList.length/6; i++) {
      double A = dataList.elementAt(6*i);
      results += "$A   ";
      double B = dataList.elementAt(6*i+1);
      results += "$B   ";
      double C = dataList.elementAt(6*i+2);
      int D = C.toInt();
      results += "$D   ";
      double E = dataList.elementAt(6*i+3);
      results += "$E   ";
      double F = dataList.elementAt(6*i+4);
      results += "$F   ";
      double H = dataList.elementAt(6*i+5);
      results += "$H   ";
      results +="\n";
    }
    String logDirectory = await ExternalPath.getExternalStoragePublicDirectory(ExternalPath.DIRECTORY_DOWNLOADS);
    String logPath = '${logDirectory}/$myFile';
    File textFilePath = File(logPath);
    print('$logPath');
    var raf = textFilePath.openSync(mode: FileMode.write);
    raf.writeStringSync('$results');
  }
  String A = "";
  //ログファイルを作成しandroidに保存
  Future<void>  makeTxtNeighbor(myFile) async {
    int cnt = 0;
    print(dataListNeighborLength.length);
    print(dataListNeighbor.length);
    for (var i = 0; i < dataListNeighborLength.length; i++) {
      int dataNumber = dataListNeighborLength[i]*2+1;
      for (var j = 0; j < dataNumber; j++) {
        String B = dataListNeighbor.elementAt(j+cnt).toString();
        A += "$B   ";
      }
      A += "\n";
      cnt = cnt + dataNumber;
    }
    String logDirectory = await ExternalPath.getExternalStoragePublicDirectory(ExternalPath.DIRECTORY_DOWNLOADS);
    String myFile2 = "Neighbor_$myFile";
    String logPath = '${logDirectory}/$myFile2';
    File textFilePath = File(logPath);
    print('$logPath');
    var raf = textFilePath.openSync(mode: FileMode.write);
    raf.writeStringSync('$A');
  }

  //メイン関数
  void main() async{
    _determinePosition();
    for(int i = 1; i < NUM;i++){
      filename = "myhome_dataset$i.txt";
    }
  }

  //メイン関数
  void main2(fileName) async{
    _determinePosition();
    print(fileName);
    await repetition(fileName);
    await makeTxt(fileName);
    await makeTxtNeighbor(fileName);
  }

  // デザインWidget
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start, //Columnの主軸方向にコンテンツを配置する
          children: <Widget>[

            // スペース
            const SizedBox(
              height: 40,
            ),

            //経過時間表示
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(5.0),
              width: 380,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black54),
              ),
              child: Text(
                '  Time   $timecount(s)',
                //style: Theme.of(context).textTheme.headline4,
                style: const TextStyle(
                  fontSize: 26,
                ),
              ),
            ),

            // スペース
            const SizedBox(
              height: 20,
            ),

            //スループット表示
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(5.0),
              width: 380,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black54),
              ),
              child: Text(
                '  Throughput  $throughput(Mbps)',
                //style: Theme.of(context).textTheme.headline4,
                style: const TextStyle(
                  fontSize: 28,
                ),
              ),
            ),

            // スペース
            const SizedBox(
              height: 20,
            ),

            //RSSI表示
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(5.0),
              width: 380,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black54),
              ),
              child: Text(
                '  RSSI  $RSSI',
                //style: Theme.of(context).textTheme.headline4,
                style: const TextStyle(
                  fontSize: 28,
                ),
              ),
            ),

            // スペース
            const SizedBox(
              height: 20,
            ),

            //RSRP表示
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(5.0),
              width: 380,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black54),
              ),
              child: Text(
                '  RSRP  $RSRP',
                //style: Theme.of(context).textTheme.headline4,
                style: const TextStyle(
                  fontSize: 28,
                ),
              ),
            ),

            // スペース
            const SizedBox(
              height: 20,
            ),

            //SINR表示
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(5.0),
              width: 380,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black54),
              ),
              child: Text(
                '  SINR  $SINR',
                //style: Theme.of(context).textTheme.headline4,
                style: const TextStyle(
                  fontSize: 28,
                ),
              ),
            ),

            // スペース
            const SizedBox(
              height: 20,
            ),

            //cellid表示
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(5.0),
              width: 380,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black54),
              ),
              child: Text(
                '  Cellid   $CellId',
                //style: Theme.of(context).textTheme.headline4,
                style: const TextStyle(
                  fontSize: 28,
                ),
              ),
            ),

            // スペース
            const SizedBox(
              height: 20,
            ),

            //ダウンロード開始ボタン表示
            SizedBox(
              height: 60, // Widgetの高さを指定
              width: 140, // Widgetの幅を指定
              child:RaisedButton.icon(
                  onPressed: () async {
                    // 押したら反応するコードを書く
                    dataset={};
                    main();
                  },
                  icon: const Icon(
                    Icons.file_download,
                    color: Colors.white,
                  ),
                  color: Colors.blue,
                  textColor: Colors.white,
                  label: const Text('測定開始')
              ),
            ),

            // スペース
            const SizedBox(
              height: 20,
            ),

            TextField(
              controller: myController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "保存するファイル名を入力",
                hintText: "my_home.txt",
              ),
            ),

            // スペース
            const SizedBox(
              height: 10,
            ),

            //データ保存ボタン表示
            SizedBox(
            height: 50, // Widgetの高さを指定
            width: 130, // Widgetの幅を指定
            child :RaisedButton(
              child: const Text('データを保存'),
              onPressed: () {
                // 押したら反応するコードを書く
                main2(myController.text);
                },
              ),
            ),

            // スペース
            const SizedBox(
              height: 65,
            ),

            //現在位置を表示ボタン
            SizedBox(
              height: 50, // Widgetの高さを指定
              width: 180, // Widgetの幅を指定
              child :RaisedButton.icon(
                //child: const Text('現在位置を表示'),
                onPressed: () {
                  // 押したら反応するコードを書く
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MapPage()),
                  );
                },
                  icon: const Icon(
                    Icons.map,
                    color: Colors.white,
                  ),
                  color: Colors.green,
                  textColor: Colors.white,
                  label: const Text('現在位置を表示')
              ),
            )
          ],
        ),
      ),
    );
  }
}
