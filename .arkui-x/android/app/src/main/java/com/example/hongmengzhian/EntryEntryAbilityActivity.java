package com.example.hongmengzhian;

import android.os.Bundle;
import ohos.stage.ability.adapter.StageActivity;

public class EntryEntryAbilityActivity extends StageActivity {
    private CampusPlatformBridge platform;

    @Override
    protected void onCreate(Bundle state) {
        platform = new CampusPlatformBridge(this, getBridgeManager());
        setInstanceName("com.example.hongmengzhian:entry:EntryAbility:");
        super.onCreate(state);
    }

    @Override
    protected void onDestroy() {
        if (platform != null) { platform.shutdown(); platform.release(); }
        super.onDestroy();
    }
}
