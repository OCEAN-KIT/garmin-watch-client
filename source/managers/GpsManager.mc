using Toybox.Position as Pos;
using Toybox.System as Sys;
using Toybox.Timer;
using Toybox.WatchUi as UI;
using Toybox.Lang; 

class GpsManager {

    var timeoutTimer;
    var timeoutSec = 20;
    var locked = false;
    var callbackMethod;
    var msgWait, msgReady, msgFail;

    function initialize(cbMethod) {
        callbackMethod = cbMethod;
        timeoutTimer = new Timer.Timer();
        msgWait  = UI.loadResource(Rez.Strings.GpsWaiting);
        msgReady = UI.loadResource(Rez.Strings.GpsReady);
        msgFail  = UI.loadResource(Rez.Strings.GpsFail);
    }

    function startSearch() {
        locked = false;
        _notify(msgWait, false, null);
        Pos.enableLocationEvents(Pos.LOCATION_ONE_SHOT, method(:onPosition));
        timeoutTimer.start(method(:onTimeout), timeoutSec * 1000, false);
    }

    function onPosition(info as Pos.Info) as Void {
        if (info != null && info.position != null) {
            var q = info.accuracy;
            if (q == Pos.QUALITY_GOOD || q == Pos.QUALITY_USABLE) {
                locked = true;
                timeoutTimer.stop();
                _notify(msgReady, true, info);
                Pos.enableLocationEvents(Pos.LOCATION_DISABLE, null);
                return;
            }
        }
    }

    function onTimeout() as Void {
        if (!locked) {
            Pos.enableLocationEvents(Pos.LOCATION_DISABLE, null);
            _notify(msgFail, false, null);
        }
    }

    function stop() {
        if (timeoutTimer != null) { timeoutTimer.stop(); }
        Pos.enableLocationEvents(Pos.LOCATION_DISABLE, null);
    }

    function _notify(msg, ready, info) {
        if (callbackMethod != null) { 
            callbackMethod.invoke(msg, ready, info);
        }
    }
}