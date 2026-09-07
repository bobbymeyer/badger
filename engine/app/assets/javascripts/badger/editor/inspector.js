import { Document } from "badger/editor/document"

// The inspector: what the selected entry is, the fields it takes, and what
// can be done to it. Built from the schema the server hands over, in the
// library's own field markup cloned from templates the view carries, so the
// fields here are the fields everywhere else in the tool.
//
// The fields are in four groups, the way a designer asks: what the entry
// is, where it goes, how it is set, how it looks; the rare ones wait behind
// "More". A number can be typed, nudged with the arrows, or scrubbed by
// dragging its label; a field that is the number of a handle on the drawing
// lights the handle when the pointer is over it.
const ALIGNS = ["top_left", "top", "top_right", "left", "center", "right", "bottom_left", "bottom", "bottom_right"]
const KIND_LABELS = {
  container: "Container", child: "Child container",
  rule: "Region · a rule", band: "Region · a band", interior: "Region · an interior",
  follow: "Type · follows a band", fit: "Type · fitted", fixed: "Type · fixed", illustration: "Artwork"
}
const GROUPS = [["what", "What"], ["where", "Where"], ["how", "How"], ["look", "Look"]]
const MODES = {
  region: [["rule", "a rule"], ["band", "a band"], ["interior", "an interior"]],
  type: [["follow", "follows a band"], ["fit", "fitted to a chord"], ["fixed", "at a fixed size"]]
}
// Which field a warning is about, by what it says.
const WARNING_FIELDS = [[/tracking/i, "tracking"], [/overflow|sweep/i, "sweep"], [/size/i, "size"]]

export class Inspector {
  constructor(root, templates, { fonts, onChange, onAction, onHover }) {
    this.root = root
    this.templates = templates
    this.fonts = fonts
    this.onChange = onChange
    this.onAction = onAction
    this.onHover = onHover || (() => {})
    this.counter = 0
    this.open = {}
  }

  clone(name) {
    return this.templates.content.querySelector(`[data-field="${name}"]`).cloneNode(true)
  }

  // --- what is shown -------------------------------------------------------

  empty() {
    this.root.replaceChildren()
    const p = document.createElement("p")
    p.className = "inspector__empty"
    p.textContent = "Select a line of the document, or a piece of the drawing."
    this.root.append(p)
  }

  show({ address, kind, entry, fields, doc, regions, warnings, error }) {
    this.address = address
    this.kind = kind
    this.doc = doc
    this.root.replaceChildren()
    this.root.append(this.head(kind, entry, address))

    const shown = fields.filter((field) => this.applies(field, fields))
    const placed = new Set()
    const unplacedWarnings = (warnings || []).filter((w) => !shown.some((f) => this.warningKey(w) === f.key))
    for (const w of unplacedWarnings) this.root.append(this.warning(w.message))

    for (const [group, title] of GROUPS) {
      const own = shown.filter((f) => (f.group || "what") === group)
      if (!own.length) continue
      const section = document.createElement("section")
      section.className = "inspector__group"
      const heading = document.createElement("p")
      heading.className = "inspector__group-name"
      heading.textContent = title
      section.append(heading)
      const list = document.createElement("div")
      list.className = "inspector__fields"
      const more = document.createElement("div")
      more.className = "inspector__fields"
      for (const field of own) {
        const built = this.build(field, regions)
        if (!built) continue
        const target = field.more ? more : list
        target.append(built)
        for (const w of (warnings || []).filter((w) => this.warningKey(w) === field.key)) {
          target.append(this.warning(w.message))
          placed.add(w)
        }
      }
      section.append(list)
      if (more.children.length) {
        const details = document.createElement("details")
        details.className = "inspector__more"
        details.open = Boolean(this.open[`${kind}:${group}`])
        details.addEventListener("toggle", () => { this.open[`${kind}:${group}`] = details.open })
        const summary = document.createElement("summary")
        summary.textContent = "More"
        details.append(summary, more)
        section.append(details)
      }
      this.root.append(section)
    }

    if (error) this.root.append(this.warning(error))

    if (address !== "") {
      const actions = document.createElement("p")
      actions.className = "micro inspector__actions"
      const duplicate = document.createElement("button")
      duplicate.type = "button"
      duplicate.textContent = "Duplicate"
      duplicate.addEventListener("click", () => this.onAction("duplicate", address))
      const remove = document.createElement("button")
      remove.type = "button"
      remove.textContent = "Remove"
      remove.className = "is-danger"
      remove.title = "Remove this entry (undo with ⌘Z)"
      remove.addEventListener("click", () => this.onAction("remove", address))
      actions.append(duplicate, " · ", remove)
      this.root.append(actions)
    }
  }

