# The engine's JavaScript: its Stimulus controllers and the module that
# registers them with the host's Stimulus application. The layout imports
# that module, so a host has nothing to add to its own importmap.
pin "badger", to: "badger.js"
pin "badger/controllers/document_controller", to: "badger/controllers/document_controller.js"
