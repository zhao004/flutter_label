import 'package:get/get.dart';

import '../models/project_config.dart';
import '../services/project_service.dart';

class ProjectController extends GetxController {
  ProjectController({ProjectService projectService = const ProjectService()})
    : _projectService = projectService;

  final ProjectService _projectService;

  final currentProject = Rxn<ProjectConfig>();
  final errorMessage = RxnString();

  Future<ProjectConfig> loadProject(String projectFilePath) async {
    errorMessage.value = null;
    try {
      final config = await _projectService.readProject(projectFilePath);
      currentProject.value = config;
      return config;
    } catch (error) {
      errorMessage.value = error.toString();
      rethrow;
    }
  }

  Future<ProjectConfig> createDatasetProject(String datasetDir) async {
    errorMessage.value = null;
    try {
      final config = await _projectService.createDatasetProject(datasetDir);
      currentProject.value = config;
      return config;
    } catch (error) {
      errorMessage.value = error.toString();
      rethrow;
    }
  }

  Future<ProjectConfig> loadDatasetProject(String datasetDir) async {
    errorMessage.value = null;
    try {
      final config = await _projectService.readDatasetProject(datasetDir);
      currentProject.value = config;
      return config;
    } catch (error) {
      errorMessage.value = error.toString();
      rethrow;
    }
  }

  Future<ProjectConfig> saveProject(ProjectConfig config) async {
    errorMessage.value = null;
    try {
      final saved = await _projectService.writeProject(config);
      currentProject.value = saved;
      return saved;
    } catch (error) {
      errorMessage.value = error.toString();
      rethrow;
    }
  }

  Future<void> updateClasses(List<String> classNames) async {
    final project = currentProject.value;
    if (project == null) {
      return;
    }
    await saveProject(project.copyWith(classes: classNames));
  }

  Future<void> updateCompletedImages(Set<String> completedImages) async {
    final project = currentProject.value;
    if (project == null) {
      return;
    }
    final sorted = completedImages.toList()..sort();
    await saveProject(project.copyWith(completedImages: sorted));
  }
}
