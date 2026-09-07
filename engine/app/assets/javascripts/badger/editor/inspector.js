// The inspector: what the selected entry is, the fields it takes, and what
// can be done to it. Built from the schema the server hands over, in the
// library's own field markup cloned from templates the view carries, so the
// fields here are the fields everywhere else in the tool.
const ALIGNS = ["center", "top", "bottom", "left", "right", "top_left", "top_right", "bottom_left", "bottom_right"]
const KIND_LABELS = {
  container: "Container", child: "Child container",
  rule: "Region · a rule", band: "Region · a band", interior: "Region · an interior",
  follow: "Type · follows a band", fit: "Type · fitted", fixed: "Type · fixed", illustration: "Artwork"
}

export class Inspector {
  constructor(root, templates, { fonts, onChange, onAction }) {
    this.root = root
    this.templates = templates
    this.fonts = fonts
    this.onChange = onChange
    this.onAction = onAction
    this.counter = 0
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
    this.doc = doc
    this.root.replaceChildren()

    const head = document.createElement("div")
    const kindLine = document.createElement("p")
    kindLine.className = "micro quiet inspector__kind"
    kindLine.textContent = KIND_LABELS[kind] || kind
    const name = document.createElement("h3")
    name.className = "inspector__name"
    name.textContent = entry.name || entry.text || (address === "" ? "Badge" : kind)
    head.append(kindLine, name)
    this.root.append(head)

    const list = document.createElement("div")
    list.className = "inspector__fields"
    for (const field of fields) {
      if (!this.applies(field, fields)) continue
      const built = this.build(field, regions)
      if (built) list.append(built)
    }
    this.root.append(list)

    for (const w of warnings || []) {
      const p = this.clone("error")
      p.classList.add("inspector__error")
      p.textContent = w.message
      this.root.append(p)
    }
    if (error) {
      const p = this.clone("error")
      p.classList.add("inspector__error")
      p.textContent = error
      this.root.append(p)
    }

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
      remove.addEventListener("click", () => this.onAction("remove", address))
      actions.append(duplicate, " · ", remove)
      this.root.append(actions)
    }
  }

  showError(message) {
    this.root.querySelectorAll(".inspector__error--render").forEach((el) => el.remove())
    if (!message) return
    const p = this.clone("error")
    p.classList.add("inspector__error", "inspector__error--render")
    p.textContent = message
    this.root.append(p)
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
    switch (field.type) {
      case "text": return this.textField(field)
      case "textarea": return this.textField(field, "textarea")
      case "number": return this.numberField(field)
      case "select": return this.selectField(field, field.options)
      case "toggle": return this.toggleField(field)
      case "font": return this.selectField(field, this.fonts.map((f) => [f, f]))
      case "region": return this.selectField(field, (regions[field.of] || []).map((r) => [r, r]))
      case "align": return this.selectField({ ...field, optional: true, default: "center" }, ALIGNS.map((a) => [a, a.replace("_", " ")]))
      case "locator": return this.locatorField(field)
      case "sweep": return this.sweepField(field)
      case "stretch": return this.stretchField(field)
      default: return null
    }
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

  numberField(field, key = field.key, label = field.label) {
    const el = this.clone("number")
    const id = this.id()
    this.label(el, { label }, id)
    const input = el.querySelector("input")
    input.id = id
    if (field.step) input.step = field.step
    const value = this.value(key)
    input.value = value === undefined || value === null ? "" : value
    if (field.optional && field.default !== undefined) input.placeholder = field.default
    el.querySelector(".unit").textContent = field.unit || ""
    input.addEventListener("input", () => {
      const raw = input.value
      this.onChange(key, raw === "" ? null : Number(raw))
    })
    return this.withHint(el, field)
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

  // Where a child is put: one of four locators, each with its own numbers.
  locatorField(field) {
    const wrap = document.createElement("div")
    wrap.className = "inspector__compound"
    const value = this.value(field.key)
    const mode = typeof value === "string" ? value : value ? Object.keys(value)[0] : "centroid"
    const modes = [["centroid", "centroid"], ["polar", "polar: an angle and a radius"], ["axial", "axial: fractions of the bounds"], ["on_path", "on the path"]]
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
      pair.append(this.numberField({ step: 0.01 }, `${field.key}.axial[0]`, "Across"), this.numberField({ step: 0.01 }, `${field.key}.axial[1]`, "Down"))
    } else if (mode === "on_path") {
      pair.append(this.numberField({ step: 0.01 }, `${field.key}.on_path.fraction`, "Fraction along"))
    }
    if (pair.children.length) wrap.append(pair)
    return this.withHint(wrap, field)
  }

  // The sweep a run takes: a side, the whole way round, or two angles.
  sweepField(field) {
    const wrap = document.createElement("div")
    wrap.className = "inspector__compound"
    const value = this.value(field.key)
    const mode = typeof value === "string" ? value : value && (value.from !== undefined || value.to !== undefined) ? "degrees" : value ? "fraction" : "top"
    const el = this.clone("select")
    const id = this.id()
    this.label(el, field, id)
    const select = el.querySelector("select")
    select.id = id
    for (const [v, t] of [["top", "over the top"], ["bottom", "under the bottom"], ["full", "all the way round"], ["degrees", "between two angles"], ["fraction", "a start and a length"]]) {
      const option = document.createElement("option")
      option.value = v
      option.textContent = t
      select.append(option)
    }
    select.value = mode
    select.addEventListener("change", () => {
      const starters = { top: "top", bottom: "bottom", full: "full", degrees: { from: 200, to: 340 }, fraction: { start: 0, length: 0.5 } }
      this.onChange(field.key, starters[select.value])
    })
    wrap.append(el)
    const pair = document.createElement("div")
    pair.className = "inspector__pair"
    if (mode === "degrees") {
      pair.append(this.numberField({ step: 1, unit: "° from" }, `${field.key}.from`, "From"), this.numberField({ step: 1, unit: "° to" }, `${field.key}.to`, "To"))
    } else if (mode === "fraction") {
      pair.append(this.numberField({ step: 0.01 }, `${field.key}.start`, "Start"), this.numberField({ step: 0.01 }, `${field.key}.length`, "Length"))
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
    pair.append(this.numberField({ step: 0.05 }, `${field.key}.min`, "Stretch at least"), this.numberField({ step: 0.05 }, `${field.key}.max`, "at most"))
    wrap.append(pair)
    return this.withHint(wrap, field)
  }
}
