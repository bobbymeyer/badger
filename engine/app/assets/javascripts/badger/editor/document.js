// The document the editor holds: the badge as Badger::Spec reads it, with
// the addresses the core's render hands back. An address names one entry —
// "" is the root container, "regions[0]" its first region,
// "children[1].type[0]" the first type in its second child — and a key
// names a value inside an entry, dotted for nesting: "shape.rx",
// "sweep.from", "at.axial[1]". Nothing here knows what a value means; that
// is the schema's, and the core's.
export class Document {
  constructor(spec) {
    this.spec = structuredClone(spec || {})
  }

  toJSON() { return this.spec }

  // --- addresses ---------------------------------------------------------

  static parseAddress(address) {
    if (!address) return []
    return address.split(".").map((part) => {
      const match = part.match(/^(\w+)\[(\d+)\]$/)
      if (!match) throw new Error(`not an address: ${address}`)
      return { key: match[1], index: Number(match[2]) }
    })
  }

  static parentOf(address) {
    const parts = Document.parseAddress(address)
    // the containing container: drop trailing non-child segments
    const kept = []
    for (const part of parts) {
      if (part.key === "children") kept.push(part)
      else break
    }
    return kept.map((p) => `${p.key}[${p.index}]`).join(".")
  }

  static containerOf(address) {
    // the container an entry belongs to; a container's own address is itself
    const parts = Document.parseAddress(address)
    const last = parts[parts.length - 1]
    if (!last || last.key === "children") return address
    return parts.slice(0, -1).map((p) => `${p.key}[${p.index}]`).join(".")
  }

  entry(address) {
    let node = this.spec
    for (const part of Document.parseAddress(address)) {
      node = node?.[part.key]?.[part.index]
      if (node === undefined) return undefined
    }
    return node
  }

  // The list an entry sits in and its index there, for removing and duplicating.
  slot(address) {
    const parts = Document.parseAddress(address)
    if (parts.length === 0) return null
    const last = parts[parts.length - 1]
    const holder = this.entry(parts.slice(0, -1).map((p) => `${p.key}[${p.index}]`).join("."))
    return { list: holder[last.key], index: last.index, key: last.key }
  }

  kindOf(address) {
    const entry = this.entry(address)
    if (!entry) return null
    if (address === "") return "container"
    const last = Document.parseAddress(address).pop()
    if (last.key === "children") return "child"
    if (last.key === "regions") return entry.kind
    if (last.key === "type") return entry.mode
    if (last.key === "illustrations") return "illustration"
    return null
  }

  // --- values --------------------------------------------------------------

  static parseKey(key) {
    return key.split(".").flatMap((part) => {
      const match = part.match(/^(\w+)\[(\d+)\]$/)
      return match ? [match[1], Number(match[2])] : [part]
    })
  }

  get(address, key) {
    let node = this.entry(address)
    for (const step of Document.parseKey(key)) {
      if (node === undefined || node === null) return undefined
      node = node[step]
    }
    return node
  }

  // Set a value; null or "" removes the key, so an optional field left
  // blank is an entry that does not mention it and takes the core's default.
  set(address, key, value) {
    const steps = Document.parseKey(key)
    let node = this.entry(address)
    for (let i = 0; i < steps.length - 1; i++) {
      const step = steps[i]
      if (node[step] === undefined || node[step] === null || typeof node[step] !== "object") {
        node[step] = typeof steps[i + 1] === "number" ? [] : {}
      }
      node = node[step]
    }
    const last = steps[steps.length - 1]
    if (value === null || value === undefined || value === "") {
      if (Array.isArray(node)) node[last] = null
      else delete node[last]
    } else {
      node[last] = value
    }
  }

  // --- the tree ------------------------------------------------------------

  // Every entry, depth first, in the order the core draws them.
  entries() {
    const out = []
    const walk = (container, address, depth) => {
      out.push({ address, kind: address === "" ? "container" : "child", entry: container, depth })
      const at = (key, i) => (address ? `${address}.${key}[${i}]` : `${key}[${i}]`)
      ;(container.regions || []).forEach((r, i) => out.push({ address: at("regions", i), kind: r.kind, entry: r, depth: depth + 1 }))
      ;(container.type || []).forEach((t, i) => out.push({ address: at("type", i), kind: t.mode, entry: t, depth: depth + 1 }))
      ;(container.illustrations || []).forEach((a, i) => out.push({ address: at("illustrations", i), kind: "illustration", entry: a, depth: depth + 1 }))
      ;(container.children || []).forEach((c, i) => walk(c, at("children", i), depth + 1))
    }
    walk(this.spec, "", 0)
    return out
  }

  // What the tree says of an entry: a label and, beside it, what it is and
  // where it goes in plain words — "over the top of ring", "the chord at
  // y −311", "24 units at the centroid" — rather than the model's keys.
  describe({ address, kind, entry }) {
    const shape = entry.shape?.kind?.replace(/_/g, " ")
    const n = (v) => (typeof v === "number" ? Document.number(v) : v)
    switch (kind) {
      case "container": return { label: entry.name || "Badge", meta: Document.shapeWords(entry.shape) }
      case "child": return { label: entry.name || "child", meta: `${Document.shapeWords(entry.shape)}, ${Document.placeWords(entry.at)}` }
      case "rule": {
        const d = entry.distance ?? 0
        return { label: entry.name || "rule", meta: d === 0 ? "rule at the edge" : `rule, ${n(Math.abs(d))} ${d < 0 ? "in" : "out"}` }
      }
      case "band": return { label: entry.name || "band", meta: `band, ${n(entry.width ?? "")} wide` }
      case "interior": return { label: entry.name || "field", meta: entry.inside ? `the field, inset ${n(Math.abs(entry.inside))}` : "the field" }
      case "follow": return { label: entry.name || entry.text || "text", meta: `${Document.sweepWords(entry.sweep, entry.reversed)} ${entry.region || "?"}` }
      case "fit": return { label: entry.name || entry.text || "text", meta: Document.fitWords(entry) }
      case "fixed": return { label: entry.name || entry.text || "text", meta: `${n(entry.size ?? "")} units, ${Document.placeWords(entry.at)}` }
      case "illustration": return { label: entry.name || "artwork", meta: `artwork, ${Document.placeWords(entry.at)}` }
      default: return { label: address, meta: "" }
    }
  }

