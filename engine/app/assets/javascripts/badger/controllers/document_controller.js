import { Controller } from "@hotwired/stimulus"

// The document is YAML, and YAML is indentation. A textarea hands Tab to the
// browser, which moves focus to the next control; here it puts two spaces
// under the cursor instead, and Shift-Tab takes two away, so a document can
// be indented the way it is read. Nothing else: the editor is the server's,
// and a document that does not build is refused where it is typed.
export default class extends Controller {
  static values = { step: { type: Number, default: 2 } }

  indent(event) {
    if (event.key !== "Tab") return
    event.preventDefault()

    const area = this.element
    const [ start, end ] = [ area.selectionStart, area.selectionEnd ]
    const before = area.value.slice(0, start)
    const lineStart = before.lastIndexOf("\n") + 1

    if (event.shiftKey) {
      const line = area.value.slice(lineStart, start)
      const removed = Math.min(this.stepValue, line.length - line.trimStart().length)
      area.setRangeText("", lineStart, lineStart + removed, "end")
      area.setSelectionRange(Math.max(lineStart, start - removed), Math.max(lineStart, end - removed))
    } else {
      area.setRangeText(" ".repeat(this.stepValue), start, end, "end")
    }

    area.dispatchEvent(new Event("input", { bubbles: true }))
  }
}
