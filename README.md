# Itemly

## Run in Chrome

Install Flutter and Chrome, then run:

```sh
flutter run -d chrome
```

The web app stores its development database in the browser's IndexedDB, separate
from the Android database. Browser data is scoped to the origin/port, so keep
the same web port between runs to retain your test data.

Android development remains available with `flutter run` and is unaffected by
the web database.
