import "rails_admin/base";
import "trix";
import "@rails/actiontext";
import * as ActiveStorage from "@rails/activestorage";
ActiveStorage.start();

window.domReadyTriggered = [];

document.addEventListener("rails_admin.dom_ready", function () {
  window.domReadyTriggered.push("plainjs/dot");
});