  // What the entry is, its name, and — for a region or a run of type —
  // which kind it is, changed here rather than among its numbers.
  head(kind, entry, address) {
    const head = document.createElement("div")
    head.className = "inspector__head"
    const kindLine = document.createElement("p")
    kindLine.className = "micro quiet inspector__kind"
    kindLine.textContent = KIND_LABELS[kind] || kind
    const name = document.createElement("h3")
    name.className = "inspector__name"
    name.textContent = entry.name || entry.text || (address === "" ? "Badge" : kind)
    head.append(kindLine, name)
    const family = ["rule", "band", "interior"].includes(kind) ? "region" : ["follow", "fit", "fixed"].includes(kind) ? "type" : null
    if (family) {
      const label = document.createElement("label")
      label.className = "inspector__mode"
      const key = family === "region" ? "kind" : "mode"
      const select = document.createElement("select")
      select.setAttribute("aria-label", family === "region" ? "Kind of region" : "How the type is set")
      for (const [value, text] of MODES[family]) {
        const option = document.createElement("option")
        option.value = value
        option.textContent = text
        select.append(option)
      }
      select.value = kind
      select.addEventListener("change", () => this.onChange(key, select.value))
      label.append(select)
      head.append(label)
    }
    return head
  }

  warning(message) {
    const p = this.clone("error")
    p.classList.add("inspector__error")
    p.textContent = message
    return p
  }

  warningKey(warning) {
    const found = WARNING_FIELDS.find(([pattern]) => pattern.test(warning.message))
    return found ? found[1] : null
  }

  showError(message) {
    this.root.querySelectorAll(".inspector__error--render").forEach((el) => el.remove())
    if (!message) return
    const p = this.clone("error")
    p.classList.add("inspector__error", "inspector__error--render")
    p.textContent = message
    this.root.append(p)
  }

  // Light the field that is the number of a handle, while the handle is
  // taken hold of.
  light(handleId) {
    for (const el of this.root.querySelectorAll("[data-handle]")) {
      el.classList.toggle("is-lit", Boolean(handleId) && el.dataset.handle.split(" ").includes(handleId))
    }
  }

  // A field with a `when` shows only when the key it names has one of the
  // values it lists; a key that is not written has its own field's default.
  applies(field, fields) {
    if (!field.when) return true
    let value = this.doc.get(this.address, field.when.key)
    if (value === undefined) value = fields.find((f) => f.key === field.when.key && !f.when)?.default
    return field.when.in.includes(String(value))
  }

  // --- fields ----------------------------------------------------------------

  id() {
    this.counter += 1
    return `inspector-field-${this.counter}`
  }

  value(key) {
    return this.doc.get(this.address, key)
  }

  build(field, regions) {
    let el
    switch (field.type) {
      case "text": el = this.textField(field); break
      case "textarea": el = this.textField(field, "textarea"); break
      case "number": el = this.numberField(field); break
      case "select": el = this.selectField(field, field.options); break
      case "toggle": el = this.toggleField(field); break
      case "font": el = this.selectField(field, this.fonts.map((f) => [f, f])); break
      case "region": el = this.selectField(field, (regions[field.of] || []).map((r) => [r, r])); break
      case "align": el = this.alignField(field); break
      case "locator": el = this.locatorField(field); break
      case "sweep": el = this.sweepField(field); break
      case "stretch": el = this.stretchField(field); break
      default: return null
    }
    return this.handled(el, field)
  }

