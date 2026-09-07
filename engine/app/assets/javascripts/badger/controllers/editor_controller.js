import { Controller } from "@hotwired/stimulus"
import { Document } from "badger/editor/document"
import { Canvas } from "badger/editor/canvas"
import { Inspector } from "badger/editor/inspector"

// The editor. It holds the document, and everything on the page is a view
// of it: the tree lists its entries, the stage draws the server's render of
// it, the inspector edits the entry selected, the Document view shows it as
// YAML. A change goes into the document, the document goes to the server,
// the drawing comes back; the construction lines are the controls, and a
// handle belongs to the selection. Every change is in one history, so a
// drag is never a commitment. Nothing is saved until Save.
export default class extends Controller {
  static targets = ["tree", "svg", "grid", "referenceLayer", "pieces", "construction", "handles",
                    "status", "inspector", "referencePanel", "templates", "saveState", "yaml", "yamlError",
                    "undo", "redo", "addInto"]
  static values = {
    document: Object, rendering: Object, schema: Object, starters: Object, fonts: Array,
    renderUrl: String, saveUrl: String, reference: Object, referenceUrl: String,
    yaml: String, select: String
  }

  connect() {
    this.doc = new Document(this.documentValue)
    this.canvas = new Canvas(this.svgTarget, {
      grid: this.gridTarget, reference: this.referenceLayerTarget, pieces: this.piecesTarget,
      construction: this.constructionTarget, handles: this.handlesTarget
    })
    this.inspector = new Inspector(this.inspectorTarget, this.templatesTarget, {
      fonts: this.fontsValue,
      onChange: (key, value) => this.change(key, value),
      onAction: (action, address) => this.act(action, address),
      onHover: (handle, on) => this.canvas.lightHandles(on ? handle.split(" ") : [])
    })
    this.layers = { construction: true, reference: Boolean(this.referenceValue.url), grid: false }
    this.reference = { ...this.referenceValue }
    this.selected = ""
    this.dirty = false
    this.construction = []
    this.warnings = []
    this.past = []
    this.future = []
    this.space = false
    this.yaml = this.yamlValue
    this.apply(this.renderingValue)
    this.canvas.fit()
    this.renderTree()
    this.select(this.selectValue || "")
    this.drawReference()
    this.setHistoryButtons()
    // opened on an entry, as a new badge is on its first run: the first
    // thing to do is type its word
    if (this.selectValue && this.selected === this.selectValue) this.inspectorTarget.querySelector("input[type=text]")?.select()
    this.leaving = (event) => { if (this.dirty) { event.preventDefault(); event.returnValue = "" } }
    window.addEventListener("beforeunload", this.leaving)
    this.resize = () => { if (this.canvas.mode === "fit") this.canvas.fit(); this.status(); this.redrawOverlays() }
    window.addEventListener("resize", this.resize)
    this.keydown = (event) => this.key(event)
    this.keyup = (event) => { if (event.key === " ") { this.space = false; this.svgTarget.classList.remove("stage--space") } }
    document.addEventListener("keydown", this.keydown)
    document.addEventListener("keyup", this.keyup)
  }

  disconnect() {
    window.removeEventListener("beforeunload", this.leaving)
    window.removeEventListener("resize", this.resize)
    document.removeEventListener("keydown", this.keydown)
    document.removeEventListener("keyup", this.keyup)
  }

  // --- the render ----------------------------------------------------------

  apply(rendering) {
    if (!rendering || !rendering.svg) return
    this.rendering = rendering
    if (rendering.yaml !== undefined) this.yaml = rendering.yaml
    this.construction = rendering.construction || []
    this.warnings = rendering.warnings || []
    this.canvas.setPieces(rendering.svg)
    this.drawConstruction()
    this.status()
    this.inspector.showError(null)
    this.svgTarget.classList.remove("stage--rendering")
  }

  scheduleRender(delay = 250) {
    clearTimeout(this.renderTimer)
    this.svgTarget.classList.add("stage--rendering")
    this.renderTimer = setTimeout(() => this.render(), delay)
  }

  async render() {
    clearTimeout(this.renderTimer)
    this.renderTimer = null
    const stamp = (this.renderStamp = (this.renderStamp || 0) + 1)
    const data = await this.ask({ document: this.doc.toJSON() })
    if (stamp !== this.renderStamp || !data) return
    if (data.ok) {
      this.apply(data)
      this.refreshInspector()
    } else {
      this.svgTarget.classList.remove("stage--rendering")
      this.inspector.showError(data.error || "The document does not build.")
    }
  }

  // The server's answer for a document, as JSON or as YAML, with `ok`
  // saying whether it drew; null when the server did not answer.
  async ask(body) {
    let response
    try {
      response = await fetch(this.renderUrlValue, { method: "POST", headers: this.headers(), body: JSON.stringify(body) })
    } catch (e) {
      this.svgTarget.classList.remove("stage--rendering")
      this.inspector.showError("The drawing could not be asked for: the server did not answer.")
      return null
    }
    const data = await response.json()
    data.ok = response.ok
    return data
  }

