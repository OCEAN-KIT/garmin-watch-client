using Toybox.WatchUi as UI;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang;

class DeviceInfoView extends UI.View {

    var strTitle;
    var pairingCode = "ERROR"; 

    function initialize() {
        View.initialize();
        strTitle = UI.loadResource(Rez.Strings.InfoTitle); 
        
        var settings = Sys.getDeviceSettings();
        if (settings has :uniqueIdentifier && settings.uniqueIdentifier != null) {
            pairingCode = generatePairingCode(settings.uniqueIdentifier);
        }
    }

    function generatePairingCode(deviceId) {
        var salt = "OCDIVER"; 
        var input = deviceId + salt;
        
        // FNV-1a Hash
        var hash = 0x811c9dc5; 
        var prime = 0x01000193;

        var bytes = input.toUtf8Array();
        for (var i = 0; i < bytes.size(); i++) {
            hash = hash ^ bytes[i];
            hash = hash * prime;
        }

        var alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"; 
        var code = "";
        
        if (hash < 0) { hash = ~hash; }

        for (var i = 0; i < 6; i++) {
            var idx = hash % alphabet.length();
            code = code + alphabet.substring(idx, idx + 1);
            hash = hash / alphabet.length();
        }
        
        return code;
    }

    function onUpdate(dc) {
        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
        dc.clear();
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);

        var width = dc.getWidth();
        var height = dc.getHeight();
        var cx = width / 2;
        var cy = height / 2;
        
        // [수정] G1, G2 공용 최적화 레이아웃
        // "Enter in App" 삭제하고, 두 줄을 화면 중앙에 타이트하게 배치
        
        // 1. 안내 문구 (중앙보다 살짝 위: -25px)
        dc.drawText(cx, cy - 25, Gfx.FONT_SMALL, "PAIRING CODE", Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);

        // 2. 페어링 코드 (중앙보다 살짝 아래: +15px)
        // FONT_LARGE를 유지하여 시인성 확보
        dc.drawText(cx, cy + 15, Gfx.FONT_LARGE, pairingCode, Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
    }
}

class DeviceInfoDelegate extends UI.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }
    
    function onBack() {
        UI.popView(UI.SLIDE_RIGHT);
        return true;
    }
}