  // A field that is the number of a handle on the drawing lights it when
  // the pointer is over the field.
  handled(el, field) {
    if (!field.handle || !el) return el
    const wrap = document.createElement("div")
    wrap.className = "inspector__handled"
    wrap.dataset.handle = field.handle
    wrap.append(el)
    wrap.addEventListener("pointerenter", () => this.onHover(field.handle, true))
    wrap.addEventListener("pointerleave", () => this.onHover(field.handle, false))
    return wrap
  }

  withHint(el, field) {
    if (!field.hint) return el
    const wrap = document.createDocumentFragment()
    const hint = this.clone("hint")
    hint.textContent = field.hint
    wrap.append(el, hint)
    return wrap
  }

  label(el, field, id) {
    const label = el.querySelector("label")
    label.textContent = field.label
    label.setAttribute("for", id)
    return label
  }

  textField(field, kind = "text") {
    const el = this.clone(kind === "textarea" ? "textarea" : "text")
    const id = this.id()
    this.label(el, field, id)
    const input = el.querySelector("input, textarea")
    input.id = id
    input.value = this.value(field.key) ?? ""
    input.addEventListener("input", () => this.onChange(field.key, input.value === "" ? null : input.value))
    return this.withHint(el, field)
  }

  // A number: typed, nudged with the arrows (Shift for tens), or scrubbed by
  // dragging its label sideways. `factor` shows a fraction as a percentage.
  numberField(field, key = field.key, label = field.label, write = null) {
    const el = this.clone("number")
    const id = this.id()
    const labelEl = this.label(el, { label }, id)
    const input = el.querySelector("input")
    input.id = id
    const factor = field.factor || 1
    const step = field.step || 1
    if (field.step) input.step = field.step
    const value = this.value(key)
    input.value = value === undefined || value === null ? "" : Inspector.round(value * factor)
    if (field.optional && field.default !== undefined) input.placeholder = field.default
    el.querySelector(".unit").textContent = field.unit || ""
    const emit = () => {
      const raw = input.value
      const number = raw === "" ? null : Inspector.round(Number(raw) / factor)
      if (write) write(number)
      else this.onChange(key, number)
    }
    input.addEventListener("input", emit)
    input.addEventListener("keydown", (event) => {
      if ((event.key === "ArrowUp" || event.key === "ArrowDown") && event.shiftKey) {
        event.preventDefault()
        const current = Number(input.value || input.placeholder || 0)
        input.value = Inspector.round(current + (event.key === "ArrowUp" ? 10 : -10) * step)
        emit()
      }
    })
    // scrubbing: the label is a slider without a track
    labelEl.classList.add("scrub")
    labelEl.title = "Drag sideways to change"
    labelEl.addEventListener("pointerdown", (event) => {
      if (event.button !== 0) return
      event.preventDefault()
      const startX = event.clientX
      const startValue = Number(input.value || input.placeholder || 0)
      labelEl.setPointerCapture(event.pointerId)
      labelEl.classList.add("is-scrubbing")
      const move = (e) => {
        const ticks = Math.round((e.clientX - startX) / 3)
        input.value = Inspector.round(startValue + ticks * step * (e.shiftKey ? 10 : 1))
        emit()
      }
      const up = () => {
        labelEl.classList.remove("is-scrubbing")
        labelEl.removeEventListener("pointermove", move)
        labelEl.removeEventListener("pointerup", up)
        labelEl.removeEventListener("pointercancel", up)
      }
      labelEl.addEventListener("pointermove", move)
      labelEl.addEventListener("pointerup", up)
      labelEl.addEventListener("pointercancel", up)
    })
    return this.withHint(el, field)
  }

