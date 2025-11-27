using Toybox.FitContributor;
using Toybox.System as Sys;
using Toybox.Time;
using Toybox.Sensor;
using Toybox.Application.Storage as Storage;
using Toybox.Lang;

class DataManager {

    // =========================================================
    // 1. Global Session Context (전체 다이빙 세션 관리)
    // =========================================================
    var sessionActivities = []; // 완료된 개별 활동들을 모아두는 리스트
    const SESSION_KEY = "temp_session_acts"; // 앱 종료 대비 임시 저장 키
    const GLOBAL_START_KEY = "global_start_epoch";

    var globalStartEpoch = null;
    var globalStartPos = null;
    var globalEndPos = null;

    // =========================================================
    // 2. Current Activity Context (현재 수행 중인 개별 작업)
    // =========================================================
    var gridId = "A-1";
    var workType = 0; // 0: Urchin, 1: Seaweed, 2: Other
    var totalCount = 0;
    var currentId = 100;
    var defaultStatus = "NEW";
    
    // State Flags
    var isReadyToStart = false; 
    var isIdSet = false;
    var isSessionStarted = false; // 녹화 중 여부

    // 현재 활동의 시공간 정보
    var actStartEpoch = null; 
    var actStartPos = null;
    var actEndPos = null;

    var workLogs = [];
    
    // FIT Fields
    var fGrid, fWorkType, fTotal, fDefaultStatus, fStartId, fCurrentCount;

    function initialize() {
        // 앱 재시작 시 기존에 쌓아둔 데이터가 있으면 복구
        var savedActs = Storage.getValue(SESSION_KEY);
        if (savedActs instanceof Lang.Array) {
            sessionActivities = savedActs;
        } else {
            sessionActivities = [];
        }
        
        // 전체 세션 시작 시간 복구
        globalStartEpoch = Storage.getValue(GLOBAL_START_KEY);
        
        // 현재 활동 변수 초기화
        resetCurrentActivity();
    }

    // [Action] 전체 세션 초기화 (업로드 성공 후 호출)
    function clearAllSession() {
        sessionActivities = [];
        globalStartEpoch = null;
        globalStartPos = null;
        globalEndPos = null;
        
        Storage.deleteValue(SESSION_KEY);
        Storage.deleteValue(GLOBAL_START_KEY);
        
        resetCurrentActivity();
        Sys.println("DataManager: All Session Data Cleared.");
    }

    // [Action] 현재 활동 변수만 초기화 (다음 Grid 작업을 위해)
    function resetCurrentActivity() {
        actStartPos = null;
        actEndPos = null;
        actStartEpoch = null;
        workLogs = [];
        
        isReadyToStart = false;
        isIdSet = false;
        isSessionStarted = false;
        totalCount = 0;
        
        // ID는 연속성을 위해 초기화하지 않음 (Seaweed ID 유지)
        // gridId도 유지 (보통 같은 구역에서 작업하므로)
        Sys.println("DataManager: Current Activity Reset.");
    }

