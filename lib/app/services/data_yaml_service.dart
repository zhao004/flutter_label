import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/annotation_class.dart';

/// 统一读写 YOLO `data.yaml` 中的类别信息。
///
/// 项目只把 `data.yaml.names` 作为外部类别真源；`project.json` 可继续缓存
/// 类别数组，但外部类别文件只维护 `data.yaml`。
class DataYamlService {
  const DataYamlService();

  String defaultDataYamlPath(String datasetDir) {
    return p.join(datasetDir, 'data.yaml');
  }

  Future<List<AnnotationClass>> readClasses(String dataYamlPath) async {
    final names = await readClassNames(dataYamlPath);
    return _classesFromNames(names);
  }

  List<AnnotationClass> readClassesSync(String dataYamlPath) {
    final names = readClassNamesSync(dataYamlPath);
    return _classesFromNames(names);
  }

  Future<List<String>> readClassNames(String dataYamlPath) async {
    final file = File(_normalizePath(dataYamlPath, 'data.yaml 路径'));
    if (!await file.exists()) {
      throw FileSystemException('data.yaml 不存在', file.path);
    }
    return parseClassNames(await file.readAsLines(), sourcePath: file.path);
  }

  List<String> readClassNamesSync(String dataYamlPath) {
    final file = File(_normalizePath(dataYamlPath, 'data.yaml 路径'));
    if (!file.existsSync()) {
      throw FileSystemException('data.yaml 不存在', file.path);
    }
    return parseClassNames(file.readAsLinesSync(), sourcePath: file.path);
  }

  Future<void> writeClasses({
    required String dataYamlPath,
    required List<String> classNames,
  }) async {
    final file = File(_normalizePath(dataYamlPath, 'data.yaml 路径'));
    await file.parent.create(recursive: true);
    await file.writeAsString(buildDataYaml(classNames));
  }

  void writeClassesSync({
    required String dataYamlPath,
    required List<String> classNames,
  }) {
    final file = File(_normalizePath(dataYamlPath, 'data.yaml 路径'));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(buildDataYaml(classNames));
  }

  String buildDataYaml(List<String> classNames) {
    final names = validateClassNames(classNames);
    final buffer = StringBuffer()
      ..writeln('path: .')
      ..writeln('train: images/train')
      ..writeln('val: images/val')
      ..writeln('test: images/test')
      ..writeln();
    if (names.isEmpty) {
      buffer.writeln('names: []');
    } else {
      buffer.writeln('names:');
      for (var index = 0; index < names.length; index++) {
        buffer.writeln('  $index: ${_yamlString(names[index])}');
      }
    }
    return buffer.toString();
  }

  List<String> parseClassNames(
    List<String> lines, {
    required String sourcePath,
  }) {
    var hasNames = false;
    List<String>? listNames;
    Map<int, String>? mapNames;

    for (var index = 0; index < lines.length; index++) {
      final rawLine = lines[index];
      final line = _stripComment(rawLine).trimRight();
      final trimmed = line.trim();
      if (trimmed.isEmpty || !trimmed.startsWith('names:')) {
        continue;
      }

      if (hasNames) {
        throw FormatException('$sourcePath 只能包含一个 names 字段');
      }
      hasNames = true;
      final inline = trimmed.substring('names:'.length).trim();
      if (inline.isNotEmpty) {
        final parsed = _parseInlineNames(inline, sourcePath);
        listNames = parsed.listNames;
        mapNames = parsed.mapNames;
        continue;
      }

      final blockList = <String>[];
      final blockMap = <int, String>{};
      var detectedBlockKind = _NamesBlockKind.unknown;
      while (index + 1 < lines.length) {
        final nextRawLine = lines[index + 1];
        final nextLine = _stripComment(nextRawLine).trimRight();
        final nextTrimmed = nextLine.trim();
        if (nextTrimmed.isEmpty) {
          index++;
          continue;
        }
        if (!_isIndented(nextRawLine)) {
          break;
        }

        final entry = _parseBlockNameEntry(nextTrimmed, sourcePath);
        if (entry.index == null) {
          if (detectedBlockKind == _NamesBlockKind.map) {
            throw FormatException('$sourcePath 的 names 列表和编号格式不能混用');
          }
          detectedBlockKind = _NamesBlockKind.list;
          blockList.add(entry.name);
        } else {
          if (detectedBlockKind == _NamesBlockKind.list) {
            throw FormatException('$sourcePath 的 names 列表和编号格式不能混用');
          }
          detectedBlockKind = _NamesBlockKind.map;
          _putIndexedName(blockMap, entry.index!, entry.name, sourcePath);
        }
        index++;
      }
      listNames = detectedBlockKind == _NamesBlockKind.map ? null : blockList;
      mapNames = detectedBlockKind == _NamesBlockKind.map ? blockMap : null;
    }

    if (!hasNames) {
      throw FormatException('$sourcePath 缺少 names 字段');
    }
    final names = mapNames == null
        ? (listNames ?? const <String>[])
        : _orderedMapNames(mapNames, sourcePath);
    return List.unmodifiable(validateClassNames(names));
  }

  List<String> validateClassNames(List<String> classNames) {
    final names = classNames.map((name) => name.trim()).toList();
    if (names.any((name) => name.isEmpty)) {
      throw const FormatException('类别名称不能为空');
    }
    if (names.toSet().length != names.length) {
      throw const FormatException('类别名称不能重复');
    }
    return names;
  }

  List<AnnotationClass> _classesFromNames(List<String> names) {
    return [
      for (var index = 0; index < names.length; index++)
        AnnotationClass(id: index, name: names[index]),
    ];
  }

