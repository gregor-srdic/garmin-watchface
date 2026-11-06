using Toybox.Application;
using Toybox.WatchUi;

class ArchesWatchFaceApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
    }

    function onStop(state) {
    }

    function getInitialView() {
        var view = new ArchesWatchFaceView();
        return [ view, new ArchesWatchFaceDelegate(view) ];
    }
}
