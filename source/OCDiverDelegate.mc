using Toybox.WatchUi as UI;
using Toybox.System as Sys;
using Toybox.Attention as Attn;
using Toybox.Application as App;
using Toybox.Lang;
using Toybox.Timer; 

class OCDiverDelegate extends UI.BehaviorDelegate {

    var view;
    var statusList = [];
    var sidx = 0;
    // saveTimer는 OCDiverView의 스플래시 로직으로 대체되어 삭제됨

    function initialize(v) {
        UI.BehaviorDelegate.initialize();
        view = v;
        
        statusList = [
            UI.loadResource(Rez.Strings.StatusNew),
            UI.loadResource(Rez.Strings.StatusGood),
            UI.loadResource(Rez.Strings.StatusFair),
            UI.loadResource(Rez.Strings.StatusPoor),
            UI.loadResource(Rez.Strings.StatusDead),
            UI.loadResource(Rez.Strings.StatusLost)
        ];
    }

    function onSelect() {
        if (!gDataManager.isSessionStarted) { 
            showMainMenu();
            return true; 
        }
        showStopMenu(); 
        return true;
    }

    function onBack() {
        if (!gDataManager.isSessionStarted) { 
            if (view.gpsManager != null) { view.gpsManager.stop(); }
            return false; 
        } 
        // 활동별 기록
        if (gDataManager.workType == 0) { recordUrchin(); } 
        else if (gDataManager.workType == 1) { recordSeaweed(); }
        else if (gDataManager.workType == 2) { recordOther(); }
        return true; 
    }

    function onNextPage() {
        if (gDataManager.isSessionStarted && gDataManager.workType == 1) { cycleStatus(1); return true; }
        return false;
    }

    function onPreviousPage() {
        if (gDataManager.isSessionStarted) {
            if (gDataManager.workType == 0) { gDataManager.decrementTotalCount(); }
            else if (gDataManager.workType == 1) { cycleStatus(-1); }
            return true;
        }
        return false;
    }

    function onMenu() { 
        if (!gDataManager.isSessionStarted) { showMainMenu(); } 
        else { showInDiveMenu(); }
        return true; 
    }

    function showMainMenu() {
        var menu = new UI.Menu2({:title=>"Ocean Campus"});
        menu.addItem(new UI.MenuItem("Start Diving", "Select Activity", :start_dive, null));
        menu.addItem(new UI.MenuItem("End Diving", "Upload All Logs", :end_dive, null));
        
        // [New] 기기 정보 메뉴 추가
        menu.addItem(new UI.MenuItem(UI.loadResource(Rez.Strings.MenuInfo), "Check ID", :dev_info, null));
        
        UI.pushView(menu, new MainMenuDelegate(self), UI.SLIDE_UP);
    }
    
    function recordUrchin() {
        gDataManager.addUrchinEvent();
        UI.requestUpdate();
        _buzz([30]);
    }

    function recordSeaweed() {
        if (!gDataManager.isIdSet) {
            var picker = new IdPicker();
            UI.pushView(picker, new InDiveIdPickerDelegate(self), UI.SLIDE_LEFT);
        } else {
            gDataManager.addSeaweedEvent(gDataManager.defaultStatus);
            UI.requestUpdate();
            _buzz([30]);
        }
    }

    function recordOther() {
        gDataManager.addOtherEvent();
        var msg = UI.loadResource(Rez.Strings.MsgPointSaved);
        view.triggerFlashMessage(msg);
        _buzz([50]); 
    }
    
    function onIdConfigured() { recordSeaweed(); }

    function cycleStatus(d) {
        sidx += d;
        if (sidx >= statusList.size()) { sidx = 0; }
        if (sidx < 0) { sidx = statusList.size()-1; }
        gDataManager.defaultStatus = statusList[sidx];
        UI.requestUpdate();
    }

    function showStopMenu() {
        var title = UI.loadResource(Rez.Strings.MenuPaused);
        var menu = new UI.Menu2({:title=>title});
        menu.addItem(new UI.MenuItem("Resume", null, :resume, null));
        menu.addItem(new UI.MenuItem("Save & New", "Queue & Reset", :save, null));
        menu.addItem(new UI.MenuItem("Discard", null, :discard, null));
        
        if (view.gpsManager != null) { view.gpsManager.startSearch(); }
        UI.pushView(menu, new StopMenuDelegate(self), UI.SLIDE_UP);
    }

    function showInDiveMenu() {
        var menu = new UI.Menu2({:title=>"Edit Mode"});
        if (gDataManager.workType == 0) {
            menu.addItem(new UI.MenuItem("Count -1", null, :dec_count, null));
        } else if (gDataManager.workType == 1) {
            menu.addItem(new UI.MenuItem("Jump ID +10", null, :jump_id, null));
        }
        menu.addItem(new UI.MenuItem("Change Grid", null, :chg_grid, null));
        UI.pushView(menu, new InDiveMenuDelegate(self), UI.SLIDE_UP);
    }

    function triggerStop() {
        gDataManager.isSessionStarted = false; 
        view.setSessionActive(false);
        if (view.gpsManager != null) { view.gpsManager.stop(); }
        UI.requestUpdate();
    }

