// Registers the engine's controllers with the host's Stimulus application.
// controllers/application is what stimulus-rails installs in every host; it
// is the one thing the engine assumes about the JavaScript around it. The
// live search on the index is its-swiss's, and the host registers that one.
import { application } from "controllers/application"
import DocumentController from "badger/controllers/document_controller"
import EditorController from "badger/controllers/editor_controller"
import StartController from "badger/controllers/start_controller"

application.register("badger-document", DocumentController)
application.register("badger-editor", EditorController)
application.register("badger-start", StartController)
