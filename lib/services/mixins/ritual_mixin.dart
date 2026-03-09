import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../models/ritual.dart';
import '../../repositories/ritual_repository.dart';

mixin RitualMixin on ChangeNotifier {
  RitualRepository get ritualRepo;

  Future<void> checkRitualResets() async {
    try {
      for (final ritual in ritualRepo.all) {
        await ritual.resetIfNeeded();
      }
    } catch (e, stackTrace) {
      developer.log(
        'Failed to check ritual resets',
        name: 'TaskService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<Ritual?> addRitual(String title, {String? description}) async {
    try {
      const uuid = Uuid();
      final ritual = Ritual(
        id: uuid.v4(),
        title: title,
        description: description,
        createdAt: DateTime.now(),
      );

      await ritualRepo.put(ritual);
      notifyListeners();
      return ritual;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to add ritual: $title',
        name: 'TaskService',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<bool> updateRitual(Ritual ritual) async {
    try {
      await ritual.save();
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to update ritual: ${ritual.id}',
        name: 'TaskService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> toggleRitualCompletion(String ritualId) async {
    try {
      final ritual = ritualRepo.get(ritualId);
      if (ritual == null) return false;
      if (!ritual.isCompleted) {
        await ritual.markCompleted();
      } else {
        ritual.isCompleted = false;
        await ritual.save();
      }
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to toggle ritual completion: $ritualId',
        name: 'TaskService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> deleteRitual(String ritualId) async {
    try {
      await ritualRepo.delete(ritualId);
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      developer.log(
        'Failed to delete ritual: $ritualId',
        name: 'TaskService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
