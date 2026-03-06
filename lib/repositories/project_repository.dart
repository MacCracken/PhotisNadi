import '../models/project.dart';
import 'hive_repository.dart';

class ProjectRepository extends HiveRepository<Project> {
  ProjectRepository() : super('projects', 'ProjectRepository');

  @override
  String getId(Project entity) => entity.id;

  List<Project> get active => where((p) => !p.isArchived);
  List<Project> get archived => where((p) => p.isArchived);
}
