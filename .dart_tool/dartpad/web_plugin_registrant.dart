// Flutter web plugin registrant file.
//
// Generated file. Do not edit.
//

// @dart = 2.13
// ignore_for_file: type=lint

import 'package:flutter_keyboard_visibility_temp_fork/flutter_keyboard_visibility_web.dart';
import 'package:image_picker_for_web/image_picker_for_web.dart';
import 'package:quill_native_bridge_web/quill_native_bridge_web.dart';
import 'package:shared_preferences_web/shared_preferences_web.dart';
import 'package:url_launcher_web/url_launcher_web.dart';
import 'package:video_player_web/video_player_web.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

void registerPlugins([final Registrar? pluginRegistrar]) {
  final Registrar registrar = pluginRegistrar ?? webPluginRegistrar;
  FlutterKeyboardVisibilityTempForkWeb.registerWith(registrar);
  ImagePickerPlugin.registerWith(registrar);
  QuillNativeBridgeWeb.registerWith(registrar);
  SharedPreferencesPlugin.registerWith(registrar);
  UrlLauncherPlugin.registerWith(registrar);
  VideoPlayerPlugin.registerWith(registrar);
  registrar.registerMessageHandler();
}
