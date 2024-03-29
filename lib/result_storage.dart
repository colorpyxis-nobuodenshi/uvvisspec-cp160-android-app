import 'dart:io';
import 'package:external_path/external_path.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uvvisspec_insects_app/settings.dart';
import 'uvvisspecapp.dart';

class ResultStorage {
  Future<File> write(String filename, ResultReport result) async {
    final status = await Permission.storage.request();
    final directory = await ExternalPath.getExternalStoragePublicDirectory(
        ExternalPath.DIRECTORY_DOWNLOADS);
    final file = File('$directory/$filename.csv');

    if (status.isGranted) {
      final wl = result.wl;
      final sp = result.sp;
      final len = sp.length;
      final mdt = result.measureDatetime;
      final pp = result.pp;
      final pw = result.pwl;
      final unit = result.mode == MeasureMode.irradiance
          ? "\uFEFF放射照度[W・m^-2]"
          : result.mode == MeasureMode.insectsIrradiance
              ? "\uFEFF光子数密度[photons・m^-2・S^-1]"
              : "\uFEFF光量子束密度[μmol・m^-2・S^-1]";
      var name = result.filterName;
      await file.writeAsString('\uFEFF測定日, $mdt\r\n', mode: FileMode.append);
      if (result.filterName != "") {
        await file.writeAsString('\uFEFF昆虫タイプ, $name\r\n', mode: FileMode.append);
      }
      await file.writeAsString('\uFEFF波長[nm], $unit\r\n', mode: FileMode.append);
      for (var i = 0; i < len; i++) {
        final v1 = wl[i];
        final v2 = sp[i];
        var contents = '$v1,$v2\r\n';
        await file.writeAsString(contents, mode: FileMode.append);
      }
    }
    return file;
  }
}
