// Default Flutter entry point.
//
// The real bootstrap (guarded error zone, ProviderContainer, session restore)
// lives in `bootstrap/main.dart`. This thin shim keeps the conventional
// `flutter run` / `flutter build` target (`lib/main.dart`) working without
// duplicating that logic.
import 'bootstrap/main.dart' as bootstrap;

void main() => bootstrap.main();
