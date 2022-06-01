import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'uvvisspec.dart';
import 'settings.dart';
import 'result_storage.dart';
import 'insects.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const Home(),
      theme: ThemeData(
      brightness: Brightness.dark,
      appBarTheme: const AppBarTheme(
        color: Colors.blueGrey
      ),
    ),
    );
  }
}

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return HomeState();
  }}

class HomeState extends State<Home> {
  final ResultStorage storage = ResultStorage();
  final UvVisSpecDevice device = UvVisSpecDevice();
  final UVVisSpecResultConverterForInsects resultConverter = UVVisSpecResultConverterForInsects();

  var _peekPower = 0.0;
  var _peekWavelength = 0.0;
  var _irradiance = 0.0;
  var _unit = "W/m2";

  late List<double> _spectralData = List.generate(50, (index) => 1.0);
  late List<double> _spectralWl = List.generate(50, (index) => 0.0);
  late InsectsSpecResult _currentResult;
  var _settings = Settings();
  var _showWarning = true;
  var _measuring = false;
  var _connected = false;

  @override
  void initState() {
    super.initState();
    
    resultConverter.initialize();

    device.statusStream.listen((event) async { 
      if(event.detached) {
        showDialog(context: context, barrierDismissible: false, builder: (x) => AlertDialog(
          content: const Text('デバイスが切断されました.\r\nアプリを終了します.'),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed:  () {
                SystemNavigator.pop();
              },
          ),
          ],
        ),);

        await Future.delayed(const Duration(seconds: 2));
        Navigator.of(context).pop();
        SystemNavigator.pop();
      }
      setState(() {
        _connected = event.connected;
        _measuring = event.measurestarted;
        
        if(event.devicewarn || event.deviceerror) {
          _showWarning = true;
          return;
        }
        _showWarning = false;
      });
    });
    device.resultStream.listen((event) async { 
      
      _currentResult = await resultConverter.convert(_settings, event);

      var p1 = [..._currentResult.sp];
      var wl1 = [..._currentResult.wl];
      var pp1 = _currentResult.pp;
      var ir1 = _currentResult.ir;
      var pwl1 = _currentResult.pwl;
      for(var i=0;i<p1.length;i++) {
        p1[i] /= pp1;
      }
      setState(() {
        _spectralData = p1;
        _spectralWl = wl1;
        _irradiance = ir1;
        _peekWavelength = pwl1;  
        _peekPower = pp1;
      });
    });

    Future(() async{
      await device.initialize();
      //await device.measStart();
    });
  }


  @override
  void dispose() {
    super.dispose();
    Future(() async{
      //await device.measStop();
      await device.deinitialize();
    });
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UVVIS Spectrometer'),
        actions: <Widget>[
           //(_connected) ? const Icon(Icons.check_circle_outline) : const Icon(Icons.highlight_off_outlined),
           (_showWarning) ? const Icon(Icons.warning) : const SizedBox.shrink(),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await device.measStop();
              var prevExp = _settings.deviceExposureTime;
              _settings = await Navigator.push(
                context, MaterialPageRoute(builder: (context) => SettingsPage(_settings)));

                setState(() {
                  _unit = unitMap[_settings.unit]!;
                });

                if(_settings.deviceExposureTime != prevExp) {
                  await device.changeExposureTime(_settings.deviceExposureTime);
                }
                //debugPrint(_settings.deviceExposureTime);
                
                await device.measStart();
            },
          ),
        ],
      ),
      body: Center(
          child: Column(children: <Widget>[
        SizedBox(
          width: 700,
          height: 240,
          child: Card(
            //color: Colors.white12,
            child: SpectralLineChart.create(_spectralWl, _spectralData, _settings.sumRangeMin, _settings.sumRangeMax),) 
        ),
          SizedBox(
          height: 100,
          width: 700,
          child: Card(
              child: Column(
                children: <Widget>[
                  const Text("ピーク光強度", 
                    style: TextStyle(
                      fontSize: 18,
                    ),
                    ),
                  Text(_peekPower.toStringAsExponential(3), 
                        style:  TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 36,
                          color: Colors.blue.shade600,
                          ),
                      ),
                  Text(_unit+"/nm", style: const TextStyle(fontSize: 18)),
                  
                ],
              ),
            ),
          ),
          SizedBox(
          height: 100,
          width: 700,
          child: Card(
              child: Column(
                children: <Widget>[
                  const Text("ピーク波長", 
                    style: TextStyle(
                      fontSize: 18,
                    ),
                    ),
                  Text(_peekWavelength.toStringAsFixed(0), 
                        style:  TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 36,
                          color: Colors.blue.shade600,
                          ),
                      ),
                  const Text("nm", style: TextStyle(fontSize: 18)),
                  
                ],
              ),
            ),
          ),
        SizedBox(
          height: 100,
          width: 700,
          child: Card(
              child: Column(
                children: <Widget>[
                  const Text("総光強度",
                    style: TextStyle(fontSize: 18),
                    ),
                  Text(_irradiance.toStringAsExponential(3), 
                        style:  TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 36,
                          color: Colors.blue.shade600,
                          ),
                      ),
                  Text(_unit, style: const TextStyle(fontSize: 18)),
                ],
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(10, 10, 10, 10),
           child: Row(
             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        SizedBox(
          height: 80,
          width: 80,
          child: ElevatedButton(
              onPressed: () async {
                await device.measStop();
                
                var res = await showDialog(context: context, barrierDismissible: false, builder: (x) => AlertDialog(
                  content: const Text('ダーク補正をします.\r\n遮光してください.'),
                  actions: [
                   TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(0),
                ),
                TextButton(
                  child: const Text('OK'),
                  onPressed: () => Navigator.of(context).pop(1),
                ),
                  ],
                ));

                if(res == 1){

                  showDialog(context: context, builder: (x) {
                    return AlertDialog(
                      content: Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            child: SizedBox(
                                child: const CircularProgressIndicator(
                                    strokeWidth: 3
                                ),
                                width: 32,
                                height: 32
                            ),
                            padding: const EdgeInsets.only(bottom: 16)
                          ),
                          Padding(
                            child: const Text(
                              'しばらくお待ちください...',
                              style: const TextStyle(
                                fontSize: 16
                              ),
                              textAlign: TextAlign.center,
                            ),
                            padding: const EdgeInsets.only(bottom: 4)
                          )
                        ]
                    )
                  ),
                    );
                  });
                // showGeneralDialog(
                //   context: context,
                //   barrierDismissible: false,
                //   //transitionDuration: const Duration(seconds: 60),
                //   barrierColor: Colors.black.withOpacity(0.5),
                //   pageBuilder: (BuildContext context, Animation animation, Animation secondaryAnimation) {
                //     return Center(
                //       child: SizedBox(
                //         height: 300,
                //         width: 300,
                //         child: Column(
                //         // ignore: prefer_const_literals_to_create_immutables
                //         children: [
                //           const CircularProgressIndicator(),
                //           const Text("ダーク補正中...\r\nしばらくお待ちください.", style: TextStyle(fontSize: 18, fontWeight: FontWeight.normal, color: Colors.black87, decoration: TextDecoration.none),)
                //         ]
                //       ),
                //       ),
                //     );
                    
                //   }
                // );

                await device.dark();
                
                Navigator.of(context).pop();

                // dialog = const AlertDialog(
                //   content: Text('ダーク補正しました.'),
                // );
                // await showDialog(context: context, builder: (x) => dialog);
                }
                await device.measStart();
              },
              child: const Text("DARK"),
              style: ElevatedButton.styleFrom(
                shape: const StadiumBorder(),
                primary: Colors.white38
              ),
            ),
        ),
        SizedBox(
          height: 90,
          width: 90,
          child: ElevatedButton(
               onPressed: () async {
                 setState(() {
                 });
                 if(_measuring){
                    await device.measStop();
                    return;
                  }
                  await device.measStart();
               },
              child: !_measuring ? const Text("MEAS") : const Text("HOLD"),
              style: ElevatedButton.styleFrom(
                shape: const StadiumBorder(),
                primary: !_measuring ? Colors.green : Colors.blue.shade800
              ),
            ),
        ),
        SizedBox(
          height: 80,
          width: 80,
          child: ElevatedButton(
               onPressed: () async {
                  final now = DateTime.now();
                  final filename = '${now.year}${now.month.toString().padLeft(2,"0")}${now.day.toString().padLeft(2,"0")}${now.hour.toString().padLeft(2,"0")}${now.minute.toString().padLeft(2,"0")}${now.second.toString().padLeft(2,"0")}';
                  _currentResult.measureDatetime = now.toString();
                  storage.write(filename, _currentResult);
                  var dialog = const AlertDialog(
                  content: Text("保存しました."),
                );
                await showDialog(context: context, builder: (x) => dialog);
               },
              child: const Text("STORE"),
              style: ElevatedButton.styleFrom(
                shape: const StadiumBorder(),
                primary: Colors.orange
              ),
            ),
        ),
        
            
      ],
    ),
        ),
      ])),
      );
  }
}

