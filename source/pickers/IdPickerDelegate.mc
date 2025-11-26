using Toybox.WatchUi as UI;
using Toybox.System as Sys;
using Toybox.Application as App;
using Toybox.Graphics as Gfx;

class DigitFactory extends UI.PickerFactory {
    function initialize() { PickerFactory.initialize(); }
    function getSize() { return 10; } 
    function getValue(index) { return index; }
    function getDrawable(index, selected) {
        return new UI.Text({:text => index.toString(), :color => Gfx.COLOR_WHITE, :font => Gfx.FONT_NUMBER_HOT, :locX => UI.LAYOUT_HALIGN_CENTER, :locY => UI.LAYOUT_VALIGN_CENTER});
    }
}

class IdPicker extends UI.Picker {
    function initialize() {
        var title = new UI.Text({:text => "Set Start ID", :locX => UI.LAYOUT_HALIGN_CENTER, :locY => UI.LAYOUT_VALIGN_BOTTOM, :color => Gfx.COLOR_WHITE});
        var factories = [new DigitFactory(), new DigitFactory(), new DigitFactory()];
        var cur = gDataManager.currentId;
        if (cur == null) { cur = 100; } if (cur > 999) { cur = 999; } 
        var d1 = (cur / 100).toLong() % 10; var d2 = (cur / 10).toLong() % 10; var d3 = cur.toLong() % 10;
        var defaults = [d1, d2, d3];
        Picker.initialize({:title=>title, :pattern=>factories, :defaults=>defaults});
    }
    function onUpdate(dc) { dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK); dc.clear(); Picker.onUpdate(dc); }
}

// 2. Setup 단계 전용 Delegate
class SetupIdPickerDelegate extends UI.PickerDelegate {
    function initialize() { PickerDelegate.initialize(); }

    function onCancel() {
        UI.popView(UI.SLIDE_IMMEDIATE);
        return true;
    }

    function onAccept(values) {
        var v1 = values[0]; var v2 = values[1]; var v3 = values[2];
        var finalId = (v1 * 100) + (v2 * 10) + v3;
        
        gDataManager.currentId = finalId.toLong(); 
        gDataManager.isIdSet = true;
        Sys.println("Setup Start ID: " + finalId);

        // [Fix] 1. 녹화 상태 먼저 활성화 (BaseView onShow 간섭 방지)
        var app = App.getApp();
        app.startDiveFlowAfterSetup(); 

        // [Fix] 2. 그 다음에 Picker 닫기
        UI.popView(UI.SLIDE_IMMEDIATE);

        return true;
    }
}

// 3. In-Dive 전용 Delegate (수정 없음)
class InDiveIdPickerDelegate extends UI.PickerDelegate {
    var parentDelegate;
    function initialize(d) { PickerDelegate.initialize(); parentDelegate = d; }
    function onCancel() { UI.popView(UI.SLIDE_IMMEDIATE); return true; }
    function onAccept(values) {
        var v1 = values[0]; var v2 = values[1]; var v3 = values[2];
        var finalId = (v1 * 100) + (v2 * 10) + v3;
        gDataManager.currentId = finalId.toLong(); 
        gDataManager.isIdSet = true;
        Sys.println("In-Dive ID Set: " + finalId);
        var menu = new UI.Menu2({:title=>"Status"});
        menu.addItem(new UI.MenuItem(UI.loadResource(Rez.Strings.StatusNew), null, "NEW", null));
        menu.addItem(new UI.MenuItem(UI.loadResource(Rez.Strings.StatusGood), null, "GOOD", null));
        menu.addItem(new UI.MenuItem(UI.loadResource(Rez.Strings.StatusFair), null, "FAIR", null));
        menu.addItem(new UI.MenuItem(UI.loadResource(Rez.Strings.StatusPoor), null, "POOR", null));
        UI.switchToView(menu, new InDiveStatusDelegate(parentDelegate), UI.SLIDE_LEFT);
        return true;
    }
}

class InDiveStatusDelegate extends UI.Menu2InputDelegate {
    var parentDelegate;
    function initialize(d) { UI.Menu2InputDelegate.initialize(); parentDelegate = d; }
    function onSelect(item) {
        var status = item.getId();
        gDataManager.defaultStatus = status;
        UI.popView(UI.SLIDE_IMMEDIATE);
        if (parentDelegate != null) { parentDelegate.onIdConfigured(); }
    }
}