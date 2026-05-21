import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/app_settings.dart';

typedef SettingsFileResolver = Future<File> Function();

/// 负责读取和写入本机配置文件，文件损坏时向上抛出可展示的格式错误。
class AppSettingsService {
  const AppSettingsService({SettingsFileResolver? fileResolver})
    : _fileResolver = fileResolver;

  static const String _settingsFileName = 'app_settings.json';

  final SettingsFileResolver? _fileResolver;

  Future<AppSettings> load() async {
    final file = await _resolveSettingsFile();
    if (!await file.exists()) {
      return const AppSettings.defaults();
    }

    try {
      final content = (await file.readAsString()).trim();
      if (content.isEmpty) {
        return const AppSettings.defaults();
      }
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('应用配置文件必须是 JSON 对象');
      }
      return AppSettings.fromJson(decoded);
    } on FormatException {
      rethrow;
    } on FileSystemException {
      rethrow;
    } catch (error) {
      throw FormatException('读取应用配置失败：$error');
    }
  }

  Future<void> save(AppSettings settings) async {
    final file = await _resolveSettingsFile();
    try {
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(settings.toJson()),
      );
    } on FileSystemException {
      rethrow;
    } catch (error) {
      throw FileSystemException('保存应用配置失败：$error', file.path);
    }
  }

  Future<File> _resolveSettingsFile() async {
    final resolver = _fileResolver;
    if (resolver != null) {
      return resolver();
    }
    final directory = await getApplicationSupportDirectory();
    return File(p.join(directory.path, _settingsFileName));
  }
}