  headers() {
    const token = document.querySelector("meta[name='csrf-token']")?.content
    return { "Content-Type": "application/json", Accept: "application/json", "X-CSRF-Token": token || "" }
  }

  status() {
    const ink = this.rendering?.ink
    if (!ink) return
    this.statusTarget.textContent = `${Math.round(ink.width)} × ${Math.round(ink.height)} · ${this.canvas.percent()}%`
  }

  // --- the views -----------------------------------------------------------

  // The drawing or the document. Showing the document fills it from the
  // last render, after any render still owed; showing the drawing refits
  // it, since it had no size while it was away.
  async view(event) {
    const view = event.currentTarget.dataset.view
    for (const button of this.element.querySelectorAll(".editor__view")) {
      if (button.dataset.view === view) button.setAttribute("aria-current", "page")
      else button.removeAttribute("aria-current")
    }
    this.element.classList.toggle("editor--document", view === "document")
    if (view === "document") {
      if (this.renderTimer) await this.render()
      if (this.yaml !== undefined) this.yamlTarget.value = this.yaml
      this.yamlTarget.setSelectionRange(0, 0)
      this.yamlTarget.scrollTop = 0
      this.yamlTarget.focus({ preventScroll: true })
    } else {
      this.resize()
    }
  }

  yamlInput() {
    this.touched()
    clearTimeout(this.yamlTimer)
    this.yamlTimer = setTimeout(() => this.renderYaml(), 500)
  }

  // The document as typed, drawn: what builds replaces the document held,
  // and what does not is refused under the text, where it was typed.
  async renderYaml() {
    const stamp = (this.renderStamp = (this.renderStamp || 0) + 1)
    const data = await this.ask({ document_yaml: this.yamlTarget.value })
    if (stamp !== this.renderStamp || !data) return
    if (data.ok) {
      this.record("yaml")
      this.doc = new Document(data.document)
      this.yamlErrorTarget.hidden = true
      this.apply(data)
      this.renderTree()
      this.select(this.doc.entry(this.selected) ? this.selected : "")
    } else {
      this.yamlErrorTarget.textContent = data.error || "The document does not build."
      this.yamlErrorTarget.hidden = false
    }
  }

  // --- history -------------------------------------------------------------

  // The document as it was before a change, kept so the change can be
  // taken back. Changes to one field in quick succession — typing a word,
  // scrubbing a number — are one step, not one a keystroke.
  record(coalesce = null) {
    const last = this.past[this.past.length - 1]
    if (coalesce && last && last.coalesce === coalesce && Date.now() - last.at < 1200) {
      last.at = Date.now()
      return
    }
    this.past.push({ spec: structuredClone(this.doc.spec), selected: this.selected, coalesce, at: Date.now() })
    if (this.past.length > 100) this.past.shift()
    this.future = []
    this.setHistoryButtons()
  }

  undo() {
    const step = this.past.pop()
    if (!step) return
    this.future.push({ spec: structuredClone(this.doc.spec), selected: this.selected, coalesce: null, at: 0 })
    this.restore(step)
  }

  redo() {
    const step = this.future.pop()
    if (!step) return
    this.past.push({ spec: structuredClone(this.doc.spec), selected: this.selected, coalesce: null, at: 0 })
    this.restore(step)
  }

  restore(step) {
    this.doc = new Document(step.spec)
    this.touched()
    this.renderTree()
    this.select(this.doc.entry(step.selected) ? step.selected : "")
    this.setHistoryButtons()
    this.scheduleRender(0)
  }

  setHistoryButtons() {
    if (this.hasUndoTarget) this.undoTarget.disabled = this.past.length === 0
    if (this.hasRedoTarget) this.redoTarget.disabled = this.future.length === 0
  }

  // --- keys ------------------------------------------------------------------

  // The keys a hand expects of a drawing tool, wherever on the page it is,
  // as long as it is not in a field: undo and redo, Delete, Save, Space
  // to pan, and the zoom buttons' numbers. In a field, only Save.
  key(event) {
    const meta = event.metaKey || event.ctrlKey
    const inField = event.target.closest("input, textarea, select, [contenteditable]")
    if (meta && event.key.toLowerCase() === "s") { event.preventDefault(); this.save(event); return }
    if (inField) return
    if (meta && event.key.toLowerCase() === "z") { event.preventDefault(); if (event.shiftKey) this.redo(); else this.undo(); return }
    if (meta && event.key.toLowerCase() === "y") { event.preventDefault(); this.redo(); return }
    if (event.key === "Escape") { this.select(""); return }
    if (event.key === "Delete" || event.key === "Backspace") {
      if (this.selected && this.selected !== "reference") { event.preventDefault(); this.act("remove", this.selected) }
      return
    }
    if (event.key === " " && !event.repeat) { this.space = true; this.svgTarget.classList.add("stage--space"); event.preventDefault(); return }
    if (!meta && ["0", "1", "2"].includes(event.key)) {
      if (event.key === "0") this.canvas.fit()
      else this.canvas.zoomTo(Number(event.key))
      this.status()
      this.setZoomButtons()
      this.redrawOverlays()
    }
  }

