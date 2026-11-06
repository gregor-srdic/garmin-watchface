using Toybox.Complications;
using Toybox.Lang;
using Toybox.WatchUi;

// Touch-and-hold on an arc opens that metric's native Garmin screen.
//
// onPress is the touch-and-hold hook (API 4.2.0); onTap only fires in
// config mode, so it is deliberately not implemented. Returning false lets
// the system's own hold action (watch-face menu) happen.
class ArchesWatchFaceDelegate extends WatchUi.WatchFaceDelegate {

    private var _view as ArchesWatchFaceView;

    function initialize(view as ArchesWatchFaceView) {
        WatchFaceDelegate.initialize();
        _view = view;
    }

    function onPress(evt as WatchUi.ClickEvent) as Lang.Boolean {
        try {
            if (!(Toybox has :Complications)) {
                return false;
            }
            if (_view.isLowPower()) {
                return false;
            }
            var xy = evt.getCoordinates();
            var slot = _view.slotAtPoint(xy[0], xy[1]);
            if (slot == null) {
                return false;
            }
            var id = _view.compIdForSlot(slot);
            if (id == null || ArchesLogic.safeGetComplication(id) == null) {
                return false;
            }
            Complications.exitTo(id);
            return true;
        } catch (e) {
            return false;
        }
    }
}
