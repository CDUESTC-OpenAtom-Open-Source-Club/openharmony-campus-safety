package com.example.hongmengzhian;

import android.app.KeyguardManager;
import android.app.Activity;
import android.content.Context;
import android.content.SharedPreferences;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;
import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import java.util.Iterator;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;
import org.json.JSONObject;
import ohos.ace.adapter.capability.bridge.BridgeManager;
import ohos.ace.adapter.capability.bridge.BridgePlugin;
import ohos.ace.adapter.capability.bridge.TaskOption;

/** Native capabilities absent from the bundled ArkUI-X plugins. No secret logging. */
public final class CampusPlatformBridge extends BridgePlugin {
    private static final String KEY = "campus.ai.encryption.v1";
    private final Context context;
    private final Activity activity;
    private final SharedPreferences records;
    private final AiHttpTransport network = new AiHttpTransport();

    public CampusPlatformBridge(Context context, BridgeManager manager) {
        // A concurrent task queue keeps network/Keystore work off the main thread
        // and lets cancellation execute while a network request is blocked.
        super(context, "CampusPlatform", manager, BridgeType.JSON_TYPE, new TaskOption(false));
        this.context = context.getApplicationContext();
        this.activity = (Activity) context;
        records = this.context.getSharedPreferences("ai_encrypted_v1", Context.MODE_PRIVATE);
    }

    private static String reply(boolean ok, String value) {
        try { return new JSONObject().put("ok", ok).put("value", value).toString(); }
        catch (Exception ignored) { return "{\"ok\":false,\"value\":\"\"}"; }
    }

    private void requireUnlocked() {
        KeyguardManager manager = (KeyguardManager) context.getSystemService(Context.KEYGUARD_SERVICE);
        if (manager == null || manager.isDeviceLocked()) throw new IllegalStateException();
    }

    private synchronized SecretKey key() throws Exception {
        KeyStore store = KeyStore.getInstance("AndroidKeyStore");
        store.load(null);
        if (!store.containsAlias(KEY)) {
            KeyGenerator generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore");
            generator.init(new KeyGenParameterSpec.Builder(KEY,
                KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true).setKeySize(256).build());
            generator.generateKey();
        }
        return (SecretKey) store.getKey(KEY, null);
    }

    private static void checkAlias(String alias) {
        if (!alias.startsWith("campus.ai.v1.") || alias.length() > 512) throw new IllegalArgumentException();
    }

    public String saveConfig(String payload) {
        try {
            requireUnlocked();
            JSONObject record = new JSONObject(payload);
            String alias = record.getString("alias"); checkAlias(alias);
            byte[] value = record.getString("value").getBytes(StandardCharsets.UTF_8);
            if (value.length > 16384) throw new IllegalArgumentException();
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, key());
            cipher.updateAAD(alias.getBytes(StandardCharsets.UTF_8));
            String encrypted = Base64.encodeToString(cipher.getIV(), Base64.NO_WRAP) + ":" +
                Base64.encodeToString(cipher.doFinal(value), Base64.NO_WRAP);
            if (!records.edit().putString(alias, encrypted).commit()) throw new IllegalStateException();
            return reply(true, "");
        } catch (Exception ignored) { return reply(false, ""); }
    }

    public String loadConfig(String alias) {
        try {
            requireUnlocked(); checkAlias(alias);
            String encrypted = records.getString(alias, null);
            if (encrypted == null) return reply(true, "");
            String[] parts = encrypted.split(":", -1);
            if (parts.length != 2) throw new IllegalArgumentException();
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, key(), new GCMParameterSpec(128, Base64.decode(parts[0], Base64.NO_WRAP)));
            cipher.updateAAD(alias.getBytes(StandardCharsets.UTF_8));
            return reply(true, new String(cipher.doFinal(Base64.decode(parts[1], Base64.NO_WRAP)), StandardCharsets.UTF_8));
        } catch (Exception ignored) { return reply(false, ""); }
    }

    public String removeConfig(String alias) {
        try {
            requireUnlocked(); checkAlias(alias);
            if (!records.edit().remove(alias).commit()) throw new IllegalStateException();
            return reply(true, "");
        } catch (Exception ignored) { return reply(false, ""); }
    }

    public String enablePrivacy(String ignored) {
        try {
            CountDownLatch ready = new CountDownLatch(1);
            AtomicBoolean enabled = new AtomicBoolean(false);
            activity.runOnUiThread(() -> {
                try {
                    activity.getWindow().addFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE);
                    enabled.set(true);
                } catch (RuntimeException error) { /* Report failure without crashing the UI. */ }
                finally { ready.countDown(); }
            });
            return reply(ready.await(2, TimeUnit.SECONDS) && enabled.get(), "");
        } catch (Exception error) { return reply(false, ""); }
    }

    public String request(String payload) {
        try {
            JSONObject spec = new JSONObject(payload);
            JSONObject jsonHeaders = spec.getJSONObject("headers");
            Map<String, String> headers = new HashMap<>();
            Iterator<String> names = jsonHeaders.keys();
            while (names.hasNext()) { String name = names.next(); headers.put(name, jsonHeaders.getString(name)); }
            AiHttpTransport.Result result = network.request(spec.getString("id"), spec.getString("endpoint"),
                spec.getString("method"), headers, spec.getString("body"), spec.getInt("timeout"), spec.getInt("maxBytes"));
            return reply(true, new JSONObject().put("status", result.status).put("body", result.body).toString());
        } catch (Exception ignored) { return reply(false, ""); }
    }

    public String cancelRequest(String id) { network.cancel(id); return reply(true, ""); }
    public void shutdown() { network.shutdown(); }
}