  // --- the document --------------------------------------------------------

  change(key, value) {
    if (this.selected === "reference") return
    this.record(`${this.selected}:${key}`)
    if (key === "kind" || key === "mode") {
      // a region or a line of type of another kind: start again from the
      // starter for it, keeping what carries over
      const old = this.doc.entry(this.selected)
      const fresh = structuredClone(this.startersValue[value] || {})
      for (const carried of ["name", "text", "font", "slot", "region"]) if (old[carried] !== undefined) fresh[carried] = old[carried]
      const slot = this.doc.slot(this.selected)
      slot.list[slot.index] = fresh
    } else {
      // the panel is built again only when its fields change: a locator or
      // a sweep of another kind, a shape or a fit of another kind. A number
      // scrubbed into one of them is not that.
      const was = this.doc.get(this.selected, key)
      const rebuilt = ["kind", "mode", "shape.kind", "fit", "reversed"].includes(key) ||
        ((key === "at" || key === "sweep") && (typeof value !== "number") && (typeof was !== typeof value || (typeof value === "string") || (value && was && Object.keys(value)[0] !== Object.keys(was)[0])))
      this.doc.set(this.selected, key, value)
      this.touched()
      this.renderTree()
      if (rebuilt) this.showInspector()
      this.scheduleRender()
      return
    }
    this.touched()
    this.renderTree()
    this.showInspector()
    this.scheduleRender()
  }

  touched() {
    this.dirty = true
    this.saveStateTarget.textContent = "Unsaved changes"
  }

  act(action, address) {
    if (action === "remove") {
      const { label } = this.doc.describe({ address, kind: this.doc.kindOf(address), entry: this.doc.entry(address) })
      this.record()
      this.doc.remove(address)
      this.touched()
      this.renderTree()
      this.select(Document.containerOf(address) === address ? Document.parentOf(address) : Document.containerOf(address))
      this.scheduleRender(0)
      this.say(`Removed ${label}.`, "Undo", () => this.undo())
    } else if (action === "duplicate") {
      this.record()
      const copy = this.doc.duplicate(address)
      this.touched()
      this.renderTree()
      this.select(copy)
      this.scheduleRender(0)
    }
  }

  // A line under the tree that says what just happened, with the one thing
  // to do about it.
  say(text, action, onAction) {
    this.saveStateTarget.replaceChildren(text, " ")
    if (action) {
      const button = document.createElement("button")
      button.type = "button"
      button.className = "tree__undo"
      button.textContent = action
      button.addEventListener("click", onAction)
      this.saveStateTarget.append(button)
    }
  }

  // Add an entry of a kind to the selected container, as the adders say:
  // a band, a rule, an interior; a run following a band, a line fitted to a
  // chord, a line at a fixed size; a child; an artwork. A run following a
  // band where there is none brings a band with it.
  add(event) {
    const kind = event.currentTarget.dataset.kind
    event.currentTarget.closest("details")?.removeAttribute("open")
    const container = this.selected === "reference" ? "" : Document.containerOf(this.selected)
    const list = { rule: "regions", band: "regions", interior: "regions", follow: "type", fit: "type", fixed: "type", child: "children", illustration: "illustrations" }[kind]
    this.record()
    const starter = structuredClone(this.startersValue[kind])
    if (kind === "follow") {
      if (!this.doc.regionNames(container, "band").length) this.doc.add(container, "regions", structuredClone(this.startersValue.band))
      starter.region = this.doc.regionNames(container, "band")[0]
    }
    if (kind === "fit") {
      if (!this.doc.regionNames(container, "interior").length) this.doc.add(container, "regions", structuredClone(this.startersValue.interior))
      starter.region = this.doc.regionNames(container, "interior")[0]
    }
    const address = this.doc.add(container, list, starter)
    this.touched()
    this.renderTree()
    this.select(address)
    this.scheduleRender(0)
    this.inspectorTarget.querySelector("input[type=text]")?.select()
  }

  async save(event) {
    event?.preventDefault()
    this.saveStateTarget.textContent = "Saving…"
    let response
    try {
      response = await fetch(this.saveUrlValue, {
        method: "PATCH", headers: this.headers(), body: JSON.stringify({ badge: { spec: this.doc.toJSON() } })
      })
    } catch (e) {
      this.saveStateTarget.textContent = "Not saved: the server did not answer."
      return
    }
    const data = await response.json()
    if (response.ok) {
      this.dirty = false
      this.saveStateTarget.textContent = "Saved just now"
    } else {
      this.saveStateTarget.textContent = `Not saved: ${data.error}`
    }
  }

