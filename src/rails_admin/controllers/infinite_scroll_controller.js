import { Controller } from "@hotwired/stimulus";

// Lives on a pending next-batch <turbo-frame loading="lazy">. Turbo does the
// loading; this controller starts it one viewport before the frame scrolls
// into view, and turns a failed load into an error with a Retry link.
//
// State stays in attributes (Turbo's `busy`, `data-load-error`) and the
// strings arrive as values, because a restored page snapshot keeps attributes
// but not JS fields, and Stimulus connects before I18n is initialised.
export default class extends Controller {
  static targets = ["error", "link"];
  static values = { error: String, retryLabel: String };

  #observer;
  #requested = false;

  connect() {
    if (this.element.loading === "eager") return;
    this.#observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) this.#loadNow();
      },
      { rootMargin: `0px 0px ${window.innerHeight}px 0px` }
    );
    this.#observer.observe(this.element);
  }

  disconnect() {
    this.#observer?.disconnect();
  }

  // Turbo's own lazy loading may already have started the request (a frame
  // inside the viewport); switching to eager then would cancel and repeat it.
  started() {
    this.#requested = true;
    this.#observer?.disconnect();
  }

  failed() {
    this.#showError();
  }

  // A response without this frame (a server error page) would otherwise
  // replace the frame with "Content missing" and throw.
  missing(event) {
    event.preventDefault();
    this.#showError();
  }

  // Following the link would dispatch turbo:click, which shows the global
  // loading badge that only a full page render hides. Turbo stops observing a
  // frame once a load has been attempted, so after a failure only reload()
  // fetches it again.
  load(event) {
    event.preventDefault();
    if (!("loadError" in this.element.dataset)) return this.#loadNow();

    delete this.element.dataset.loadError;
    this.errorTarget.textContent = "";
    this.element.reload();
  }

  #loadNow() {
    this.#observer?.disconnect();
    if (this.#requested) return;
    this.element.loading = "eager";
  }

  #showError() {
    this.element.dataset.loadError = "";
    this.errorTarget.textContent = this.errorValue;
    this.linkTarget.textContent = this.retryLabelValue;
  }
}
