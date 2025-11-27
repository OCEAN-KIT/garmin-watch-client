using Toybox.Application as App;
using Toybox.WatchUi as UI;
using Toybox.System as Sys;
using Toybox.ActivityRecording as AR;
using Toybox.Graphics as Gfx;
using Toybox.Timer; 
using Toybox.Application.Storage as Storage; 

var gDataManager;
var gNetworkManager;

class OCDiverApp extends App.AppBase {

    var session = null;
    var mView; 
    var mDelegate; 

    var _flowTimer; 

    function initialize() { AppBase.initialize(); }

    function onStart(state) {
        // [테스트용] 배포 시 삭제 필요: 기존 데이터 강제 초기화
        Storage.clearValues(); 
        
        gDataManager = new DataManager();
        gNetworkManager = new NetworkManager(); 
    }

    function onStop(state) {
        if (session != null && session.isRecording()) {
            session.stop();
            session.save();
        }
    }

    function getInitialView() {
        mView = new OCDiverView();
        mDelegate = new OCDiverDelegate(mView);
        return [mView, mDelegate];
    }

    // =========================================================
    // Flow Control Methods
    // =========================================================

    function startDiveFlowAfterSetup() {
        startDiveSession(); 
        gDataManager.isSessionStarted = true;
        gDataManager.isReadyToStart = true;
        
        if (mView != null) {
            mView.setSessionActive(true);
            if (mView.gpsManager != null) { mView.gpsManager.startSearch(); }
        }
    }

    function startDiveSession() {
        Sys.println("--- Starting Activity Session ---");
        
        if (session != null) { 
            if (session.isRecording()) {
                session.stop();
                session.save();
            }
            session = null; 
        }
        
        if (mView != null) { mView.clearUploadMessage(); }

        if ((Toybox has :ActivityRecording) && (AR has :createSession)) {
            session = AR.createSession({
                :name => "Ocean Keeper",
                :sport => AR.SPORT_GENERIC,
                :subSport => AR.SUB_SPORT_GENERIC
            });
            gDataManager.setupFitFields(session);
            session.start();
            Sys.println("FIT Recording Started.");
        }
    }

    // [Modified] 저장 후 1.5초 뒤 자동 넘김 로직 추가
    function stopAndSave() {
        gDataManager.writeFinalFitFields();
        
        if (session != null && session.isRecording()) {
            session.stop();
            session.save(); 
            session = null;
        }
        
        gDataManager.accumulateCurrentActivity();
        
        if (mView != null) {
            var count = gDataManager.sessionActivities.size();
            mView.setUploadMessage("Saved Locally (" + count + ")", Gfx.COLOR_WHITE);
        }
        
        // [New] 1.5초 뒤에 메인 메뉴로 이동
        if (_flowTimer == null) { _flowTimer = new Timer.Timer(); }
        _flowTimer.start(method(:onLocalSaveFinished), 1500, false);
    }
    
    // [New] 로컬 저장 완료 후 호출되는 콜백
    function onLocalSaveFinished() as Void {
        _flowTimer = null;
        if (mView != null) { mView.clearUploadMessage(); }
        if (mDelegate != null) { mDelegate.showMainMenu(); }
    }

    function handleEndDiving() {
        if (!gDataManager.hasActivitiesToSend() && !gNetworkManager.hasOfflineItems()) {
            if (mView != null) { 
                mView.setUploadMessage("No Data Found", Gfx.COLOR_WHITE); 
            }
            _flowTimer = new Timer.Timer();
            _flowTimer.start(method(:onFinishFlow), 2000, false);
            return;
        }

        if (mView != null) {
            mView.startEndFlow(); 
        }
    }
    
    function uploadSession() {
        if (!gDataManager.hasActivitiesToSend()) {
            gNetworkManager.syncOffline(method(:onUploadResult));
            if (mView != null) { mView.setUploadMessage("Syncing Queue...", Gfx.COLOR_WHITE); }
            return;
        }

        var payload = gDataManager.getFinalSessionPayload();
        
        if (mView != null) { mView.setUploadMessage("Uploading All...", Gfx.COLOR_WHITE); }

        gNetworkManager.uploadData(payload, method(:onUploadResult));
    }

    function onUploadResult(ok, code, data) {
        if (mView != null) {
            if (ok) { 
                if (code == 0) {
                     mView.setUploadMessage("All Synced", Gfx.COLOR_WHITE);
                } else {
                     mView.setUploadMessage("Upload Success!", Gfx.COLOR_WHITE);
                }
                gDataManager.clearAllSession();
            } else { 
                mView.setUploadMessage("Fail: Queued (" + code + ")", Gfx.COLOR_WHITE); 
                gDataManager.clearAllSession();
            }
            
            _flowTimer = new Timer.Timer();
            _flowTimer.start(method(:onFinishFlow), 2500, false);
        }
    }

    function onFinishFlow() as Void {
        _flowTimer = null;
        if (mView != null) {
            mView.clearUploadMessage(); 
        }
        startSplashSequence();
    }

    function startSplashSequence() {
        if (_flowTimer == null) {
            _flowTimer = new Timer.Timer();
            _flowTimer.start(method(:onSplashTimer), 1500, false);
        }
    }

    function onSplashTimer() as Void {
        _flowTimer = null;
        if (mDelegate != null) {
            mDelegate.showMainMenu();
        }
    }
}