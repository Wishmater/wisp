import 'package:xdg_mime/xdg_mime.dart';

late final MimeDatabase _mimeDb;
MimeDatabase get mimedb => _mimeDb;
late final DesktopEntryManager _desktopEntryManager;
DesktopEntryManager get desktopEntryManager => _desktopEntryManager;

Future<void> initXdgMime() async {
  _mimeDb = await SharedMimeInfo.open();
  _desktopEntryManager = await DesktopEntryManager.create();
}
