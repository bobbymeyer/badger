import { application } from "controllers/application"

// its-swiss pins its two controllers from its engine; a host registers them
// once. The engine's own controllers register themselves from badger.js.
import ItsSwissClipboardController from "its_swiss/clipboard_controller"
import ItsSwissLiveSearchController from "its_swiss/live_search_controller"
application.register("its-swiss-clipboard", ItsSwissClipboardController)
application.register("its-swiss-live-search", ItsSwissLiveSearchController)
