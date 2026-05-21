/// 路由字符串独立于 GetPage 声明，方便导航壳层读取且避免页面和路由表互相导入。
abstract final class AppRouteNames {
  static const home = '/home';
  static const annotation = '/annotation';
  static const videoExtract = '/video-extract';
  static const autoLabel = '/auto-label';
  static const modelVerify = '/model-verify';
  static const formatConvert = '/format-convert';
  static const datasetExport = '/dataset-export';
  static const runLog = '/run-log';
  static const settings = '/settings';
}
