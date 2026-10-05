import 'package:drift_flutter/drift_flutter.dart';

import 'database.dart';

AppDatabase openAppDatabase() => AppDatabase(driftDatabase(name: 'own_yute'));
