import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../models/report.dart';

class ReportRepository {
  final FirebaseFirestore _firestore;

  ReportRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _ref =>
      _firestore.collection(AppConstants.reportsCollection);

  Future<void> submit(Report report) async {
    final doc = _ref.doc();
    await doc.set({
      ...report.toMap(),
      'id': doc.id,
    });
  }

  Stream<List<Report>> streamAll() {
    return _ref
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Report.fromFirestore).toList());
  }

  Future<void> updateStatus(String id, String status) async {
    await _ref.doc(id).update({'status': status});
  }
}
