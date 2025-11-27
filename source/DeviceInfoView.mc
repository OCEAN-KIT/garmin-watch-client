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
            // Device ID를 기반으로 페어링 코드 생성
            pairingCode = generatePairingCode(settings.uniqueIdentifier);
        }
    }

    // [Core Logic] 해싱 + 인코딩 알고리즘
    // Server(Java)에서도 동일한 로직으로 구현해야 매칭 가능
    function generatePairingCode(deviceId) {
        var salt = "OCDIVER"; // 보안을 위한 소금
        var input = deviceId + salt;
        
        // 1. FNV-1a Hash (32-bit) 구현
        // Monkey C는 32-bit Signed Integer를 사용하므로 오버플로우는 자연스럽게 처리됨
        var hash = 0x811c9dc5; // FNV offset basis
        var prime = 0x01000193; // FNV prime

        var bytes = input.toUtf8Array(); // 문자열을 바이트 배열로 변환
        
        for (var i = 0; i < bytes.size(); i++) {
            hash = hash ^ bytes[i];
            hash = hash * prime;
        }

        // 2. 읽기 쉬운 문자열로 변환 (Base31 - I, O, U, L 등 헷갈리는 문자 제외)
        // 0123456789 ABCDEFGH JK MN PQR ST VWXYZ (31개)
        var alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"; 
        var code = "";
        
        // 해시값을 양수로 보정
        if (hash < 0) { hash = ~hash; }

        // 6자리 코드 생성
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
        
        // 1. 안내 문구
        dc.drawText(cx, cy - 40, Gfx.FONT_TINY, "PAIRING CODE", Gfx.TEXT_JUSTIFY_CENTER);

        // 2. 페어링 코드 (중앙, 아주 크게)
        // 예: "K9J2XM"
        dc.drawText(cx, cy, Gfx.FONT_NUMBER_HOT, pairingCode, Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        
        // 3. 부가 설명
        dc.drawText(cx, cy + 40, Gfx.FONT_XTINY, "Enter in App", Gfx.TEXT_JUSTIFY_CENTER);
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