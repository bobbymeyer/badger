import { Controller } from "@hotwired/stimulus"
import { Document } from "badger/editor/document"
import { Canvas } from "badger/editor/canvas"
import { Inspector } from "badger/editor/inspector"

// The editor. It holds the document, and everything on the page is a view
// of it: the tree lists its entries, the stage draws the server's render of
// it, the inspector edits the entry selected. A change goes into the
// document, the document goes to the server, the drawing comes back; the
// construction lines are the controls, and a handle belongs to the
// selection. Nothing is saved until Save.
export default class extends Controller {
  static targets = ["tree", "svg", "grid", "referenceLayer", "pieces", "construction", "handles",
                    "status", "inspector", "referencePanel", "templates", "saveState", "yaml", "yamlError"]
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
      onAction: (action, address) => this.act(action, address)
    })
    this.layers = { construction: true, reference: Boolean(this.referenceValue.url), grid: false }
    this.reference = { ...this.referenceValue }
    this.selected = ""
    this.dirty = false
    this.construction = []
    this.warnings = []
    this.yaml = this.yamlValue
    this.apply(this.renderingValue)
    this.canvas.fit()
    this.renderTree()
    this.select(this.selectValue || "")
    this.drawReference()
    // opened on an entry, as a new badge is on its first run: the first
    // thing to do is type its word
    if (this.selectValue && this.selected === this.selectValue) this.inspectorTarget.querySelector("input[type=text]")?.select()
    this.leaving = (event) => { if (this.dirty) { event.preventDefault(); event.returnValue = "" } }
    window.addEventListener("beforeunload", this.leaving)
    this.resize = () => { if (this.canvas.mode === "fit") this.canvas.fit(); this.status(); this.redrawOverlays() }
    window.addEventListener("resize", this.resize)
  }

  disconnect() {
    window.removeEventListener("beforeunload", this.leaving)
    window.removeEventListener("resize", this.resize)
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
  }

  scheduleRender(delay = 250) {
    clearTimeout(this.renderTimer)
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
      this.showInspector()
    } else {
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
      this.inspector.showError("The drawing could not be asked for: the server did not answer.")
      return null
    }
    const data = await response.json()
    data.ok = response.ok
    return data
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

  headers() {
    const token = document.querySelector("meta[name='csrf-token']")?.content
    return { "Content-Type": "application/json", Accept: "application/json", "X-CSRF-Token": token || "" }
  }

  status() {
    const ink = this.rendering?.ink
    if (!ink) return
    this.statusTarget.textContent = `${Math.round(ink.width)} × ${Math.round(ink.height)} · ${this.canvas.percent()}%`
  }

  // --- the document --------------------------------------------------------

  change(key, value) {
    if (this.selected === "reference") return
    if (key === "kind" || key === "mode") {
      // a region or a line of type of another kind: start again from the
      // starter for it, keeping what carries over
      const old = this.doc.entry(this.selected)
      const fresh = structuredClone(this.startersValue[value] || {})
      for (const carried of ["name", "text", "font", "slot", "region"]) if (old[carried] !== undefined) fresh[carried] = old[carried]
      const slot = this.doc.slot(this.selected)
      slot.list[slot.index] = fresh
    } else {
      this.doc.set(this.selected, key, value)
    }
    this.touched()
    this.renderTree()
    if (key === "kind" || key === "mode" || key === "shape.kind" || key === "fit" || key === "at" || key === "sweep") this.showInspector()
    this.scheduleRender()
  }

  touched() {
    this.dirty = true
    this.saveStateTarget.textContent = "Unsaved changes"
  }

  act(action, address) {
    if (action === "remove") {
      this.doc.remove(address)
      this.touched()
      this.renderTree()
      this.select(Document.containerOf(address) === address ? "" : Document.containerOf(address))
      this.scheduleRender(0)
    } else if (action === "duplicate") {
      const copy = this.doc.duplicate(address)
      this.touched()
      this.renderTree()
      this.select(copy)
      this.scheduleRender(0)
    }
  }

  add(event) {
    const what = event.currentTarget.dataset.kind
    const container = this.selected === "reference" ? "" : Document.containerOf(this.selected)
    let kind = what
    let list = { region: "regions", type: "type", child: "children", illustration: "illustrations" }[what]
    if (what === "region") kind = "band"
    if (what === "type") kind = this.doc.regionNames(container, "band").length ? "follow" : "fixed"
    const starter = structuredClone(this.startersValue[kind])
    if (kind === "follow") starter.region = this.doc.regionNames(container, "band")[0]
    if (kind === "fit") starter.region = this.doc.regionNames(container, "interior")[0]
    const address = this.doc.add(container, list, starter)
    this.touched()
    this.renderTree()
    this.select(address)
    this.scheduleRender(0)
  }

  async save(event) {
    event.preventDefault()
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
      const li = document.createElement("li")
      li.className = `tree__row${visible ? "" : " tree__row--hidden"}`
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
      li.append(chevron, name, note)
      if (hasEye) {
        const eye = document.createElement("button")
        eye.type = "button"
        eye.className = "tree__eye"
        eye.setAttribute("aria-pressed", String(visible))
        eye.setAttribute("aria-label", visible ? "Drawn; click to hide" : "Hidden; click to draw")
        eye.textContent = "◉"
        eye.addEventListener("click", () => {
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
    this.drawConstruction()
    this.drawReference()
    this.showInspector()
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
      fields: this.fieldsFor(kind), doc: this.doc, regions,
      warnings: this.warnings.filter((w) => w.address === this.selected)
    })
  }

  // The schema's fields for a kind, with a way to change the kind itself.
  fieldsFor(kind) {
    const fields = [...(this.schemaValue[kind] || [])]
    if (["rule", "band", "interior"].includes(kind)) {
      fields.unshift({ key: "kind", label: "Kind", type: "select", options: [["rule", "rule"], ["band", "band"], ["interior", "interior"]] })
    }
    if (["follow", "fit", "fixed"].includes(kind)) {
      fields.unshift({ key: "mode", label: "Mode", type: "select", options: [["follow", "follows a band"], ["fit", "fitted"], ["fixed", "fixed"]] })
    }
    return fields
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
          { id: "sweep:from", x: c.sweep.from.x, y: c.sweep.from.y, label: `from ${fmt(c.sweep.from.degrees)}` },
          { id: "sweep:to", x: c.sweep.to.x, y: c.sweep.to.y, label: `to ${fmt(c.sweep.to.degrees)}` }
        ]
      }
      case "band": {
        const outer = at(c.outer_d)
        const inner = at(c.inner_d)
        return [{ id: "band:outer", ...outer, label: `outer ${c.outer}` }, { id: "band:inner", ...inner, label: `width ${c.width}` }]
      }
      case "rule": return [{ id: "rule:distance", ...at(c.d), label: `rule ${c.distance}` }]
      case "interior": return [{ id: "interior:inside", ...at(c.d), label: `inset ${c.inside}` }]
      case "container":
      case "child": {
        const box = Canvas.bbox(c.d)
        const shape = this.doc.get(address, "shape.kind")
        const handles = [{ id: "shape:x", x: box.x + box.width, y: c.centroid.y, shape: "square", label: `${Math.round(box.width)} wide` }]
        if (shape !== "circle") handles.push({ id: "shape:y", x: c.centroid.x, y: box.y, shape: "square", label: `${Math.round(box.height)} tall` })
        if (c.anchor) handles.push({ id: "anchor", ...c.anchor })
        return handles
      }
      case "fit": {
        if (!c.chord) return c.anchor ? [{ id: "anchor", ...c.anchor }] : []
        const box = Canvas.bbox(c.chord)
        return [{ id: "chord:at", x: box.x + box.width / 2, y: box.y + box.height / 2, label: `at ${this.doc.get(address, "at")}` }]
      }
      case "fixed":
      case "illustration":
        return c.anchor ? [{ id: "anchor", ...c.anchor }] : []
      default: return []
    }
  }

  stagePointerDown(event) {
    const p = this.canvas.point(event)
    const handle = event.target.closest("[data-handle]")
    if (handle) {
      this.drag = { handle: handle.dataset.handle, start: p, snapshot: structuredClone(this.doc.entry(this.selected) || {}),
                    reference: { ...this.reference }, center: this.centroidOf(this.selected === "reference" ? "" : this.selected) }
      const c = this.entryOf(this.selected)
      if (c && this.drag.handle.startsWith("sweep") && typeof this.doc.get(this.selected, "sweep") !== "object") {
        // a preset sweep becomes the two angles it is, before either moves
        this.doc.set(this.selected, "sweep", { from: Math.round(c.sweep.from.degrees), to: Math.round(c.sweep.to.degrees) })
      }
      handle.classList.add("is-dragging")
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
    if (!event.target.closest("[data-address]")) {
      this.pan = { last: p, moved: false }
      this.svgTarget.classList.add("stage--panning")
      this.svgTarget.setPointerCapture(event.pointerId)
    }
  }

  stagePointerMove(event) {
    if (this.drag) {
      this.dragTo(this.canvas.point(event))
      event.preventDefault()
    } else if (this.pan) {
      const p = this.canvas.point(event)
      this.canvas.panBy(p.x - this.pan.last.x, p.y - this.pan.last.y)
      this.pan.moved = true
      this.status()
      this.setZoomButtons()
    }
  }

  stagePointerUp(event) {
    if (this.drag) {
      const wasReference = this.drag.handle.startsWith("reference")
      this.drag = null
      this.handlesTarget.querySelectorAll(".is-dragging").forEach((el) => el.classList.remove("is-dragging"))
      if (wasReference) this.saveReference()
      else this.scheduleRender(0)
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
    const target = event.target.closest("[data-address]")
    if (target) this.select(target.dataset.address)
    else if (event.target.closest("[data-reference]")) this.select("reference")
    this.svgTarget.focus({ preventScroll: true })
  }

  stageWheel(event) {
    event.preventDefault()
    this.canvas.zoomBy(Math.exp(event.deltaY * 0.0015), this.canvas.point(event))
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

  // Where a handle went, as the number it stands for.
  dragTo(p) {
    const { handle, start, snapshot, center } = this.drag
    const round = (v, places = 1) => Number(v.toFixed(places))
    const radial = center ? Canvas.distance(center, p) - Canvas.distance(center, start) : 0
    const set = (key, value) => { this.doc.set(this.selected, key, value); this.touched() }
    switch (handle) {
      case "sweep:from": set("sweep.from", Math.round(Canvas.degrees(center, p))); break
      case "sweep:to": set("sweep.to", Math.round(Canvas.degrees(center, p))); break
      case "band:outer": set("outer", round(snapshot.outer + radial)); break
      case "band:inner": set("width", round(Math.max(1, (snapshot.width ?? 40) - radial))); break
      case "rule:distance": set("distance", round(snapshot.distance + radial)); break
      case "interior:inside": set("inside", round(Math.min(0, (snapshot.inside ?? 0) + radial))); break
      case "shape:x": {
        const dx = p.x - start.x
        const shape = snapshot.shape || {}
        if (shape.kind === "circle") set("shape.radius", round(Math.max(1, shape.radius + dx)))
        else if (shape.kind === "ellipse") set("shape.rx", round(Math.max(1, shape.rx + dx)))
        else set("shape.width", round(Math.max(1, shape.width + 2 * dx)))
        break
      }
      case "shape:y": {
        const dy = start.y - p.y
        const shape = snapshot.shape || {}
        if (shape.kind === "ellipse") set("shape.ry", round(Math.max(1, shape.ry + dy)))
        else set("shape.height", round(Math.max(1, shape.height + 2 * dy)))
        break
      }
      case "chord:at": {
        const along = (snapshot.fit || "chord_at_y") === "chord_at_x" ? p.x - start.x : p.y - start.y
        set("at", round(snapshot.at + along))
        break
      }
      case "anchor": {
        const at = snapshot.at
        if (at && at.polar) {
          set("at.polar.angle", Math.round(Canvas.degrees(center, p)))
          set("at.polar.radius", round(Canvas.distance(center, p)))
        } else if (at && at.axial) {
          const box = Canvas.bbox(this.entryOf(Document.containerOf(this.selected)).d)
          set("at.axial[0]", round((p.x - box.x) / box.width, 3))
          set("at.axial[1]", round((p.y - box.y) / box.height, 3))
        }
        break
      }
      case "reference:move":
        this.reference.x = round(this.drag.reference.x + (p.x - start.x))
        this.reference.y = round(this.drag.reference.y + (p.y - start.y))
        this.drawReference()
        this.fillReferenceFields()
        return
      case "reference:scale": {
        const r = this.drag.reference
        const from = Canvas.distance({ x: r.x, y: r.y }, start)
        const to = Canvas.distance({ x: r.x, y: r.y }, p)
        this.reference.scale = round(Math.max(0.01, r.scale * (to / Math.max(1e-6, from))), 3)
        this.drawReference()
        this.fillReferenceFields()
        return
      }
    }
    this.renderTree()
    this.showInspector()
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