class SpectralLineChart extends StatelessWidget {
  final charts.Series<dynamic, num>? series;
  final bool? animate;
  final double sumRangeMin;
  final double sumRangeMax;
  SpectralLineChart(this.series, this.animate, this.sumRangeMin, this.sumRangeMax);

  factory SpectralLineChart.create(List<double> wl, List<double> opticalPower, double sumRangeMin, double sumRangeMax)
  {
    return SpectralLineChart(_createSpectralChartData(wl, opticalPower), false, sumRangeMin, sumRangeMax);
  }

  static charts.Series<LinearSpectral, int> _createSpectralChartData(List<double> wl, List<double> opticalPower)
  {
    List<LinearSpectral> l = [];
    for(var i=0;i<wl.length;i++)
    {
      l.add(LinearSpectral(wl[i], opticalPower[i]));
    }

    return 
      charts.Series<LinearSpectral, int>(
        id: 'SpectralData',
        colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
        // areaColorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
        domainFn: (LinearSpectral sp, _) => sp.waveLength.toInt(),
        measureFn: (LinearSpectral sp, _) => sp.opticalPower,
        data: l,
        strokeWidthPxFn: (datum, index) => 3,

      );
  }
  @override
  Widget build(BuildContext context) {
    return charts.LineChart(
        [series!],
        animate: animate,
        defaultRenderer:
            charts.LineRendererConfig(includeArea: true, stacked: false, radiusPx: 6, roundEndCaps: true),
        domainAxis: const charts.NumericAxisSpec(
          viewport: charts.NumericExtents(300.0, 800.0),
          showAxisLine: false,
          renderSpec: charts.SmallTickRendererSpec(
            labelStyle: charts.TextStyleSpec(
              fontSize: 15,
              color: charts.MaterialPalette.white,
            ),
            tickLengthPx: 0,
          ),
          
          tickProviderSpec: charts.BasicNumericTickProviderSpec(
            dataIsInWholeNumbers: true,
            desiredTickCount: 9)
        ),
        primaryMeasureAxis: const charts.NumericAxisSpec(
          renderSpec: charts.NoneRenderSpec(),
          showAxisLine: false
        ),
        
        behaviors: [
          charts.RangeAnnotation([
            // charts.RangeAnnotationSegment(310, sumRangeMin, charts.RangeAnnotationAxisType.domain, color: charts.ColorUtil.fromDartColor(Colors.white10)),
            // charts.RangeAnnotationSegment(sumRangeMax, 800, charts.RangeAnnotationAxisType.domain, color: charts.ColorUtil.fromDartColor(Colors.white10)),
            charts.RangeAnnotationSegment(sumRangeMin, sumRangeMax, charts.RangeAnnotationAxisType.domain, color: charts.ColorUtil.fromDartColor(Colors.black12)),
            // charts.LineAnnotationSegment(
            // sumRangeMin, charts.RangeAnnotationAxisType.domain,
            // color: charts.ColorUtil.fromDartColor(Colors.black12), strokeWidthPx: 3),
            // charts.LineAnnotationSegment(
            // sumRangeMax, charts.RangeAnnotationAxisType.domain,
            // color: charts.ColorUtil.fromDartColor(Colors.black12), strokeWidthPx: 3),
            ]),
              ],
          );
  }
}

class LinearSpectral {
  final double waveLength;
  final double opticalPower;

  LinearSpectral(this.waveLength, this.opticalPower);
}