    function _buzz(arr) {
        if (Attn has :vibrate) {
            var seq = [];
            for(var i=0; i<arr.size(); i++) {
                var d = arr[i];
                seq.add(new Attn.VibeProfile(100, d)); 
            }
            Attn.vibrate(seq);
        }
    }
}

// --- Delegates ---

class MainMenuDelegate extends UI.Menu2InputDelegate {
    var parent; 
    function initialize(p) { Menu2InputDelegate.initialize(); parent = p; }
    
    function onSelect(item) {
        var id = item.getId();
        if (id == :start_dive) {
            var app = App.getApp();
            if (app.mView != null) { app.mView.startGpsSearch(); }
            showActivitySelectMenu();
        } else if (id == :end_dive) {
            var app = App.getApp();
            if (app.mView != null) { app.mView.isEndingSequence = true; }
            UI.popView(UI.SLIDE_IMMEDIATE);
            if (app instanceof OCDiverApp) { app.handleEndDiving(); }
        } else if (id == :dev_info) {
            // [New] 기기 정보 화면으로 이동
            UI.pushView(new DeviceInfoView(), new DeviceInfoDelegate(), UI.SLIDE_LEFT);
        }
    }
    
    function onBack() {
        UI.popView(UI.SLIDE_IMMEDIATE);
        UI.popView(UI.SLIDE_IMMEDIATE);
    }
    
    function showActivitySelectMenu() {
        var menu = new UI.Menu2({:title=>"Select Activity"});
        menu.addItem(new UI.MenuItem(UI.loadResource(Rez.Strings.MenuUrchin), null, :urchin, null));
        menu.addItem(new UI.MenuItem(UI.loadResource(Rez.Strings.MenuSeaweed), null, :seaweed, null));
        menu.addItem(new UI.MenuItem(UI.loadResource(Rez.Strings.MenuOther), null, :other, null));
        UI.switchToView(menu, new ActivitySelectDelegate(), UI.SLIDE_LEFT);
    }
}

class StopMenuDelegate extends UI.Menu2InputDelegate {
    var parent;
    function initialize(p) { UI.Menu2InputDelegate.initialize(); parent = p; }
    function onSelect(item) {
        var id = item.getId();
        if (id == :resume) { 
            UI.popView(UI.SLIDE_DOWN);
        } else if (id == :save) {
            var app = App.getApp();
            if (app instanceof OCDiverApp) { (app as OCDiverApp).stopAndSave(); }
            parent.triggerStop(); 
            UI.popView(UI.SLIDE_IMMEDIATE); 
            // View onShow handles splash
        } else if (id == :discard) { 
            parent.triggerStop(); 
            UI.popView(UI.SLIDE_DOWN);
        }
    }
}

class ActivitySelectDelegate extends UI.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item) {
        var id = item.getId();
        if (id == :urchin) {
            gDataManager.workType = 0;
            openPicker();
        } else if (id == :seaweed) {
            gDataManager.workType = 1;
            openPicker();
        } else if (id == :other) {
            gDataManager.workType = 2;
            openPicker();
        }
    }
    
    function onBack() {
        var app = App.getApp();
        var menu = new UI.Menu2({:title=>"Ocean Campus"});
        menu.addItem(new UI.MenuItem("Start Diving", "Select Activity", :start_dive, null));
        menu.addItem(new UI.MenuItem("End Diving", "Upload All Logs", :end_dive, null));
        menu.addItem(new UI.MenuItem(UI.loadResource(Rez.Strings.MenuInfo), "Check ID", :dev_info, null)); // Back 시에도 메뉴 구성 동일하게
        
        var delegate = new MainMenuDelegate(new OCDiverDelegate(app.mView));
        UI.switchToView(menu, delegate, UI.SLIDE_RIGHT);
    }

    function openPicker() {
        var picker = new GridPicker();
        UI.switchToView(picker, new GridPickerDelegate(), UI.SLIDE_LEFT);
    }
}

class InDiveMenuDelegate extends UI.Menu2InputDelegate {
    var parent;
    function initialize(p) { Menu2InputDelegate.initialize(); parent = p; }
    function onSelect(item) {
        var id = item.getId();
        if (id == :dec_count) { gDataManager.decrementTotalCount(); } 
        else if (id == :jump_id) { gDataManager.currentId += 10; } 
        else if (id == :chg_grid) {
            var picker = new GridPicker();
            UI.pushView(picker, new GridPickerDelegate(), UI.SLIDE_LEFT);
            return; 
        }
        UI.popView(UI.SLIDE_DOWN);
        UI.requestUpdate();
    }
}

class StartConfMenuDelegate extends UI.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item) {
        var id = item.getId();
        if (id == :start_final) {
            if (gDataManager.workType == 1) { openSetupIdPicker(); } 
            else { startSessionNow(); }
        } else if (id == :back_setup) {
            var picker = new GridPicker();
            UI.switchToView(picker, new GridPickerDelegate(), UI.SLIDE_RIGHT);
        }
    }
    function openSetupIdPicker() {
        var picker = new IdPicker();
        UI.switchToView(picker, new SetupIdPickerDelegate(), UI.SLIDE_LEFT);
    }
    function startSessionNow() {
        var app = App.getApp();
        app.startDiveFlowAfterSetup(); 
        UI.popView(UI.SLIDE_IMMEDIATE);
    }
}