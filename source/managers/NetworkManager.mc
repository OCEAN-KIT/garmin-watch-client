using Toybox.Communications as Comm;
using Toybox.System as Sys;
using Toybox.WatchUi as UI;
using Toybox.Lang;
using Toybox.Application.Storage as Storage;

class NetworkManager {

    var apiUrl;
    var apiKey;
    const QUEUE_KEY = "upload_queue";

    var _uploadCb;        
    var _currentPayload;  

    var _syncCb;          
    var _syncQueue;       
    var _syncIndex;       

    function initialize() {
        apiUrl = UI.loadResource(Rez.Strings.ApiUrl);
        apiKey = UI.loadResource(Rez.Strings.ApiKey);
    }

    function uploadData(payload, cb) {
        _uploadCb       = cb;
        _currentPayload = payload;

        Sys.println("--------------------------------------------------");
        Sys.println("[DEBUG] Payload to verify Sensor Data:");
        Sys.println(payload); 
        Sys.println("--------------------------------------------------");

        var options = {
            :method       => Comm.HTTP_REQUEST_METHOD_POST,
            :headers      => {
                "Content-Type"    => Comm.REQUEST_CONTENT_TYPE_JSON,
                "X-WATCH-API-KEY" => apiKey
            },
            :responseType => Comm.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        Comm.makeWebRequest(
            apiUrl,
            payload,
            options,
            method(:onUploadResponse)
        );
    }

    function onUploadResponse(code as Lang.Number, data as Lang.Dictionary or Lang.String or Null) as Void {
        var ok = (code >= 200 && code < 300);

        if (!ok && _currentPayload != null) {
            saveToStorage(_currentPayload);
            Sys.println("Upload failed, queued offline. code=" + code);
        } else {
            Sys.println("Upload success. code=" + code);
            Sys.println("Response Data: " + data);
        }

        if (_uploadCb != null) {
            _uploadCb.invoke(ok, code, data);
        }

        _currentPayload = null;
        _uploadCb       = null;
    }

    function saveToStorage(payload) as Void {
        if (payload == null) { return; }

        var raw = Storage.getValue(QUEUE_KEY);
        var q   = (raw instanceof Lang.Array) ? raw : [];

        q.add(payload);
        Storage.setValue(QUEUE_KEY, q);

        Sys.println("Saved locally. queued=" + q.size());
    }

    function hasOfflineItems() as Lang.Boolean {
        var raw = Storage.getValue(QUEUE_KEY);
        return (raw instanceof Lang.Array) && raw.size() > 0;
    }

    function syncOffline(cb) as Void {
        var raw = Storage.getValue(QUEUE_KEY);
        var q   = (raw instanceof Lang.Array) ? raw : [];

        if (q.size() == 0) {
            // [Fixed] 인자 개수 부족 에러 해결 (true, 0, null) -> 3개 전달 필수
            if (cb != null) { cb.invoke(true, 0, null); }
            return;
        }

        _syncCb    = cb;
        _syncQueue = q;
        _syncIndex = 0;

        _syncNext();
    }

    function _syncNext() as Void {
        if (_syncQueue == null || _syncIndex >= _syncQueue.size()) {
            Storage.setValue(QUEUE_KEY, _syncQueue);
            if (_syncCb != null) { _syncCb.invoke(true, _syncIndex, null); } // 여기도 안전하게 null 추가
            _syncQueue = null;
            _syncCb    = null;
            return;
        }

        _currentPayload = _syncQueue[_syncIndex];

        var options = {
            :method       => Comm.HTTP_REQUEST_METHOD_POST,
            :headers      => {
                "Content-Type"    => Comm.REQUEST_CONTENT_TYPE_JSON,
                "X-WATCH-API-KEY" => apiKey
            },
            :responseType => Comm.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        Comm.makeWebRequest(
            apiUrl,
            _currentPayload,
            options,
            method(:onSyncResponse)
        );
    }

    function onSyncResponse(code as Lang.Number, data as Lang.Dictionary or Lang.String or Null) as Void {
        var ok = (code >= 200 && code < 300);

        if (ok) {
            Sys.println("Sync item " + _syncIndex + " success.");
            _syncQueue.remove(_syncIndex);
            Storage.setValue(QUEUE_KEY, _syncQueue);
            _syncNext(); 
        } else {
            Sys.println("Sync failed at " + _syncIndex + ", code=" + code);
            if (_syncCb != null) { _syncCb.invoke(false, code, null); } // 실패 시에도 인자 3개
            _syncQueue = null;
            _syncCb    = null;
        }
    }
}