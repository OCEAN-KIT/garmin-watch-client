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
                :name => "Ocean Campus",
                :sport => AR.SPORT_GENERIC,
                :subSport => AR.SUB_SPORT_GENERIC
            });
            gDataManager.setupFitFields(session);
            session.start();
            Sys.println("FIT Recording Started.");
        }
    }

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
    }

    // [New] End Diving 진입점: 데이터 체크 먼저 수행
    function handleEndDiving() {
        // 1. 데이터가 하나도 없으면 GPS 잡을 필요 없이 바로 종료
        if (!gDataManager.hasActivitiesToSend() && !gNetworkManager.hasOfflineItems()) {
            if (mView != null) { 
                mView.setUploadMessage("No Data Found", Gfx.COLOR_WHITE); 
            }
            _flowTimer = new Timer.Timer();
            _flowTimer.start(method(:onFinishFlow), 2000, false);
            return;
        }

        // 2. 데이터가 있다면 GPS 탐색 흐름 시작
        if (mView != null) {
            mView.startEndFlow(); 
        }
    }
    
    // GPS 탐색 종료 후 호출되는 실제 업로드 함수
    function uploadSession() {
        // handleEndDiving에서 이미 데이터 유무를 체크했으므로 바로 전송 로직 수행

        // 1. 오프라인 큐 우선 처리
        if (!gDataManager.hasActivitiesToSend()) {
            gNetworkManager.syncOffline(method(:onUploadResult));
            if (mView != null) { 
                mView.setUploadMessage("Syncing Queue...", Gfx.COLOR_WHITE); 
            }
            return;
        }

        // 2. 현재 세션 데이터 업로드
        var payload = gDataManager.getFinalSessionPayload();
        
        if (mView != null) { 
            mView.setUploadMessage("Uploading All...", Gfx.COLOR_WHITE); 
        }

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