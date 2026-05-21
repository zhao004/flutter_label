enum DatasetSplit {
  train,
  val,
  test;

  String get directoryName => name;

  String get label {
    return switch (this) {
      DatasetSplit.train => 'train',
      DatasetSplit.val => 'val',
      DatasetSplit.test => 'test',
    };
  }
}

enum DatasetFolderFilter {
  all,
  val,
  train,
  test;

  String get label {
    return switch (this) {
      DatasetFolderFilter.all => '全部',
      DatasetFolderFilter.val => 'val',
      DatasetFolderFilter.train => 'train',
      DatasetFolderFilter.test => 'test',
    };
  }

  DatasetSplit? get split {
    return switch (this) {
      DatasetFolderFilter.all => null,
      DatasetFolderFilter.val => DatasetSplit.val,
      DatasetFolderFilter.train => DatasetSplit.train,
      DatasetFolderFilter.test => DatasetSplit.test,
    };
  }

  bool matchesRelativePath(String relativePath) {
    if (this == DatasetFolderFilter.all) {
      return true;
    }
    final target = split!.directoryName.toLowerCase();
    final segments = relativePath
        .replaceAll('\\', '/')
        .split('/')
        .where((segment) => segment.trim().isNotEmpty)
        .map((segment) => segment.toLowerCase())
        .toList(growable: false);
    if (segments.isEmpty) {
      return false;
    }
    if (segments.first == target) {
      return true;
    }
    if (segments.length < 2) {
      return false;
    }
    return (segments.first == 'images' || segments.first == 'labels') &&
        segments[1] == target;
  }
}
