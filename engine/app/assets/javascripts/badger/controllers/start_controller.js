import { Controller } from "@hotwired/stimulus"

// The start of a badge: a composition on a shape. Choosing a composition
// brings its own shape with it; choosing a shape keeps the composition. The
// button says what the two add up to, the name field offers the
// composition's name, and the path field shows only when the shape is one.
export default class extends Controller {
  static targets = ["name", "submit", "path"]

  connect() {
    this.choose()
  }

  choose(event) {
    const composition = this.element.querySelector("input[name='badge[composition]']:checked")
    if (event?.target.name === "badge[composition]") {
      const own = this.element.querySelector(`input[name='badge[shape]'][value='${composition.dataset.shape}']`)
      if (own) own.checked = true
    }
    const shape = this.element.querySelector("input[name='badge[shape]']:checked")
    if (this.hasPathTarget) this.pathTarget.hidden = shape?.value !== "path"
    if (this.hasNameTarget && composition) this.nameTarget.placeholder = composition.dataset.name
    if (this.hasSubmitTarget && composition && shape) {
      this.submitTarget.textContent = `Compose ${this.article(composition.dataset.name)} on ${this.article(shape.dataset.label)}`
    }
  }

  article(word) {
    const lower = word.toLowerCase()
    return `${/^[aeiou]/.test(lower) ? "an" : "a"} ${lower}`
  }
}
