var I18n = {
  locale: null,
  translations: null,
  init(locale, translations) {
    this.locale = locale;
    this.translations = translations;
    if (typeof this.translations === "string") {
      this.translations = JSON.parse(this.translations);
    }
  },
  t(key) {
    var humanize;
    humanize = key.charAt(0).toUpperCase() + key.replace(/_/g, " ").slice(1);
    // Stimulus controllers can connect before dom-ready.js calls I18n.init, so
    // tolerate translations not being loaded yet (fall back to the humanized key).
    return (this.translations && this.translations[key]) || humanize;
  },
};

export { I18n as default };