  static number(v) {
    return Number.isInteger(v) ? String(v) : v.toFixed(1).replace(/\.0$/, "")
  }

  static shapeWords(shape) {
    if (!shape) return ""
    const kind = shape.kind?.replace(/_/g, " ") || "shape"
    if (shape.kind === "circle") return `circle, r ${Document.number(shape.radius ?? 0)}`
    if (shape.kind === "ellipse") return `ellipse, ${Document.number((shape.rx ?? 0) * 2)} × ${Document.number((shape.ry ?? 0) * 2)}`
    if (shape.width && shape.height) return `${kind}, ${Document.number(shape.width)} × ${Document.number(shape.height)}`
    return kind
  }

  static placeWords(at) {
    if (!at || at === "centroid") return "at the centroid"
    if (at.polar) return `at ${Document.number(at.polar.angle ?? 0)}°, ${Document.number(at.polar.radius ?? 0)} out`
    if (at.axial) return `at ${Math.round((at.axial[0] ?? 0.5) * 100)}% across, ${Math.round((at.axial[1] ?? 0.5) * 100)}% down`
    if (at.on_path) return `${Math.round((at.on_path.fraction ?? 0) * 100)}% along the path`
    return "placed"
  }

  static sweepWords(sweep, reversed) {
    if (sweep === undefined || sweep === "top") return "over the top of"
    if (sweep === "bottom") return "under the bottom of"
    if (sweep === "full") return "all the way round"
    if (sweep && sweep.from !== undefined) {
      const { centre, span } = Document.sweepCentreSpan(sweep, reversed)
      return `${Math.round(span)}° about ${Math.round(centre)}° on`
    }
    if (sweep && sweep.start !== undefined) return `from ${Math.round(sweep.start * 100)}% along`
    return "on"
  }

  static fitWords(entry) {
    const region = entry.region ? ` in ${entry.region}` : ""
    switch (entry.fit || "chord_at_y") {
      case "chord_at_y": return `the chord at y ${Document.number(entry.at ?? 0)}${region}`
      case "chord_at_x": return `the chord at x ${Document.number(entry.at ?? 0)}${region}`
      case "chord_at_x_per_glyph": return `each letter its chord${region}`
      case "box": return `a box${entry.height ? `, ${Document.number(entry.height)} tall` : ""}${entry.width ? `, ${Document.number(entry.width)} wide` : ""}`
      default: return "fitted"
    }
  }

  // A sweep given as two angles, as the centre it is about and the span
  // it covers. A run goes clockwise on the screen from `from` to `to`, and
  // the other way when reversed, so the same two angles are two sweeps.
  static sweepCentreSpan(sweep, reversed) {
    const mod = (v) => ((v % 360) + 360) % 360
    const from = Number(sweep.from ?? 0)
    const to = Number(sweep.to ?? 0)
    const span = reversed ? mod(from - to) : mod(to - from)
    const centre = mod(reversed ? from - span / 2 : from + span / 2)
    return { centre, span: span === 0 && from !== to ? 360 : span }
  }

  static sweepFromCentreSpan(centre, span, reversed) {
    const mod = (v) => ((v % 360) + 360) % 360
    const half = span / 2
    return reversed ? { from: mod(centre + half), to: mod(centre - half) } : { from: mod(centre - half), to: mod(centre + half) }
  }

  // Which container an address is in, as its tree label.
  containerLabel(address) {
    const container = this.entry(address) || this.spec
    return container.name || (address ? "child" : "Badge")
  }

  // The names of a container's regions of one kind, for the fields that
  // name one; type follows a band and is fitted to an interior.
  regionNames(containerAddress, kind) {
    const container = this.entry(containerAddress) || {}
    return (container.regions || []).filter((r) => r.kind === kind && r.name).map((r) => r.name)
  }

  // --- editing the tree ----------------------------------------------------

  // Add an entry to a container's list and answer its address.
  add(containerAddress, listKey, entry) {
    const container = this.entry(containerAddress)
    container[listKey] ||= []
    container[listKey].push(entry)
    const i = container[listKey].length - 1
    return containerAddress ? `${containerAddress}.${listKey}[${i}]` : `${listKey}[${i}]`
  }

  remove(address) {
    const slot = this.slot(address)
    if (!slot) return
    slot.list.splice(slot.index, 1)
  }

  duplicate(address) {
    const slot = this.slot(address)
    if (!slot) return address
    slot.list.splice(slot.index + 1, 0, structuredClone(slot.list[slot.index]))
    const parts = Document.parseAddress(address)
    parts[parts.length - 1].index += 1
    return parts.map((p) => `${p.key}[${p.index}]`).join(".")
  }

  setVisible(address, visible) {
    const entry = this.entry(address)
    if (!entry) return
    if (visible) delete entry.visible
    else entry.visible = false
    // a band or interior is invisible by default; say it explicitly either way
    const kind = this.kindOf(address)
    if (kind === "band" || kind === "interior") entry.visible = visible
  }

  isVisible(address) {
    const entry = this.entry(address)
    const kind = this.kindOf(address)
    if (entry?.visible !== undefined) return Boolean(entry.visible)
    return !(kind === "band" || kind === "interior")
  }
}
