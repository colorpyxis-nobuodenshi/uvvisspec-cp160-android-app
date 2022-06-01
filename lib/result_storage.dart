import 'dart:io';
import 'package:external_path/external_path.dart';
import 'package:permission_handler/permission_handler.dart';
import 'insects.dart';

class ResultStorage{
  Future<File> write(String filename, InsectsSpecResult result) async {
    final status = await Permission.storage.request();
    final directory = await ExternalPath.getExternalStoragePublicDirectory(ExternalPath.DIRECTORY_DOWNLOADS);
    final file = File('$directory/$filename.csv');

    if (status.isGranted) {
      
      final wl = result.wl;
      final sp = result.sp;
      final len = sp.length;
      final mdt = result.measureDatetime;
      final pp = result.pp;
      final pw = result.pwl;
      final unit = result.unit;
      var name = result.insectsName;
      await file.writeAsString('Measure date, $mdt\r\n', mode: FileMode.append);
      await file.writeAsString('Type, $name\r\n', mode: FileMode.append);
      await file.writeAsString('[nm], [$unit]\r\n', mode: FileMode.append);
      for(var i=0;i<len;i++){
        final v1 = wl[i];
        final v2 = sp[i];
        var contents = '$v1,$v2\r\n';
        await file.writeAsString(contents, mode: FileMode.append);
      }
    }
    return file;
  }
}