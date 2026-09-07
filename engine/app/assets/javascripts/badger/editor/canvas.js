// The stage: an SVG with the drawing in it, the construction over it and
// the handles over that, in the badge's own units. Zoom and pan are a
// viewBox; every coordinate that comes in from a pointer is turned into
// badge units here, so the rest of the editor never sees a pixel.
export class Canvas {
  constructor(svg, layers) {
    this.svg = svg
    this.layers = layers
    this.content = { x: -100, y: -100, width: 200, height: 200 }
    this.mode = "fit"
    this.view = { ...this.content }
  }

  // --- coordinates -------------------------------------------------------

  // A pointer event as a point in badge units.
  point(event) {
    const rect = this.svg.getBoundingClientRect()
    const sx = this.view.width / rect.width
    const sy = this.view.height / rect.height
    return { x: this.view.x + (event.clientX - rect.left) * sx, y: this.view.y + (event.clientY - rect.top) * sy }
  }

  unitsPerPixel() {
    return this.view.width / this.svg.getBoundingClientRect().width
  }

  setView(view) {
    this.view = view
    this.svg.setAttribute("viewBox", `${view.x} ${view.y} ${view.width} ${view.height}`)
  }

  // --- zoom ----------------------------------------------------------------

  // The whole drawing, with air round it, at whatever scale fills the stage.
  fit() {
    this.mode = "fit"
    const rect = this.svg.getBoundingClientRect()
    const margin = 0.08
    const w = this.content.width * (1 + 2 * margin)
    const h = this.content.height * (1 + 2 * margin)
    const aspect = rect.width / rect.height
    let vw = w
    let vh = h
    if (w / h < aspect) vw = h * aspect
    else vh = w / aspect
    const cx = this.content.x + this.content.width / 2
    const cy = this.content.y + this.content.height / 2
    this.setView({ x: cx - vw / 2, y: cy - vh / 2, width: vw, height: vh })
  }

  // One badge unit is `scale` screen pixels, about the drawing's centre.
  zoomTo(scale) {
    this.mode = String(scale)
    const rect = this.svg.getBoundingClientRect()
    const vw = rect.width / scale
    const vh = rect.height / scale
    const cx = this.view.x + this.view.width / 2
    const cy = this.view.y + this.view.height / 2
    this.setView({ x: cx - vw / 2, y: cy - vh / 2, width: vw, height: vh })
  }

  zoomBy(factor, about) {
    this.mode = "free"
    const w = this.view.width * factor
    const h = this.view.height * factor
    const fx = (about.x - this.view.x) / this.view.width
    const fy = (about.y - this.view.y) / this.view.height
    this.setView({ x: about.x - fx * w, y: about.y - fy * h, width: w, height: h })
  }

  panBy(dx, dy) {
    this.mode = "free"
    this.setView({ ...this.view, x: this.view.x - dx, y: this.view.y - dy })
  }

  // The scale the drawing is shown at, as a percentage.
  percent() {
    return Math.round(100 / this.unitsPerPixel())
  }

  // --- the drawing ---------------------------------------------------------

  // The server's SVG: its pieces move into the pieces layer, its viewBox is
  // what the drawing occupies.
  setPieces(svgText) {
    const parsed = new DOMParser().parseFromString(svgText, "image/svg+xml")
    const root = parsed.documentElement
    const [x, y, width, height] = (root.getAttribute("viewBox") || "0 0 100 100").split(/\s+/).map(Number)
    this.content = { x, y, width, height }
    const layer = this.layers.pieces
    layer.replaceChildren(...Array.from(root.children).map((child) => document.importNode(child, true)))
    if (this.mode === "fit") this.fit()
  }

  // --- construction --------------------------------------------------------

  static svg(tag, attributes = {}) {
    const el = document.createElementNS("http://www.w3.org/2000/svg", tag)
    for (const [key, value] of Object.entries(attributes)) {
      if (value !== undefined && value !== null) el.setAttribute(key, value)
    }
    return el
  }