    function setupFitFields(session) {
        fGrid          = session.createField("grid_id",        0, Toybox.FitContributor.DATA_TYPE_STRING, {:count=>16, :mesgType=>Toybox.FitContributor.MESG_TYPE_SESSION});
        fWorkType      = session.createField("work_type",      1, Toybox.FitContributor.DATA_TYPE_UINT8,  {:mesgType=>Toybox.FitContributor.MESG_TYPE_SESSION});
        fTotal         = session.createField("total_count",    2, Toybox.FitContributor.DATA_TYPE_UINT16, {:mesgType=>Toybox.FitContributor.MESG_TYPE_SESSION});
        fDefaultStatus = session.createField("default_status", 3, Toybox.FitContributor.DATA_TYPE_STRING, {:count=>8,  :mesgType=>Toybox.FitContributor.MESG_TYPE_SESSION});
        fStartId       = session.createField("start_id",       4, Toybox.FitContributor.DATA_TYPE_UINT16, {:mesgType=>Toybox.FitContributor.MESG_TYPE_SESSION});
        fCurrentCount  = session.createField("current_count",  5, Toybox.FitContributor.DATA_TYPE_UINT16, {:mesgType=>Toybox.FitContributor.MESG_TYPE_LAP});

        if(fGrid != null) { fGrid.setData(gridId); }
        if(fWorkType != null) { fWorkType.setData(workType); }
        if(fStartId != null) { fStartId.setData(currentId); }
        
        if(fTotal != null) { fTotal.setData(0); }
        if(fCurrentCount != null) { fCurrentCount.setData(0); }
        
        // 현재 활동 시작 시간 기록
        actStartEpoch = Time.now().value();

        // 전체 세션 시작 시간이 없으면 지금을 시작으로 설정 (최초 활동 시)
        if (globalStartEpoch == null) {
            globalStartEpoch = actStartEpoch;
            Storage.setValue(GLOBAL_START_KEY, globalStartEpoch);
        }
    }

    function updateLocation(info) {
        if (info == null || info.position == null) { return; }
        
        // 1. 현재 활동 위치 갱신
        if (actStartPos == null) {
            actStartPos = info.position;
        } else {
            actEndPos = info.position;
        }

        // 2. 전체 세션 위치 갱신 (요약 정보용)
        if (globalStartPos == null) {
            globalStartPos = info.position; // 첫 활동의 시작점
        }
        globalEndPos = info.position; // 계속 갱신 (마지막 활동의 종료점)
    }

    function setStartLocation(info) {
        if (info != null) { actStartPos = info.position; }
    }

    // --- Data Collection Helpers ---

    function _getSensorData() {
        var info = Sensor.getInfo();
        var depth = 0.0;
        var temp = 0.0;
        
        if (info has :temperature && info.temperature != null) { temp = info.temperature; }
        if (info has :pressure && info.pressure != null) {
            var p = info.pressure;
            if (p > 100000) {
                depth = (p - 101325) / 9806.65; 
                if (depth < 0) { depth = 0.0; }
            }
        }
        return [depth, temp];
    }

    function _elapsed() {
        if (actStartEpoch == null) { actStartEpoch = Time.now().value(); }
        return Time.now().value() - actStartEpoch;
    }

    // --- Recording Methods ---

    function addUrchinEvent() {
        totalCount += 1;
        var t = _elapsed();
        var sensors = _getSensorData(); 
        // [Format]: [Time, Depth, Temp, TotalCount]
        workLogs.add([t, sensors[0], sensors[1], totalCount]); 
        _updateFitCounts();
        Sys.println("Urchin +1 -> " + totalCount);
    }

    function addSeaweedEvent(status) {
        var t = _elapsed();
        var sensors = _getSensorData();
        var unitId = currentId;
        currentId += 1; // ID 증가
        
        // [Format]: [Time, Depth, Temp, UnitID, StatusCode]
        workLogs.add([t, sensors[0], sensors[1], unitId, status]);
        
        totalCount += 1;
        _updateFitCounts();
        Sys.println("Seaweed #" + unitId);
    }

    // 기타 활동 기록
    function addOtherEvent() {
        totalCount += 1;
        var t = _elapsed();
        var sensors = _getSensorData();
        // 포맷: [Time, Depth, Temp, Count] (성게와 동일)
        workLogs.add([t, sensors[0], sensors[1], totalCount]);
        _updateFitCounts();
        Sys.println("Other Point Saved -> " + totalCount);
    }
    
    function decrementTotalCount() {
        if (totalCount > 0) {
            totalCount -= 1;
            _updateFitCounts();
            Sys.println("Correction: Count -1 -> " + totalCount);
        }
    }
    
    function _updateFitCounts() {
        if (fTotal != null) { fTotal.setData(totalCount); }
        if (fCurrentCount != null) { fCurrentCount.setData(totalCount); }
    }
    
