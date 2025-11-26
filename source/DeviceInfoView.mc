using Toybox.WatchUi as UI;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang;

class DeviceInfoView extends UI.View {

    var deviceId = "Unknown";
    var strTitle;

    function initialize() {
        View.initialize();
        strTitle = UI.loadResource(Rez.Strings.InfoTitle);
        
        var settings = Sys.getDeviceSettings();
        if (settings has :uniqueIdentifier && settings.uniqueIdentifier != null) {
            deviceId = settings.uniqueIdentifier;
        }
        
        // [테스트용] ID가 짧아서 테스트가 안될 경우를 대비해 긴 문자열로 테스트하려면 아래 주석 해제
        // deviceId = "3b241101e6f24b9e97b126f5551cd633"; 
    }

    function onUpdate(dc) {
        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
        dc.clear();
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);

        var width = dc.getWidth();
        var height = dc.getHeight();
        var cx = width / 2;
        
        // 1. 제목 표시 (상단) 
        dc.drawText(cx, 30, Gfx.FONT_TINY, strTitle, Gfx.TEXT_JUSTIFY_CENTER);

        // 2. 긴 ID 줄바꿈 처리 로직
        var font = Gfx.FONT_XTINY;
        var fontHeight = dc.getFontHeight(font);
        var maxWidth = width * 0.75; // 화면 너비의 75%만 사용 (원형 화면 잘림 방지)
        var lines = [];
        
        var currentLine = "";
        var len = deviceId.length();
        
        // 한 글자씩 붙여가며 너비 체크
        for (var i = 0; i < len; i++) {
            var char = deviceId.substring(i, i+1);
            var testLine = currentLine + char;
            
            if (dc.getTextWidthInPixels(testLine, font) > maxWidth) {
                // 너비 초과 시 현재 라인 저장하고 다음 줄로
                lines.add(currentLine);
                currentLine = char;
            } else {
                currentLine = testLine;
            }
        }
        // 마지막 남은 줄 추가
        if (currentLine.length() > 0) {
            lines.add(currentLine);
        }

        // 3. 수직 중앙 정렬을 위한 시작 Y 좌표 계산 
        var totalTextHeight = lines.size() * fontHeight;
        var startY = (height / 2) - (totalTextHeight / 2) + 15; // 제목 공간 고려해 살짝 아래로(+15)

        // 4. 줄바꿈된 텍스트 그리기
        for (var i = 0; i < lines.size(); i++) {
            dc.drawText(cx, startY + (i * fontHeight), font, lines[i], Gfx.TEXT_JUSTIFY_CENTER);
        }
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