  // --- the tree ------------------------------------------------------------

  renderTree() {
    const rows = []
    for (const item of this.doc.entries()) {
      const { label, meta } = this.doc.describe(item)
      const isContainer = item.kind === "container" || item.kind === "child"
      const hasEye = isContainer || ["rule", "band", "interior"].includes(item.kind)
      const visible = this.doc.isVisible(item.address)
      const warned = this.warnings.some((w) => w.address === item.address)
      const li = document.createElement("li")
      li.className = `tree__row${visible ? "" : " tree__row--hidden"}${warned ? " tree__row--warned" : ""}`
      li.dataset.address = item.address
      li.setAttribute("aria-selected", String(item.address === this.selected))
      li.style.paddingInlineStart = `calc(var(--space-1) + ${item.depth} * var(--space-3))`
      li.addEventListener("click", (event) => { if (!event.target.closest(".tree__eye")) this.select(item.address) })
      const chevron = document.createElement("span")
      chevron.className = "tree__chevron"
      chevron.textContent = isContainer ? "›" : ""
      const name = document.createElement("span")
      name.className = "tree__label"
      name.textContent = label
      const note = document.createElement("span")
      note.className = "tree__meta"
      note.textContent = meta
      if (warned) note.title = this.warnings.filter((w) => w.address === item.address).map((w) => w.message).join(" ")
      li.append(chevron, name, note)
      if (hasEye) {
        const eye = document.createElement("button")
        eye.type = "button"
        eye.className = "tree__eye"
        eye.setAttribute("aria-pressed", String(visible))
        eye.setAttribute("aria-label", visible ? "Drawn; click to hide" : "Hidden; click to draw")
        eye.title = visible ? "Drawn. Click to hide it; it still derives and anchors." : "Hidden. Click to draw it."
        eye.textContent = "◉"
        eye.addEventListener("click", () => {
          this.record()
          this.doc.setVisible(item.address, !visible)
          this.touched()
          this.renderTree()
          if (this.selected === item.address) this.showInspector()
          this.scheduleRender(0)
        })
        li.append(eye)
      }
      rows.push(li)
    }
    const ref = document.createElement("li")
    ref.className = "tree__row"
    ref.dataset.address = "reference"
    ref.setAttribute("aria-selected", String(this.selected === "reference"))
    ref.addEventListener("click", () => this.select("reference"))
    const chevron = document.createElement("span")
    chevron.className = "tree__chevron"
    const name = document.createElement("span")
    name.className = "tree__label"
    name.textContent = "Reference"
    const note = document.createElement("span")
    note.className = "tree__meta"
    note.textContent = this.reference.url ? `${this.reference.width} × ${this.reference.height} px` : "none"
    ref.append(chevron, name, note)
    rows.push(ref)
    this.treeTarget.replaceChildren(...rows)
  }

  // --- selection -----------------------------------------------------------

  select(address) {
    if (address !== "reference" && address !== "" && !this.doc.entry(address)) address = ""
    this.selected = address
    for (const row of this.treeTarget.children) row.setAttribute("aria-selected", String(row.dataset.address === address))
    this.piecesTarget.querySelectorAll(".is-selected").forEach((el) => el.classList.remove("is-selected"))
    this.piecesTarget.querySelectorAll(`[data-address="${CSS.escape(address)}"]`).forEach((el) => el.classList.add("is-selected"))
    if (this.hasAddIntoTarget) {
      const container = address === "reference" ? "" : Document.containerOf(address)
      this.addIntoTarget.textContent = `Add to ${this.doc.containerLabel(container)}`
    }
    this.drawConstruction()
    this.drawReference()
    this.showInspector()
  }

  // The panel after a render: shown again for what the render found, unless
  // a hand is in it or on a handle, in which case it waits for the hand to
  // leave. A field being typed in is never rebuilt under the typing.
  refreshInspector() {
    if (this.drag || this.inspectorTarget.contains(document.activeElement)) {
      this.inspectorStale = true
      return
    }
    this.inspectorStale = false
    this.showInspector()
  }

  inspectorLeft(event) {
    if (event.relatedTarget && this.inspectorTarget.contains(event.relatedTarget)) return
    if (this.inspectorStale) setTimeout(() => { if (!this.inspectorTarget.contains(document.activeElement)) this.refreshInspector() }, 0)
  }

