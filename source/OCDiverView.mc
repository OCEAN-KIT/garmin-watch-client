using Toybox.WatchUi as UI;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang;
using Toybox.Sensor; 
using Toybox.Application as App; 
using Toybox.Timer; 

class OCDiverView extends UI.View {

    var gpsManager;
    var active = false;
    
    var isEndingSequence = false;

    var strGridPrefix, strRecording, strResetInfo;
    var strOrg1, strOrg2; 
    var strGpsFail; 
    var gpsMsg = "";
    var gpsReady = false;

    var uploadMsg = null;
    
    // 플래시 메시지 변수
    var flashMsg = null;
    var flashTimer;

    function initialize() {
        View.initialize();
        
        gpsMsg        = UI.loadResource(Rez.Strings.GpsWaiting);
        strGridPrefix = UI.loadResource(Rez.Strings.MsgGridPrefix);
        strRecording  = UI.loadResource(Rez.Strings.MsgRecording);
        
        strOrg1       = UI.loadResource(Rez.Strings.OrgLine1); // OCEAN
        strOrg2       = UI.loadResource(Rez.Strings.OrgLine2); // CAMPUS
        
        strResetInfo  = UI.loadResource(Rez.Strings.MsgResetInfo);
        strGpsFail    = UI.loadResource(Rez.Strings.GpsFail); 

        gpsManager = new GpsManager(method(:onGpsUpdate));
    }

    // [Fix] 앱 초기 실행 시 스플래시 로직 수행
    // 메시지(Saved Locally 등)가 떠있지 않을 때만 스플래시 실행 (충돌 방지)
    function onShow() {
        if (!active && !isEndingSequence && uploadMsg == null) {
            var app = App.getApp();
            app.startSplashSequence();
        }
    }

    function onHide() { }

    function setUploadMessage(msg, color) {
        uploadMsg = msg;
        UI.requestUpdate();
    }

    function clearUploadMessage() {
        uploadMsg = null;
        UI.requestUpdate();
    }
    
    function triggerFlashMessage(text) {
        flashMsg = text;
        UI.requestUpdate();
        
        if (flashTimer == null) { flashTimer = new Timer.Timer(); }
        flashTimer.start(method(:onFlashTimer), 1000, false);
    }
    
    function onFlashTimer() as Void {
        flashMsg = null;
        UI.requestUpdate();
    }

    function startEndFlow() {
        isEndingSequence = true; 
        setUploadMessage("Preparing Upload...",  Gfx.COLOR_WHITE);
        if (gpsManager != null) {
            gpsManager.startSearch();
        }
    }
    
    function _triggerUpload() {
        isEndingSequence = false; 
        if (gpsManager != null) { gpsManager.stop(); } 
        
        var app = App.getApp();
        if (app instanceof OCDiverApp) {
            app.uploadSession(); 
        }
    }

    function onUpdate(dc) {
        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
        dc.clear();
        
        var cx = dc.getWidth()/2;
        var cy = dc.getHeight()/2;

        if (uploadMsg != null) {
            dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, Gfx.FONT_TINY, uploadMsg, Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
            return; 
        }

        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);

        if (active) {
            var topText = strGridPrefix + gDataManager.gridId;
            if (gDataManager.workType == 1) { 
                topText = "< " + gDataManager.defaultStatus + " >"; 
            }
            dc.drawText(cx, 35, Gfx.FONT_TINY, topText, Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);

            if (flashMsg != null) {
                dc.drawText(cx, cy - 5, Gfx.FONT_MEDIUM, flashMsg, Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
            } else {
                var mainVal = gDataManager.totalCount.toString();
                if (gDataManager.workType == 1) {
                     mainVal = "#" + gDataManager.currentId.toString();
                }
                dc.drawText(cx, cy - 5, Gfx.FONT_NUMBER_HOT, mainVal, Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
            }

            var info = Sensor.getInfo();
            var depth = 0.0;
            if (info has :pressure && info.pressure != null) {
                var p = info.pressure;
                if (p > 100000) { depth = (p - 101325) / 9806.65; }
                if (depth < 0) { depth = 0.0; }
            }
            
            var clock = Sys.getClockTime();
            var timeStr = Lang.format("$1$:$2$", [clock.hour, clock.min.format("%02d")]);
            var infoStr = Lang.format("D: $1$m  T: $2$", [depth.format("%.1f"), timeStr]);
            
            dc.drawText(cx, cy + 40, Gfx.FONT_TINY, infoStr, Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);

        } else {
            // Splash
            dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
            dc.drawText(cx, cy - 25, Gfx.FONT_LARGE, strOrg1, Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
            dc.drawText(cx, cy + 15, Gfx.FONT_LARGE, strOrg2, Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        }
    }

    function onGpsUpdate(msg, ready, info) {
        gpsMsg = msg;
        gpsReady = ready;
        
        if (ready && info != null) { gDataManager.updateLocation(info); }

        if (isEndingSequence) {
            if (ready) { _triggerUpload(); } 
            else if (msg.equals(strGpsFail)) { _triggerUpload(); }
        }
        UI.requestUpdate();
    }

    function setSessionActive(v) { active = v; UI.requestUpdate(); }

    function startGpsSearch() {
        if (gpsManager != null) { gpsManager.startSearch(); }
        UI.requestUpdate();
    }
}