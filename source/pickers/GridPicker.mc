using Toybox.WatchUi as UI;
using Toybox.Graphics as Gfx;
using Toybox.Lang;
using Toybox.Application as App;
using Toybox.System as Sys;

class GridPickerFactory extends UI.PickerFactory {
    var _type; 
    var _alpha = ["A","B","C","D","E","F","G","H","I","J","K","L","M", "N","O","P","Q","R","S","T","U","V","W","X","Y","Z"];
    var _number = ["1","2","3","4","5","6","7","8","9"];
    function initialize(type) { PickerFactory.initialize(); _type = type; }
    function getSize() { return (_type == 0) ? _alpha.size() : _number.size(); }
    function getValue(index) { return (_type == 0) ? _alpha[index] : _number[index]; }
    function getDrawable(index, selected) {
        return new UI.Text({:text => getValue(index) as Lang.String, :color => Gfx.COLOR_WHITE, :font => Gfx.FONT_LARGE, :locX => UI.LAYOUT_HALIGN_CENTER, :locY => UI.LAYOUT_VALIGN_CENTER});
    }
}

class GridPicker extends UI.Picker {
    function initialize() {
        var title = new UI.Text({:text => "Select Grid", :locX => UI.LAYOUT_HALIGN_CENTER, :locY => UI.LAYOUT_VALIGN_BOTTOM, :color => Gfx.COLOR_WHITE});
        var factories = [new GridPickerFactory(0), new GridPickerFactory(1)];
        Picker.initialize({ :title => title, :pattern => factories, :defaults => [0, 0] });
    }
    function onUpdate(dc) { dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK); dc.clear(); Picker.onUpdate(dc); }
}

class GridPickerDelegate extends UI.PickerDelegate {
    function initialize() { PickerDelegate.initialize(); }
    
    function onCancel() { 
        var app = App.getApp();
        // 다이빙 중이면 그냥 닫기
        if (app instanceof OCDiverApp && app.mView != null && app.mView.active) {
             UI.popView(UI.SLIDE_IMMEDIATE);
             return true;
        }

        // [Fix] 뒤로가기 시 재생성되는 메뉴에도 'Other' 항목 추가
        var menu = new UI.Menu2({:title=>"Select Activity"});
        menu.addItem(new UI.MenuItem(UI.loadResource(Rez.Strings.MenuUrchin), null, :urchin, null));
        menu.addItem(new UI.MenuItem(UI.loadResource(Rez.Strings.MenuSeaweed), null, :seaweed, null));
        menu.addItem(new UI.MenuItem(UI.loadResource(Rez.Strings.MenuOther), null, :other, null)); // <-- 이 줄 추가됨
        
        // 뒤로 갈 때도 switch
        UI.switchToView(menu, new ActivitySelectDelegate(), UI.SLIDE_RIGHT);
        return true; 
    }

    function onAccept(values) {
        var gridStr = (values[0] as Lang.String) + "-" + (values[1] as Lang.String);
        gDataManager.gridId = gridStr;
        
        // 다이빙 중 변경 처리
        var app = App.getApp();
        if (app instanceof OCDiverApp && app.mView != null && app.mView.active) {
            Sys.println(">> Grid Changed during dive.");
            UI.popView(UI.SLIDE_IMMEDIATE);
            UI.requestUpdate(); 
            return true; 
        }

        openStartConfMenu();
        return true;
    }

    function openStartConfMenu() {
        var menu = new UI.Menu2({:title=>"Ready?"});
        menu.addItem(new UI.MenuItem("START DIVE", "Go to GPS", :start_final, null));
        menu.addItem(new UI.MenuItem("BACK", "Setup", :back_setup, null));
        
        // push가 아닌 switch를 써야 이전 Picker가 사라짐
        UI.switchToView(menu, new StartConfMenuDelegate(), UI.SLIDE_LEFT);
    }
}