  showInspector() {
    if (this.selected === "reference") {
      this.inspectorTarget.hidden = true
      this.referencePanelTarget.hidden = false
      return
    }
    this.referencePanelTarget.hidden = true
    this.inspectorTarget.hidden = false
    const kind = this.doc.kindOf(this.selected)
    if (!kind) return this.inspector.empty()
    const container = Document.containerOf(this.selected)
    const regions = { band: this.doc.regionNames(container, "band"), interior: this.doc.regionNames(container, "interior") }
    this.inspector.show({
      address: this.selected, kind, entry: this.doc.entry(this.selected),
      fields: this.schemaValue[kind] || [], doc: this.doc, regions,
      warnings: this.warnings.filter((w) => w.address === this.selected)
    })
  }

  // --- the stage -----------------------------------------------------------

  drawConstruction() {
    this.constructionTarget.hidden = !this.layers.construction
    this.canvas.setConstruction(this.construction, this.selected, this.warnings)
    this.canvas.setHandles(this.layers.construction ? this.handlesFor(this.selected) : [])
  }

  drawReference() {
    this.referenceLayerTarget.hidden = !this.layers.reference
    const placing = this.selected === "reference" && Boolean(this.reference.url)
    // While the photograph is being placed it sits on top of the pointer:
    // the drawing above it lets the pointer through so a drag lands on it.
    this.svgTarget.classList.toggle("stage--placing", placing)
    this.canvas.setReference(this.reference, this.selected === "reference")
    if (this.selected === "reference" && this.reference.url) this.canvas.setHandles(this.canvas.referenceHandles(this.reference))
  }

  entryOf(address) {
    return this.construction.find((c) => c.address === address)
  }

  centroidOf(address) {
    return this.entryOf(Document.containerOf(address))?.centroid || { x: 0, y: 0 }
  }

  // The handles the selection gets: the sweep's ends for a run, an edge for
  // a region, the size of a shape, the chord of a fit, the point of a placed
  // child. Each says what it drags.
  handlesFor(address) {
    const c = this.entryOf(address)
    if (!c) return []
    const kind = this.doc.kindOf(address)
    const center = this.centroidOf(address)
    const at = (d) => Canvas.pointAtAngle(d, center, 0)
    switch (kind) {
      case "follow": {
        const fmt = (deg) => `${Math.round(deg)}°`
        return [
          { id: "sweep:from", x: c.sweep.from.x, y: c.sweep.from.y, label: `from ${fmt(c.sweep.from.degrees)}`, title: "The sweep's start. Drag to turn it; Alt keeps the sweep symmetrical." },
          { id: "sweep:to", x: c.sweep.to.x, y: c.sweep.to.y, label: `to ${fmt(c.sweep.to.degrees)}`, title: "The sweep's end. Drag to turn it; Alt keeps the sweep symmetrical." }
        ]
      }
      case "band": {
        const outer = at(c.outer_d)
        const inner = at(c.inner_d)
        return [{ id: "band:outer", ...outer, label: `outer ${c.outer}`, title: "The outer edge: its distance from the container" },
                { id: "band:inner", ...inner, label: `width ${c.width}`, title: "The inner edge: the band's width" }]
      }
      case "rule": return [{ id: "rule:distance", ...at(c.d), label: `rule ${c.distance}`, title: "The rule's distance from the container's edge" }]
      case "interior": return [{ id: "interior:inside", ...at(c.d), label: `inset ${c.inside}`, title: "The interior's inset" }]
      case "container":
      case "child": {
        const box = Canvas.bbox(c.d)
        const shape = this.doc.get(address, "shape.kind")
        const handles = [{ id: "shape:x", x: box.x + box.width, y: c.centroid.y, shape: "square", label: `${Math.round(box.width)} wide`, title: "The shape's width" }]
        if (shape !== "circle") handles.push({ id: "shape:y", x: c.centroid.x, y: box.y, shape: "square", label: `${Math.round(box.height)} tall`, title: "The shape's height" })
        if (c.anchor) handles.push({ id: "anchor", ...c.anchor, title: "Where the child is placed in its parent" })
        return handles
      }
      case "fit": {
        if (!c.chord) return c.anchor ? [{ id: "anchor", ...c.anchor, title: "Where the line is placed" }] : []
        const box = Canvas.bbox(c.chord)
        return [{ id: "chord:at", x: box.x + box.width / 2, y: box.y + box.height / 2, label: `at ${this.doc.get(address, "at")}`, title: "The chord the line is fitted to" }]
      }
      case "fixed":
      case "illustration":
        return c.anchor ? [{ id: "anchor", ...c.anchor, title: "Where it is placed" }] : []
      default: return []
    }
  }

  // What a press on a piece of the drawing drags, by what the piece is: a
  // run turns round its band, a band moves with its width, a rule or an
  // interior moves in or out, a fitted line slides its chord, anything
  // placed moves its point. The root moves nothing: it is the drawing.
  dragFor(address) {
    const kind = this.doc.kindOf(address)
    const entry = this.doc.entry(address)
    switch (kind) {
      case "follow": return "run:turn"
      case "band": return "band:move"
      case "rule": return "rule:distance"
      case "interior": return "interior:inside"
      case "fit": return entry.fit === "box" ? "anchor" : "chord:at"
      case "fixed": case "illustration": case "child": return "anchor"
      default: return null
    }
  }