  static round(v) {
    return Number(Number(v).toFixed(3))
  }

  selectField(field, options) {
    const el = this.clone("select")
    const id = this.id()
    this.label(el, field, id)
    const select = el.querySelector("select")
    select.id = id
    const current = this.value(field.key)
    if (field.optional) {
      const blank = document.createElement("option")
      blank.value = ""
      blank.textContent = field.default !== undefined ? `${String(field.default).replace(/_/g, " ")} (default)` : "—"
      select.append(blank)
    }
    for (const [value, text] of options) {
      const option = document.createElement("option")
      option.value = value
      option.textContent = text
      select.append(option)
    }
    select.value = current === undefined || current === null ? "" : String(current)
    if (select.value !== (current ?? "") && current !== undefined && current !== null) {
      // a value the options do not carry: keep it visible rather than lose it
      const option = document.createElement("option")
      option.value = String(current)
      option.textContent = String(current)
      select.append(option)
      select.value = String(current)
    }
    select.addEventListener("change", () => this.onChange(field.key, select.value === "" ? null : select.value))
    return this.withHint(el, field)
  }

  toggleField(field) {
    const el = this.clone("toggle")
    const input = el.querySelector("input")
    input.id = this.id()
    const value = this.value(field.key)
    input.checked = value === undefined ? Boolean(field.default) : Boolean(value)
    el.querySelector("span").textContent = field.label
    input.addEventListener("change", () => this.onChange(field.key, input.checked))
    return this.withHint(el, field)
  }

  // Which of the nine reference points lands on the locator: a three by
  // three of buttons, the one chosen filled.
  alignField(field) {
    const el = this.clone("nine")
    el.querySelector("label").textContent = field.label
    const grid = el.querySelector(".nine")
    const current = this.value(field.key) || "center"
    for (const value of ALIGNS) {
      const button = document.createElement("button")
      button.type = "button"
      button.className = "nine__point"
      button.dataset.value = value
      button.setAttribute("aria-pressed", String(value === current))
      button.setAttribute("aria-label", value.replace("_", " "))
      button.title = value.replace("_", " ")
      button.addEventListener("click", () => {
        grid.querySelectorAll(".nine__point").forEach((b) => b.setAttribute("aria-pressed", String(b === button)))
        this.onChange(field.key, value === "center" ? null : value)
      })
      grid.append(button)
    }
    return this.withHint(el, field)
  }

  // Where a child is put: one of four locators, each with its own numbers,
  // in degrees and units, or as percentages of the parent.
  locatorField(field) {
    const wrap = document.createElement("div")
    wrap.className = "inspector__compound"
    const value = this.value(field.key)
    const mode = typeof value === "string" ? value : value ? Object.keys(value)[0] : "centroid"
    const modes = [["centroid", "the centroid"], ["polar", "an angle and a radius"], ["axial", "a fraction across and down"], ["on_path", "a point along the path"]]
    const el = this.clone("select")
    const id = this.id()
    this.label(el, field, id)
    const select = el.querySelector("select")
    select.id = id
    for (const [v, t] of modes) {
      const option = document.createElement("option")
      option.value = v
      option.textContent = t
      select.append(option)
    }
    select.value = mode
    select.addEventListener("change", () => {
      const starters = { centroid: "centroid", polar: { polar: { angle: 90, radius: 100 } }, axial: { axial: [0.5, 0.5] }, on_path: { on_path: { fraction: 0.25 } } }
      this.onChange(field.key, starters[select.value])
    })
    wrap.append(el)
    const pair = document.createElement("div")
    pair.className = "inspector__pair"
    if (mode === "polar") {
      pair.append(this.numberField({ step: 1, unit: "°" }, `${field.key}.polar.angle`, "Angle"), this.numberField({ step: 1 }, `${field.key}.polar.radius`, "Radius"))
    } else if (mode === "axial") {
      pair.append(this.numberField({ step: 1, factor: 100, unit: "%" }, `${field.key}.axial[0]`, "Across"), this.numberField({ step: 1, factor: 100, unit: "%" }, `${field.key}.axial[1]`, "Down"))
    } else if (mode === "on_path") {
      pair.append(this.numberField({ step: 1, factor: 100, unit: "%" }, `${field.key}.on_path.fraction`, "Along the path"))
    }
    if (pair.children.length) wrap.append(pair)
    return this.withHint(wrap, field)
  }

