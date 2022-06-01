import 'dart:collection';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'uvvisspec.dart';

enum InsectsSpectralIntensityType { Azamiuma, Hachi, GaA, GaB, GaC, None }

Map<InsectsSpectralIntensityType, String> insectNameMap = {
  InsectsSpectralIntensityType.Azamiuma: "thrips",
  InsectsSpectralIntensityType.Hachi: "bee",
  InsectsSpectralIntensityType.GaA: "moth(350)",
  InsectsSpectralIntensityType.GaB: "moth(550)",
  InsectsSpectralIntensityType.GaC: "moth(350+550)",
  InsectsSpectralIntensityType.None: "none",
  };

class InsectsSpecResult {
  List<double> sp = [];
  List<double> wl = [];
  // List<double> sp2 = [];
  // List<double> sp3 = [];
  // List<double> sp4 = [];
  double pwl = 0.0;
  double ir = 0.0;
  double pp = 0.0;
  List<double> spRaw = [];
  List<double> wlRaw = [];
  int wlRangeMin = 310;
  int wlRangeMax = 800;
  InsectsSpectralIntensityType isi = InsectsSpectralIntensityType.Azamiuma;
  String insectsName = "";
  String measureDatetime = "";
  String unit = "";
}

class Settings {
  Unit unit = Unit.w;
  InsectsSpectralIntensityType type = InsectsSpectralIntensityType.None;
  double sumRangeMin = 310;
  double sumRangeMax = 800;
  String deviceExposureTime = "AUTO";
}

class UVVisSpecResultConverterForInsects {
  var _map = HashMap<InsectsSpectralIntensityType, List<double>>();

  void initialize() {
    
    Future(() async {
      _map = await _readIncectsSpectralIntensity();
    });
  }

  Future<HashMap<InsectsSpectralIntensityType, List<double>>> _readIncectsSpectralIntensity() async {
    final loadedData = await rootBundle.loadString('assets/insectsspectralintensity.csv');
    var isil1 = <double>[];
    var isil2 = <double>[];
    var isil3 = <double>[];
    var isil4 = <double>[];
    var isil5 = <double>[];
    
    var lines = loadedData.split('\n');
    for(var i=1;i<lines.length;i++){
      //debugPrint('${lines[i]}');
      var v = lines[i].split((','));
      isil1.add(double.parse(v[1]));
      isil2.add(double.parse(v[2]));
      isil3.add(double.parse(v[3]));
      isil4.add(double.parse(v[4]));
      isil5.add(double.parse(v[5]));
    }
    var map = HashMap<InsectsSpectralIntensityType, List<double>>();
    map[InsectsSpectralIntensityType.Azamiuma] = isil1;
    map[InsectsSpectralIntensityType.Hachi] = isil2;
    map[InsectsSpectralIntensityType.GaA] = isil3;
    map[InsectsSpectralIntensityType.GaB] = isil4;
    map[InsectsSpectralIntensityType.GaC] = isil5;
    
    return map;
  }

  Future<InsectsSpecResult> convert(Settings settings, UVVisSpecDeviceResult uvsr) async {
    final unit = settings.unit;
    final p1 = [...uvsr.sp];
    final wl = [...uvsr.wl];
    var p2 = List.generate(p1.length, (index) => 1.0);
    var p3 = List.generate(p1.length, (index) => 1.0);
    var p4 = List.generate(p1.length, (index) => 1.0);
    
    final l = _map[settings.type];
    if(l != null) {
      for(var i=0;i<p1.length;i++)
      {
        p2[i] = p1[i] * l[i];
        p3[i] = p2[i] * wl[i] * 5.03E+15;
        p4[i] = p2[i] * wl[i] / 0.1237 * 10E-3;
      }
    }
    else
    {
      for(var i=0;i<p1.length;i++)
      {
        p2[i] = p1[i];
        p3[i] = p2[i] * wl[i] * 5.03E+15;
        p4[i] = p2[i] * wl[i] / 0.1237 * 10E-3;
      }
    }
    var p = unit == Unit.w ? p2 : unit == Unit.photon ? p3 : unit == Unit.mol ? p4 : p2;
    var p5 = [...p];
    final l1 = settings.sumRangeMin;
    final l2 = settings.sumRangeMax;
    for(var i=0; i<wl.length; i++) {
      if(wl[i] < l1){
        p[i] = 0;
      }
      if(wl[i] > l2){
        p[i] = 0;
      }
    }
    var pp = p.reduce(max);
    var pwl = wl[p.indexWhere((x) => (x == pp))];
    var ir = 0.0;
    for(var i=0; i<wl.length; i++) {
      //if(wl[i] >= l1 && wl[i] <= l2){
        ir += p[i];
      //}
    }
    
    var res = InsectsSpecResult();
    res.sp = p5;
    res.wl = wl;
    res.ir = ir;
    res.pp = pp;
    res.pwl = pwl;
    res.insectsName = insectNameMap[settings.type]!;
    res.unit = unitMap[settings.unit]!;
    return  res;
  }
}