  stagePointerDown(event) {
    const p = this.canvas.point(event)
    if (this.space || event.button === 1) {
      this.pan = { last: p, moved: false }
      this.svgTarget.classList.add("stage--panning")
      this.svgTarget.setPointerCapture(event.pointerId)
      event.preventDefault()
      return
    }
    const handle = event.target.closest("[data-handle]")
    if (handle) {
      this.beginDrag(handle.dataset.handle, p, handle)
      this.svgTarget.setPointerCapture(event.pointerId)
      event.preventDefault()
      return
    }
    if (event.target.closest("[data-reference]") && this.selected === "reference") {
      this.drag = { handle: "reference:move", start: p, reference: { ...this.reference } }
      this.svgTarget.setPointerCapture(event.pointerId)
      event.preventDefault()
      return
    }
    const piece = event.target.closest("[data-address]")
    if (piece) {
      // a press on a piece: a click selects it, and a drag moves it
      const address = piece.dataset.address
      if (address !== this.selected) this.select(address)
      const drag = this.dragFor(address)
      if (drag) this.press = { drag, start: p, screen: { x: event.clientX, y: event.clientY } }
      this.svgTarget.setPointerCapture(event.pointerId)
      return
    }
    this.pan = { last: p, moved: false }
    this.svgTarget.classList.add("stage--panning")
    this.svgTarget.setPointerCapture(event.pointerId)
  }

  // A drag begins: the document as it stands goes into the history, and the
  // numbers the drag will change are read once.
  beginDrag(handle, start, element = null) {
    this.record()
    const address = this.selected
    const c = this.entryOf(address)
    this.drag = {
      handle, start, snapshot: structuredClone(this.doc.entry(address) || {}), reference: { ...this.reference },
      center: this.centroidOf(address === "reference" ? "" : address), element,
      origin: element ? this.handlePoint(element) : c?.anchor || start
    }
    if (c && (handle.startsWith("sweep") || handle === "run:turn") && typeof this.doc.get(address, "sweep") !== "object") {
      // a preset sweep becomes the two angles it is, before either moves
      this.doc.set(address, "sweep", { from: Math.round(c.sweep.from.degrees), to: Math.round(c.sweep.to.degrees) })
      this.drag.snapshot = structuredClone(this.doc.entry(address))
    }
    if (handle === "anchor") {
      // a thing placed at the centroid or along the path moves as fractions
      // of its parent from where it is now
      const at = this.doc.get(address, "at")
      if (!at || at === "centroid" || at.on_path) {
        const box = Canvas.bbox(this.entryOf(Document.containerOf(address)).d)
        const anchor = c?.anchor || this.drag.center
        this.doc.set(address, "at", { axial: [Number(((anchor.x - box.x) / box.width).toFixed(3)), Number(((anchor.y - box.y) / box.height).toFixed(3))] })
        this.drag.snapshot = structuredClone(this.doc.entry(address))
      }
    }
    if (element) element.classList.add("is-dragging")
    this.inspector.light(handle)
    this.svgTarget.classList.add("stage--dragging")
  }

  handlePoint(element) {
    if (element.tagName === "rect") {
      const u = this.canvas.unitsPerPixel()
      return { x: Number(element.getAttribute("x")) + 4 * u, y: Number(element.getAttribute("y")) + 4 * u }
    }
    return { x: Number(element.getAttribute("cx")), y: Number(element.getAttribute("cy")) }
  }

  stagePointerMove(event) {
    const p = this.canvas.point(event)
    if (this.press && !this.drag) {
      if (Math.hypot(event.clientX - this.press.screen.x, event.clientY - this.press.screen.y) < 4) return
      const { drag, start } = this.press
      this.press = null
      this.beginDrag(drag, start)
      this.svgTarget.classList.add("stage--panning")
    }
    if (this.drag) {
      this.dragTo(p, event)
      event.preventDefault()
    } else if (this.pan) {
      this.canvas.panBy(p.x - this.pan.last.x, p.y - this.pan.last.y)
      this.pan.moved = true
      this.status()
      this.setZoomButtons()
    }
  }

  stagePointerUp(event) {
    this.press = null
    if (this.drag) {
      const wasReference = this.drag.handle.startsWith("reference")
      this.drag = null
      this.handlesTarget.querySelectorAll(".is-dragging").forEach((el) => el.classList.remove("is-dragging"))
      this.svgTarget.classList.remove("stage--dragging")
      this.inspector.light(null)
      if (wasReference) this.saveReference()
      else { this.showInspector(); this.scheduleRender(0) }
    }
    if (this.pan) {
      this.svgTarget.classList.remove("stage--panning")
      this.pan = null
    }
    this.redrawOverlays()
    try { this.svgTarget.releasePointerCapture(event.pointerId) } catch (e) { /* not captured */ }
  }

