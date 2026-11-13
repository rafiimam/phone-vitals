
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_vitals/services/file_scan.dart';
void main(){
  test('flags zero-byte and partial files',(){
    final issues=scanFiles([{'path':'/Download/a.zip','size':0},{'path':'/Download/b.part','size':1234}]);
    expect(issues.length, 2);
  });
  test('flags duplicates by hash',(){
    final issues=scanFiles([{'path':'/Download/a.mp4','size':2000000,'sha256':'abc'},{'path':'/Download/b.mp4','size':2000000,'sha256':'abc'}]);
    expect(issues.where((i)=>i.kind=='Possible duplicate').length, 2);
  });
}