  // Every construction entry drawn as hairlines, the selected one in the
  // accent, with dots at each letter of a selected run and a mark at any
  // warning.
  setConstruction(entries, selected, warnings) {
    const layer = this.layers.construction
    layer.replaceChildren()
    const mk = Canvas.svg
    const u = this.unitsPerPixel()
    const classes = (base, address) => `${base}${address === selected ? " is-selected" : ""}`
    for (const c of entries) {
      switch (c.kind) {
        case "container":
          layer.append(mk("path", { d: c.d, class: classes("construction--container", c.address), "data-address": c.address }))
          break
        case "offset":
        case "rule":
          layer.append(mk("path", { d: c.d, class: classes("construction--rule", c.address), "data-address": c.address }))
          break
        case "band":
          layer.append(mk("path", { d: c.outer_d, class: classes("construction--edge", c.address), "data-address": c.address }))
          layer.append(mk("path", { d: c.inner_d, class: classes("construction--edge", c.address), "data-address": c.address }))
          break
        case "interior":
          layer.append(mk("path", { d: c.d, class: classes("construction--edge", c.address), "data-address": c.address }))
          break
        case "follow":
          layer.append(mk("path", { d: c.d, class: classes("construction--baseline", c.address), "data-address": c.address }))
          if (c.address === selected) {
            for (const p of c.letters) layer.append(mk("circle", { cx: p.x, cy: p.y, r: 2.5 * u, class: "construction--letter" }))
          }
          break
        default:
          if (c.chord) layer.append(mk("path", { d: c.chord, class: classes("construction--chord", c.address), "data-address": c.address }))
          if (c.anchor) layer.append(mk("circle", { cx: c.anchor.x, cy: c.anchor.y, r: 3 * u, class: classes("construction--anchor", c.address), "data-address": c.address }))
      }
    }
    for (const w of warnings || []) {
      const c = entries.find((e) => e.address === w.address)
      const at = c?.run?.from || c?.anchor
      if (!at) continue
      layer.append(mk("circle", { cx: at.x, cy: at.y, r: 4 * u, class: "construction--warning" }))
      const text = mk("text", { x: at.x + 7 * u, y: at.y + 3.5 * u, class: "construction--warning-text", style: `font-size: ${11 * u}px` })
      text.textContent = w.message.split(":")[0]
      layer.append(text)
    }
  }

  // --- handles -------------------------------------------------------------

  // Each handle says what it drags — as its cursor, and as a tooltip that
  // names the number it stands for — and carries its label beside it.
  setHandles(handles) {
    const layer = this.layers.handles
    layer.replaceChildren()
    const u = this.unitsPerPixel()
    for (const h of handles) {
      const el = h.shape === "square"
        ? Canvas.svg("rect", { x: h.x - 4 * u, y: h.y - 4 * u, width: 8 * u, height: 8 * u, "data-handle": h.id })
        : Canvas.svg("circle", { cx: h.x, cy: h.y, r: 5 * u, "data-handle": h.id })
      el.classList.add(`handle--${Canvas.cursorFor(h.id)}`)
      const title = Canvas.svg("title")
      title.textContent = h.title || h.label || h.id
      el.append(title)
      layer.append(el)
      if (h.label) {
        const text = Canvas.svg("text", { x: h.x + 8 * u, y: h.y - 8 * u, class: "handle--label", style: `font-size: ${11 * u}px`, "data-handle-label": h.id })
        text.textContent = h.label
        layer.append(text)
      }
    }
  }

  static cursorFor(id) {
    if (id.startsWith("sweep")) return "turn"
    if (id === "shape:x") return "ew"
    if (id === "shape:y") return "ns"
    if (id === "anchor" || id === "reference:move") return "move"
    if (id === "chord:at") return "ns"
    return "radial"
  }

  // A handle moved to where the pointer put it, before the drawing catches
  // up: the hand should never wait on the server.
  moveHandle(id, point, label) {
    const u = this.unitsPerPixel()
    const el = this.layers.handles.querySelector(`[data-handle="${CSS.escape(id)}"]`)
    if (!el) return
    if (el.tagName === "rect") { el.setAttribute("x", point.x - 4 * u); el.setAttribute("y", point.y - 4 * u) } else { el.setAttribute("cx", point.x); el.setAttribute("cy", point.y) }
    const text = this.layers.handles.querySelector(`[data-handle-label="${CSS.escape(id)}"]`)
    if (text) {
      text.setAttribute("x", point.x + 8 * u)
      text.setAttribute("y", point.y - 8 * u)
      if (label !== undefined) text.textContent = label
    }
  }

