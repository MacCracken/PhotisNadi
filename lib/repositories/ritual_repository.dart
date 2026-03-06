import '../models/ritual.dart';
import 'hive_repository.dart';

class RitualRepository extends HiveRepository<Ritual> {
  RitualRepository() : super('rituals', 'RitualRepository');

  @override
  String getId(Ritual entity) => entity.id;
}