  // The sweep a run takes: a side, the whole way round, or a centre and a
  // span in degrees, which is how a badge is thought about — "over the top,
  // 136° wide" — with the two angles they come to said underneath.
  sweepField(field) {
    const wrap = document.createElement("div")
    wrap.className = "inspector__compound"
    const value = this.value(field.key)
    const reversed = Boolean(this.value("reversed"))
    const mode = typeof value === "string" ? value : value && (value.from !== undefined || value.to !== undefined) ? "degrees" : value ? "fraction" : "top"
    const el = this.clone("select")
    const id = this.id()
    this.label(el, field, id)
    const select = el.querySelector("select")
    select.id = id
    for (const [v, t] of [["top", "over the top"], ["bottom", "under the bottom"], ["full", "all the way round"], ["degrees", "a centre and a span"], ["fraction", "a start and a length along the path"]]) {
      const option = document.createElement("option")
      option.value = v
      option.textContent = t
      select.append(option)
    }
    select.value = mode
    select.addEventListener("change", () => {
      const starters = { top: "top", bottom: "bottom", full: "full", degrees: Document.sweepFromCentreSpan(reversed ? 90 : 270, 140, reversed), fraction: { start: 0, length: 0.5 } }
      this.onChange(field.key, starters[select.value])
    })
    wrap.append(el)
    const pair = document.createElement("div")
    pair.className = "inspector__pair"
    if (mode === "degrees") {
      const { centre, span } = Document.sweepCentreSpan(value, reversed)
      const state = { centre: Math.round(centre), span: Math.round(span) }
      const commit = () => this.onChange(field.key, Document.sweepFromCentreSpan(state.centre, state.span, reversed))
      const centreField = this.numberField({ step: 1, unit: "°" }, `${field.key}.__centre`, "Centre", (v) => { if (v !== null) { state.centre = v; commit() } })
      const spanField = this.numberField({ step: 1, unit: "°" }, `${field.key}.__span`, "Span", (v) => { if (v !== null) { state.span = Math.max(1, Math.min(360, v)); commit() } })
      centreField.querySelector("input").value = state.centre
      spanField.querySelector("input").value = state.span
      pair.append(centreField, spanField)
      const note = this.clone("hint")
      note.classList.add("inspector__note")
      note.textContent = `From ${Math.round(value.from)}° to ${Math.round(value.to)}°${reversed ? ", reversed" : ""}. 270° is the top, 90° the bottom.`
      wrap.append(pair, note)
      return this.withHint(wrap, { ...field, hint: null })
    } else if (mode === "fraction") {
      pair.append(this.numberField({ step: 1, factor: 100, unit: "%" }, `${field.key}.start`, "Start"), this.numberField({ step: 1, factor: 100, unit: "%" }, `${field.key}.length`, "Length"))
    }
    if (pair.children.length) wrap.append(pair)
    return this.withHint(wrap, field)
  }

  // How far the width may leave the height: a range, or none.
  stretchField(field) {
    const wrap = document.createElement("div")
    wrap.className = "inspector__compound"
    const pair = document.createElement("div")
    pair.className = "inspector__pair"
    pair.append(this.numberField({ step: 5, factor: 100, unit: "%" }, `${field.key}.min`, "Stretch at least"), this.numberField({ step: 5, factor: 100, unit: "%" }, `${field.key}.max`, "at most"))
    wrap.append(pair)
    return this.withHint(wrap, field)
  }
}