    function writeFinalFitFields() {
        if (fTotal != null) { fTotal.setData(totalCount); }
        if (fDefaultStatus != null) { fDefaultStatus.setData(defaultStatus); }
    }

    function _statusToCode(s) {
        if (s.equals("NEW"))  { return 0; }
        if (s.equals("GOOD")) { return 1; }
        if (s.equals("FAIR")) { return 2; }
        if (s.equals("POOR")) { return 3; }
        if (s.equals("DEAD")) { return 4; }
        if (s.equals("LOST")) { return 5; }
        return 0;
    }

    // =========================================================
    // 3. Accumulation & Final Payload Generation
    // =========================================================

    // 현재 활동(Activity)이 끝났을 때 리스트에 추가하는 함수
    function accumulateCurrentActivity() {
        // 현재 활동 정보 구조화
        var activityInfo = {
            "activityType" => (workType == 0) ? "URCHIN_REMOVAL" : "SEAWEED_TRANSPLANT",
            "gridId"       => gridId,
            "totalCount"   => totalCount,
            "work_logs"    => workLogs 
        };

        if (workType == 2) {
             activityInfo["activityType"] = "OTHER_ACTIVITY";
        }

        // 메모리 리스트에 추가
        sessionActivities.add(activityInfo);
        
        // 영구 저장소 업데이트 (크래시 복구용)
        Storage.setValue(SESSION_KEY, sessionActivities);
        
        Sys.println("DataManager: Activity Accumulated. Total Count: " + sessionActivities.size());
        
        // 변수 리셋
        resetCurrentActivity();
    }

    // [Modified] 최종 전송용 JSON 구조 생성 (userId를 페어링 코드로 변환)
    function getFinalSessionPayload() {
        // 1. 위치 정보 계산
        var sLat = null; var sLon = null;
        if (globalStartPos != null) {
            var deg = globalStartPos.toDegrees();
            sLat = deg[0]; sLon = deg[1];
        }
        
        var eLat = null; var eLon = null;
        if (globalEndPos != null) {
            var deg = globalEndPos.toDegrees();
            eLat = deg[0]; eLon = deg[1];
        } else if (globalStartPos != null) {
            // 위치 이동이 없었으면 시작 위치 사용
            var deg = globalStartPos.toDegrees();
            eLat = deg[0]; eLon = deg[1];
        }
        
        var startT = (globalStartEpoch != null) ? globalStartEpoch : Time.now().value();

        // 2. 기기 ID 추출
        var mySettings = Sys.getDeviceSettings();
        var rawDeviceId = mySettings.uniqueIdentifier;
        if (rawDeviceId == null) { rawDeviceId = "UNKNOWN_DEVICE"; }

        // [New] 페어링 코드 생성 (userId로 사용)
        var finalUserId = _generatePairingCode(rawDeviceId);

        // 3. Summary 구성
        // Unix Timestamp
        var summary = {
            "userId"     => finalUserId, // rawDeviceId 대신 pairing code 전송
            "startTime"  => startT,
            "endTime"    => Time.now().value(),
            "startLat"   => sLat, "startLon" => sLon,
            "endLat"     => eLat, "endLon"   => eLon
        };

        // 4. 최종 구조 반환
        return {
            "summary"    => summary,
            "activities" => sessionActivities
        };
    }
    
    // [New] DeviceInfoView와 동일한 로직으로 페어링 코드 생성
    // (서버에서 이 코드를 키로 유저를 식별함)
    function _generatePairingCode(deviceId) {
        var salt = "OCDIVER"; // DeviceInfoView와 반드시 동일해야 함
        var input = deviceId + salt;
        
        // FNV-1a Hash (32-bit)
        var hash = 0x811c9dc5; 
        var prime = 0x01000193;

        var bytes = input.toUtf8Array();
        
        for (var i = 0; i < bytes.size(); i++) {
            hash = hash ^ bytes[i];
            hash = hash * prime;
        }

        // Base31 Encoding
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
    
    function hasActivitiesToSend() {
        return (sessionActivities.size() > 0);
    }
}