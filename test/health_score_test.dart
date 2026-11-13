
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_vitals/models/diagnostics.dart';
import 'package:phone_vitals/services/health_score.dart';
void main(){
  test('healthy phone scores high',(){
    final r=evaluateHealth(b: const BatteryDetail(level:80,health:'Good',status:'Discharging',tempC:32,voltageMv:4100,technology:'Li-ion',cycleCount:200,currentNowUa:-200000,chargeCounterUah:2000000), ms: const MemoryStorage(totalRamMb:8192,availRamMb:3000,lowMemory:false,totalStorageGb:128,freeStorageGb:60,storageUsedPct:50,uptimeHours:10));
    expect(r.score, greaterThanOrEqualTo(85));
  });
  test('hot battery + full storage is penalised',(){
    final r=evaluateHealth(b: const BatteryDetail(level:30,health:'Good',status:'Discharging',tempC:46,voltageMv:3600,technology:'Li-ion',cycleCount:1200,currentNowUa:-900000,chargeCounterUah:500000), ms: const MemoryStorage(totalRamMb:8192,availRamMb:500,lowMemory:true,totalStorageGb:128,freeStorageGb:2,storageUsedPct:98,uptimeHours:1));
    expect(r.score, lessThan(50)); expect(r.warnings.length, greaterThan(2));
  });
}
