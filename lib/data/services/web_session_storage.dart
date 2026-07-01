// This acts as a traffic cop. If the app is compiling for the web, it uses the web version. 
// If it's compiling for Android/iOS, it uses the safe mobile version.
export 'web_session_storage_mobile.dart'
    if (dart.library.html) 'web_session_storage_web.dart';