  stageClick(event) {
    if (this.pan?.moved) return
    if (event.target.closest("[data-reference]") && !event.target.closest("[data-address]")) this.select("reference")
    this.svgTarget.focus({ preventScroll: true })
  }

  // The wheel pans; with Ctrl or ⌘, and so on a trackpad's pinch, it zooms
  // about the pointer.
  stageWheel(event) {
    event.preventDefault()
    if (event.ctrlKey || event.metaKey) {
      this.canvas.zoomBy(Math.exp(event.deltaY * 0.01), this.canvas.point(event))
    } else {
      const u = this.canvas.unitsPerPixel()
      this.canvas.panBy(-event.deltaX * u, -event.deltaY * u)
    }
    this.status()
    this.setZoomButtons()
    clearTimeout(this.wheelTimer)
    this.wheelTimer = setTimeout(() => this.redrawOverlays(), 80)
  }

  // The overlays are drawn in badge units at a screen size, so a change of
  // scale redraws them.
  redrawOverlays() {
    this.drawConstruction()
    this.drawReference()
  }

  stageKey(event) {
    if (event.key === "Escape") this.select("")
  }

  // Where a handle went, as the number it stands for. Distances snap to the
  // unit and angles to five degrees, unless Shift is held; Alt on a sweep's
  // end keeps the sweep symmetrical about the vertical.
  dragTo(p, event) {
    const { handle, start, snapshot, center, origin } = this.drag
    const free = event.shiftKey
    const unit = (v) => (free ? Number(v.toFixed(1)) : Math.round(v))
    const angle = (v) => { const a = ((v % 360) + 360) % 360; return free ? Math.round(a) : Math.round(a / 5) * 5 % 360 }
    const mirror = (deg) => ((540 - deg) % 360 + 360) % 360
    const radial = center ? Canvas.distance(center, p) - Canvas.distance(center, start) : 0
    const set = (key, value) => { this.doc.set(this.selected, key, value); this.touched() }
    const c = this.entryOf(this.selected)
    const alongRay = (distance) => {
      const len = Canvas.distance(center, origin) || 1
      return { x: center.x + ((origin.x - center.x) / len) * (len + distance), y: center.y + ((origin.y - center.y) / len) * (len + distance) }
    }
    switch (handle) {
      case "sweep:from": case "sweep:to": {
        const deg = angle(Canvas.degrees(center, p))
        set(handle === "sweep:from" ? "sweep.from" : "sweep.to", deg)
        if (event.altKey) set(handle === "sweep:from" ? "sweep.to" : "sweep.from", mirror(deg))
        if (c) {
          this.canvas.moveHandle(handle, Canvas.pointAtAngle(c.d, center, deg), `${handle === "sweep:from" ? "from" : "to"} ${deg}°`)
          if (event.altKey) this.canvas.moveHandle(handle === "sweep:from" ? "sweep:to" : "sweep:from", Canvas.pointAtAngle(c.d, center, mirror(deg)), `${handle === "sweep:from" ? "to" : "from"} ${mirror(deg)}°`)
        }
        break
      }
      case "run:turn": {
        const delta = Canvas.degrees(center, p) - Canvas.degrees(center, start)
        set("sweep.from", angle(snapshot.sweep.from + delta))
        set("sweep.to", angle(snapshot.sweep.to + delta))
        if (c) {
          this.canvas.moveHandle("sweep:from", Canvas.pointAtAngle(c.d, center, angle(snapshot.sweep.from + delta)), `from ${angle(snapshot.sweep.from + delta)}°`)
          this.canvas.moveHandle("sweep:to", Canvas.pointAtAngle(c.d, center, angle(snapshot.sweep.to + delta)), `to ${angle(snapshot.sweep.to + delta)}°`)
        }
        break
      }
      case "band:outer": set("outer", unit(snapshot.outer + radial)); this.canvas.moveHandle(handle, alongRay(radial), `outer ${unit(snapshot.outer + radial)}`); break
      case "band:inner": set("width", unit(Math.max(1, (snapshot.width ?? 40) - radial))); this.canvas.moveHandle(handle, alongRay(radial), `width ${unit(Math.max(1, (snapshot.width ?? 40) - radial))}`); break
      case "band:move": {
        set("outer", unit(snapshot.outer + radial))
        this.canvas.moveHandle("band:outer", alongRay(radial), `outer ${unit(snapshot.outer + radial)}`)
        break
      }
      case "rule:distance": set("distance", unit(snapshot.distance + radial)); this.canvas.moveHandle(handle, alongRay(radial), `rule ${unit(snapshot.distance + radial)}`); break
      case "interior:inside": set("inside", unit(Math.min(0, (snapshot.inside ?? 0) + radial))); this.canvas.moveHandle(handle, alongRay(radial), `inset ${unit(Math.min(0, (snapshot.inside ?? 0) + radial))}`); break
      case "shape:x": {
        const dx = p.x - start.x
        const shape = snapshot.shape || {}
        if (shape.kind === "circle") set("shape.radius", unit(Math.max(1, shape.radius + dx)))
        else if (shape.kind === "ellipse") set("shape.rx", unit(Math.max(1, shape.rx + dx)))
        else set("shape.width", unit(Math.max(1, shape.width + 2 * dx)))
        this.canvas.moveHandle(handle, { x: origin.x + dx, y: origin.y })
        break
      }
      case "shape:y": {
        const dy = start.y - p.y
        const shape = snapshot.shape || {}
        if (shape.kind === "ellipse") set("shape.ry", unit(Math.max(1, shape.ry + dy)))
        else set("shape.height", unit(Math.max(1, shape.height + 2 * dy)))
        this.canvas.moveHandle(handle, { x: origin.x, y: origin.y - dy })
        break
      }
      case "chord:at": {
        const acrossX = (snapshot.fit || "chord_at_y") !== "chord_at_y"
        const along = acrossX ? p.x - start.x : p.y - start.y
        set("at", unit(snapshot.at + along))
        this.canvas.moveHandle(handle, acrossX ? { x: origin.x + along, y: origin.y } : { x: origin.x, y: origin.y + along }, `at ${unit(snapshot.at + along)}`)
        break
      }
      case "anchor": {
        const at = snapshot.at
        const target = this.drag.element ? p : { x: origin.x + (p.x - start.x), y: origin.y + (p.y - start.y) }
        if (at && at.polar) {
          set("at.polar.angle", angle(Canvas.degrees(center, target)))
          set("at.polar.radius", unit(Canvas.distance(center, target)))
        } else if (at && at.axial) {
          const box = Canvas.bbox(this.entryOf(Document.containerOf(this.selected)).d)
          const fx = (target.x - box.x) / box.width
          const fy = (target.y - box.y) / box.height
          set("at.axial[0]", free ? Number(fx.toFixed(3)) : Number(fx.toFixed(2)))
          set("at.axial[1]", free ? Number(fy.toFixed(3)) : Number(fy.toFixed(2)))
        }
        this.canvas.moveHandle("anchor", target)
        break
      }
      case "reference:move":
        this.reference.x = unit(this.drag.reference.x + (p.x - start.x))
        this.reference.y = unit(this.drag.reference.y + (p.y - start.y))
        this.drawReference()
        this.fillReferenceFields()
        return
      case "reference:scale": {
        const r = this.drag.reference
        const from = Canvas.distance({ x: r.x, y: r.y }, start)
        const to = Canvas.distance({ x: r.x, y: r.y }, p)
        this.reference.scale = Number(Math.max(0.01, r.scale * (to / Math.max(1e-6, from))).toFixed(3))
        this.drawReference()
        this.fillReferenceFields()
        return
      }
    }
    this.renderTree()
    this.scheduleRender(120)
  }