  String _normalizePath(String value, String fieldName) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw FormatException('$fieldName 不能为空');
    }
    return p.normalize(trimmed);
  }

  String _stripComment(String line) {
    var inSingleQuote = false;
    var inDoubleQuote = false;
    for (var index = 0; index < line.length; index++) {
      final char = line[index];
      if (char == "'" && !inDoubleQuote) {
        inSingleQuote = !inSingleQuote;
        continue;
      }
      if (char == '"' && !inSingleQuote) {
        inDoubleQuote = !inDoubleQuote;
        continue;
      }
      if (char == '#' && !inSingleQuote && !inDoubleQuote) {
        return line.substring(0, index);
      }
    }
    return line;
  }

  bool _isIndented(String line) {
    return line.startsWith(' ') || line.startsWith('\t');
  }

  ({List<String>? listNames, Map<int, String>? mapNames}) _parseInlineNames(
    String value,
    String sourcePath,
  ) {
    if (value == '[]') {
      return (listNames: const [], mapNames: null);
    }
    if (value == '{}') {
      return (listNames: null, mapNames: const {});
    }
    if (value.startsWith('[') && value.endsWith(']')) {
      final body = value.substring(1, value.length - 1).trim();
      if (body.isEmpty) {
        return (listNames: const [], mapNames: null);
      }
      return (
        listNames: _splitYamlInlineItems(
          body,
        ).map(_unquoteYamlString).toList(growable: false),
        mapNames: null,
      );
    }
    if (value.startsWith('{') && value.endsWith('}')) {
      final body = value.substring(1, value.length - 1).trim();
      final result = <int, String>{};
      if (body.isNotEmpty) {
        for (final item in _splitYamlInlineItems(body)) {
          final separator = _indexOfYamlSeparator(item);
          if (separator < 0) {
            throw FormatException('$sourcePath 的 names 内联编号格式非法');
          }
          final key = item.substring(0, separator).trim();
          final classIndex = int.tryParse(key);
          if (classIndex == null || classIndex < 0) {
            throw FormatException('$sourcePath 的 names 编号必须是非负整数');
          }
          final name = _unquoteYamlString(item.substring(separator + 1).trim());
          _putIndexedName(result, classIndex, name, sourcePath);
        }
      }
      return (listNames: null, mapNames: result);
    }
    throw FormatException('$sourcePath 的 names 字段格式暂不支持');
  }

  ({int? index, String name}) _parseBlockNameEntry(
    String line,
    String sourcePath,
  ) {
    if (line.startsWith('- ')) {
      return (index: null, name: _unquoteYamlString(line.substring(2).trim()));
    }

    final separatorIndex = _indexOfYamlSeparator(line);
    if (separatorIndex >= 0) {
      final key = line.substring(0, separatorIndex).trim();
      final classIndex = int.tryParse(key);
      if (classIndex == null || classIndex < 0) {
        throw FormatException('$sourcePath 的 names 编号必须是非负整数');
      }
      return (
        index: classIndex,
        name: _unquoteYamlString(line.substring(separatorIndex + 1).trim()),
      );
    }
    throw FormatException('$sourcePath 的 names 条目格式非法');
  }

  void _putIndexedName(
    Map<int, String> target,
    int index,
    String name,
    String sourcePath,
  ) {
    if (target.containsKey(index)) {
      throw FormatException('$sourcePath 的 names 编号重复：$index');
    }
    target[index] = name;
  }

  List<String> _orderedMapNames(Map<int, String> names, String sourcePath) {
    if (names.isEmpty) {
      return const [];
    }
    final indexes = names.keys.toList()..sort();
    for (var expected = 0; expected < indexes.length; expected++) {
      if (indexes[expected] != expected) {
        throw FormatException('$sourcePath 的 names 编号必须从 0 开始连续');
      }
    }
    return [for (final index in indexes) names[index]!];
  }

  List<String> _splitYamlInlineItems(String value) {
    final items = <String>[];
    var inSingleQuote = false;
    var inDoubleQuote = false;
    var start = 0;
    for (var index = 0; index < value.length; index++) {
      final char = value[index];
      if (char == "'" && !inDoubleQuote) {
        inSingleQuote = !inSingleQuote;
        continue;
      }
      if (char == '"' && !inSingleQuote) {
        inDoubleQuote = !inDoubleQuote;
        continue;
      }
      if (char == ',' && !inSingleQuote && !inDoubleQuote) {
        items.add(value.substring(start, index).trim());
        start = index + 1;
      }
    }
    items.add(value.substring(start).trim());
    return items;
  }

  int _indexOfYamlSeparator(String value) {
    var inSingleQuote = false;
    var inDoubleQuote = false;
    for (var index = 0; index < value.length; index++) {
      final char = value[index];
      if (char == "'" && !inDoubleQuote) {
        inSingleQuote = !inSingleQuote;
        continue;
      }
      if (char == '"' && !inSingleQuote) {
        inDoubleQuote = !inDoubleQuote;
        continue;
      }
      if (char == ':' && !inSingleQuote && !inDoubleQuote) {
        return index;
      }
    }
    return -1;
  }

  String _unquoteYamlString(String value) {
    if (value.length >= 2 && value.startsWith("'") && value.endsWith("'")) {
      return value.substring(1, value.length - 1).replaceAll("''", "'");
    }
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      return value.substring(1, value.length - 1).replaceAll(r'\"', '"');
    }
    return value;
  }

  String _yamlString(String value) {
    return "'${value.replaceAll("'", "''")}'";
  }
}

enum _NamesBlockKind { unknown, list, map }
