# OC Diver (Garmin Watch Client)

**Ocean Keeper** 프로젝트를 위한 Garmin Descent G1용 워치 클라이언트 애플리케이션입니다.

##  기능 (Features)
- **활동 기록**: 성게 제거(Urchin Removal), 해초 이식(Seaweed Transplant), 기타 활동 기록.
- **위치 추적**: 입수 및 출수 위치 GPS 자동 기록.
- **오프라인 저장**: 다이빙 중 데이터 로컬 저장 및 일괄 전송 기능.
- **UI 최적화**: Descent G1(흑백/원형)에 최적화된 가독성 높은 UI.

## 설치 및 빌드 설정 (Setup)

이 저장소에는 보안상의 이유로 strings.xml 파일이 제외되어 있습니다.
빌드를 위해선 아래 내용을 참고하여 파일을 직접 생성해야 합니다.

1. resources/strings.xml 파일을 생성합니다.
2. 아래 내용을 붙여넣고, 본인의 API URL과 Key를 입력하세요.

```
<strings>
    <string id="AppName">OC Diver</string>

    <string id="ApiUrl">YOUR_API_URL_HERE</string>
    <string id="ApiKey">YOUR_API_KEY_HERE</string>

    <string id="MenuUrchin">Urchin Removal</string>
    <string id="MenuSeaweed">Seaweed Transplant</string>
    <string id="MenuOther">Other Activity</string>
    <string id="MenuInfo">Device Info</string>
    
    <string id="OrgLine1">OCEAN</string>
    <string id="OrgLine2">CAMPUS</string>
    <string id="InfoTitle">MY DEVICE ID</string>
    <string id="StatusNew">NEW</string>
    <string id="StatusGood">GOOD</string>
    <string id="StatusFair">FAIR</string>
    <string id="StatusPoor">POOR</string>
    <string id="StatusDead">DEAD</string>
    <string id="StatusLost">LOST</string>
    
    <string id="MenuPaused">Paused</string>
    <string id="MenuResume">Resume</string>
    <string id="MenuSave">Save &amp; End</string>
    <string id="MenuDiscard">Discard</string>

    <string id="MsgGridPrefix">Grid: </string>
    <string id="MsgRecording">Recording...</string>
    <string id="MsgReady">Ready to Dive</string>
    <string id="MsgResetInfo">(Press Start to Reset)</string>
    <string id="MsgPointSaved">Point Saved!</string>

    <string id="MsgUploading">Uploading...</string>
    <string id="MsgSuccess">Upload Success!</string>
    <string id="MsgSavedOffline">Saved Offline</string>

    <string id="GpsWaiting">Waiting for GPS...</string>
    <string id="GpsReady">GPS READY</string>
    <string id="GpsFail">NO GPS SIGNAL</string>
</strings>
```

## 지원 기기 (Supported Devices)
Garmin Descent 시리즈 다이빙 컴퓨터를 지원합니다.
- **Descent G1** (Solar 포함)
- **Descent Mk2** (Mk2, Mk2i, Mk2s)
- **Descent Mk3** (Mk3, Mk3i 43mm/51mm)