  // --- layers and zoom -----------------------------------------------------

  toggleLayer(event) {
    const button = event.currentTarget
    const layer = button.dataset.layer
    this.layers[layer] = !this.layers[layer]
    button.setAttribute("aria-pressed", String(this.layers[layer]))
    if (layer === "grid") this.canvas.setGrid(this.layers.grid)
    if (layer === "construction") this.drawConstruction()
    if (layer === "reference") this.drawReference()
  }

  zoom(event) {
    const which = event.currentTarget.dataset.zoom
    if (which === "fit") this.canvas.fit()
    else this.canvas.zoomTo(Number(which))
    this.status()
    this.setZoomButtons()
    this.redrawOverlays()
  }

  setZoomButtons() {
    this.element.querySelectorAll("[data-zoom]").forEach((b) => b.setAttribute("aria-pressed", String(b.dataset.zoom === this.canvas.mode)))
  }

  // --- the reference -------------------------------------------------------

  placeReference(event) {
    const input = event.currentTarget
    const value = Number(input.value)
    if (Number.isNaN(value)) return
    this.reference[input.name] = value
    this.drawReference()
    clearTimeout(this.referenceTimer)
    this.referenceTimer = setTimeout(() => this.saveReference(), 400)
  }

  fillReferenceFields() {
    for (const key of ["x", "y", "scale", "opacity"]) {
      const input = this.referencePanelTarget.querySelector(`[name="${key}"]`)
      if (input) input.value = this.reference[key]
    }
  }

  async saveReference() {
    if (!this.reference.url) return
    const { x, y, scale, opacity } = this.reference
    await fetch(this.referenceUrlValue, {
      method: "PATCH", headers: this.headers(), body: JSON.stringify({ reference: { x, y, scale, opacity } })
    }).catch(() => {})
  }
}
