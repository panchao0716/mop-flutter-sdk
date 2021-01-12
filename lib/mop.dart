import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:mop/api.dart';

typedef MopEventCallback = void Function(dynamic event);
typedef MopEventErrorCallback = void Function(dynamic event);

typedef ExtensionApiHandler = Future Function(dynamic params);

class Mop {
  static final Mop _instance = new Mop._internal();
  MethodChannel _channel;
  EventChannel _mopEventChannel;
  int eventId = 0;
  List<Map<String, dynamic>> _mopEventQueye = <Map<String, dynamic>>[];

  Map<String, ExtensionApiHandler> _extensionApis = {};

  factory Mop() {
    return _instance;
  }

  Mop._internal() {
    print('mop: _internal');
    // init
    _channel = new MethodChannel('mop');
    _channel.setMethodCallHandler(_handlePlatformMethodCall);
    _mopEventChannel = new EventChannel('plugins.mop.finogeeks.com/mop_event');
    _mopEventChannel.receiveBroadcastStream().listen((dynamic value) {
      print('matrix: receiveBroadcastStream $value');
      for (Map m in _mopEventQueye) {
        if (m['event'] == value['event']) {
          m['MopEventCallback'](value['body']);
        }
      }
    }, onError: (dynamic value) {
      // failure(value);
    });
  }

  static Mop get instance => _instance;

  Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  Future<dynamic> _handlePlatformMethodCall(MethodCall call) async {
    print("_handlePlatformMethodCall: method:${call.method}");
    if (call.method.startsWith("extensionApi:")) {
      final name = call.method.substring("extensionApi:".length);
      final handler = _extensionApis[name];
      if (handler != null) {
        return await handler(call.arguments);
      }
    }
  }

  ///
  ///
  /// initialize mop miniprogram engine.
  /// 初始化小程序
  /// [appkey] is required. it can be getted from api.finclip.com
  /// [secret] is required. it can be getted from api.finclip.com
  /// [apiServer] is optional. the mop server address. default is https://mp.finogeek.com
  /// [apiPrefix] is optional. the mop server prefix. default is /api/v1/mop
  /// [cryptType] is optional. cryptType, should be MD5/SM
  /// [disablePermission] is optional.
  ///
  Future<Map> initialize(String appkey, String secret,
      {String apiServer,
      String apiPrefix,
      String cryptType,
      bool disablePermission}) async {
    final Map ret = await _channel.invokeMethod('initialize', {
      'appkey': appkey,
      'secret': secret,
      'apiServer': apiServer,
      'apiPrefix': apiPrefix,
      'cryptType': cryptType,
      'disablePermission': disablePermission
    });
    return ret;
  }

  /// open the miniprogram [appId] from the  mop server.
  /// 打开小程序
  /// [appId] is required.
  /// [path] is miniprogram open path. example /pages/index/index
  /// [query] is miniprogram query parameters. example key1=value1&key2=value2
  /// [sequence] is miniprogram sequence. example 0,1.2.3,4,5...
  /// [apiServer] is optional. the mop server address. default is https://mp.finogeek.com
  /// [apiPrefix] is optional. the mop server prefix. default is /api/v1/mop
  /// [fingerprint] is optional. the mop sdk fingerprint. is nullable
  /// [cryptType] is optional. cryptType, should be MD5/SM
  Future<Map> openApplet(
    final String appId, {
    final String path,
    final String query,
    final int sequence,
    final String apiServer,
    final String apiPrefix,
    final String fingerprint,
    final String cryptType,
  }) async {
    Map<String, Object> params = {'appId': appId};
    Map param = {};
    if (path != null) param["path"] = path;
    if (query != null) param["query"] = query;
    if (param.length > 0) params["params"] = param;
    if (sequence != null) params["sequence"] = sequence;
    if (apiServer != null) params["apiServer"] = apiServer;
    if (apiPrefix != null) params["apiPrefix"] = apiPrefix;
    if (fingerprint != null) params["fingerprint"] = fingerprint;
    if (cryptType != null) params["cryptType"] = cryptType;
    final Map ret = await _channel.invokeMethod('openApplet', params);
    return ret;
  }

  ///
  ///  get current using applet
  ///  获取当前正在使用的小程序信息
  ///  {appId,name,icon,description,version,thumbnail}
  ///
  ///
  Future<Map<String, dynamic>> currentApplet() async {
    final ret = await _channel.invokeMapMethod("currentApplet");
    return Map<String, dynamic>.from(ret);
  }

  ///
  /// close all running applets
  /// 关闭当前打开的所有小程序
  ///
  Future closeAllApplets() async {
    return await _channel.invokeMethod("closeAllApplets");
  }

  ///
  /// clear applets cache
  /// 清除缓存的小程序
  ///
  Future clearApplets() async {
    return await _channel.invokeMethod("clearApplets");
  }

  ///
  /// 获取运行时版本号
  ///
  Future<String> sdkVersion() async {
    return await _channel
        .invokeMapMethod("sdkVersion")
        .then((value) => value["data"]);
  }

  ///
  /// register handler to provide custom info or behaviour
  /// 注册小程序事件处理
  ///
  void registerAppletHandler(AppletHandler handler) {
    _extensionApis["forwardApplet"] = (params) async {
      handler.forwardApplet(Map<String, dynamic>.from(params));
    };
    _extensionApis["getUserInfo"] = (params) {
      return handler.getUserInfo();
    };
    _extensionApis["getCustomMenus"] = (params) async {
      final res = await handler.getCustomMenus(params["appId"]);
      res?.map((e) => e.toJson());
      return res;
    };
    _extensionApis["onCustomMenuClick"] = (params) {
      return handler.onCustomMenuClick(params["appId"], params["menuId"]);
    };
    _channel.invokeMethod("registerAppletHandler");
  }

  ///
  /// register extension api
  /// 注册拓展api
  ///
  void registerExtensionApi(String name, ExtensionApiHandler handler) {
    _extensionApis[name] = handler;
    _channel.invokeMethod("registerExtensionApi", {"name": name});
  }
}
