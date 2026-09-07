# The engine's JavaScript: its Stimulus controllers and the module that
# registers them with the host's Stimulus application. The layout imports
# that module, so a host has nothing to add to its own importmap.
pin "badger", to: "badger.js"
pin "badger/controllers/document_controller", to: "badger/controllers/document_controller.js"
pin "badger/controllers/editor_controller", to: "badger/controllers/editor_controller.js"
pin "badger/controllers/start_controller", to: "badger/controllers/start_controller.js"
pin "badger/editor/document", to: "badger/editor/document.js"
pin "badger/editor/canvas", to: "badger/editor/canvas.js"
pin "badger/editor/inspector", to: "badger/editor/inspector.js"
