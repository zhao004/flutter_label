enum ImageAnnotationStatus {
  all,
  unlabeled,
  labeled,
  emptyLabel,
  labelError,
  completed,
}

extension ImageAnnotationStatusText on ImageAnnotationStatus {
  String get label {
    return switch (this) {
      ImageAnnotationStatus.all => '全部',
      ImageAnnotationStatus.unlabeled => '未标注',
      ImageAnnotationStatus.labeled => '已标注',
      ImageAnnotationStatus.emptyLabel => '空标签',
      ImageAnnotationStatus.labelError => '标签异常',
      ImageAnnotationStatus.completed => '已完成',
    };
  }
}
