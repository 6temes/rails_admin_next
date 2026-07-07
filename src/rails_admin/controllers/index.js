import { application } from "rails_admin/application";

import AlertController from "rails_admin/controllers/alert_controller";
import CollapseController from "rails_admin/controllers/collapse_controller";
import DropdownController from "rails_admin/controllers/dropdown_controller";
import FeedbackController from "rails_admin/controllers/feedback_controller";
import FilterBoxController from "rails_admin/controllers/filter_box_controller";
import FilteringMultiselectController from "rails_admin/controllers/filtering_multiselect_controller";
import FilteringSelectController from "rails_admin/controllers/filtering_select_controller";
import ModalController from "rails_admin/controllers/modal_controller";
import NestedFormController from "rails_admin/controllers/nested_form_controller";
import PolymorphicController from "rails_admin/controllers/polymorphic_controller";
import RemoteFormController from "rails_admin/controllers/remote_form_controller";
import SidescrollController from "rails_admin/controllers/sidescroll_controller";

// Explicit manifest (one import + register per controller). Preferred over
// stimulus-loading's eager/lazy autoloading because the engine ships a small,
// known set of controllers and must stay self-contained — it can't scan the
// host's controllers/ path under importmap+Propshaft.
application.register("alert", AlertController);
application.register("collapse", CollapseController);
application.register("dropdown", DropdownController);
application.register("feedback", FeedbackController);
application.register("filter-box", FilterBoxController);
application.register("filtering-multiselect", FilteringMultiselectController);
application.register("filtering-select", FilteringSelectController);
application.register("modal", ModalController);
application.register("nested-form", NestedFormController);
application.register("polymorphic", PolymorphicController);
application.register("remote-form", RemoteFormController);
application.register("sidescroll", SidescrollController);