  // The handle a field is the number of, lit while the pointer is over the
  // field; none, when it leaves.
  lightHandles(ids) {
    for (const el of this.layers.handles.querySelectorAll("[data-handle]")) {
      el.classList.toggle("is-lit", ids.includes(el.dataset.handle))
    }
  }

  // The point on a path nearest a point, as a fraction of the path's length.
  static fractionAlong(d, point, samples = 720) {
    const path = Canvas.svg("path", { d })
    const total = path.getTotalLength()
    let best = { fraction: 0, dist: Infinity }
    for (let i = 0; i < samples; i++) {
      const p = path.getPointAtLength((total * i) / samples)
      const dist = Math.hypot(p.x - point.x, p.y - point.y)
      if (dist < best.dist) best = { fraction: i / samples, dist }
    }
    return best.fraction
  }

  // --- the reference and the grid -------------------------------------------

  setReference(reference, selected) {
    const layer = this.layers.reference
    layer.replaceChildren()
    if (!reference || !reference.url) return
    const w = reference.width * reference.scale
    const h = reference.height * reference.scale
    layer.append(Canvas.svg("image", {
      href: reference.url, x: reference.x - w / 2, y: reference.y - h / 2, width: w, height: h,
      opacity: reference.opacity, preserveAspectRatio: "none", class: selected ? "is-selected" : null, "data-reference": true
    }))
  }

  referenceHandles(reference) {
    const w = reference.width * reference.scale
    const h = reference.height * reference.scale
    return [{ id: "reference:scale", x: reference.x + w / 2, y: reference.y + h / 2, shape: "square", label: `${Math.round(w)} × ${Math.round(h)} units` }]
  }

  setGrid(on, step = 50) {
    const layer = this.layers.grid
    layer.replaceChildren()
    layer.hidden = !on
    if (!on) return
    const b = this.content
    const pad = Math.max(b.width, b.height)
    const x0 = Math.floor((b.x - pad) / step) * step
    const x1 = b.x + b.width + pad
    const y0 = Math.floor((b.y - pad) / step) * step
    const y1 = b.y + b.height + pad
    for (let x = x0; x <= x1; x += step) {
      layer.append(Canvas.svg("line", { x1: x, y1: y0, x2: x, y2: y1, class: x === 0 ? "grid--axis" : null }))
    }
    for (let y = y0; y <= y1; y += step) {
      layer.append(Canvas.svg("line", { x1: x0, y1: y, x2: x1, y2: y, class: y === 0 ? "grid--axis" : null }))
    }
  }

  // --- geometry helpers --------------------------------------------------

  // The point on a path (as path data) nearest a visual angle from a centre.
  static pointAtAngle(d, center, degrees, samples = 360) {
    const path = Canvas.svg("path", { d })
    const total = path.getTotalLength()
    const target = ((degrees % 360) + 360) % 360
    let best = null
    for (let i = 0; i < samples; i++) {
      const p = path.getPointAtLength((total * i) / samples)
      const seen = ((Math.atan2(p.y - center.y, p.x - center.x) * 180) / Math.PI + 360) % 360
      const diff = Math.min(Math.abs(seen - target), 360 - Math.abs(seen - target))
      if (!best || diff < best.diff) best = { diff, x: p.x, y: p.y }
    }
    return best
  }

  static degrees(center, p) {
    return ((Math.atan2(p.y - center.y, p.x - center.x) * 180) / Math.PI + 360) % 360
  }

  static distance(a, b) {
    return Math.hypot(a.x - b.x, a.y - b.y)
  }

  static bbox(d) {
    const path = Canvas.svg("path", { d })
    const holder = Canvas.svg("svg")
    holder.style.position = "absolute"
    holder.style.width = "0"
    holder.style.height = "0"
    holder.append(path)
    document.body.append(holder)
    const box = path.getBBox()
    holder.remove()
    return { x: box.x, y: box.y, width: box.width, height: box.height }
  }
}
