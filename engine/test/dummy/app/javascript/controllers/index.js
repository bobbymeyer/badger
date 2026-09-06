import { application } from "controllers/application"

// its-swiss pins its clipboard controller from its engine; a host registers
// it once. The engine's own controllers register themselves from pandatone.js.
import ItsSwissClipboardController from "its_swiss/clipboard_controller"
application.register("its-swiss-clipboard", ItsSwissClipboardController)
