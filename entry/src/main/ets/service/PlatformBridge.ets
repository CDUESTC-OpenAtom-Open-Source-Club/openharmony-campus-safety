// Loaded only when an AI operation needs it. Missing Android-only modules must
// never prevent the HarmonyOS entry page from loading.
interface BridgeFactory {
  createBridge(name: string): NativeBridge;
}

interface BridgeModule {
  default: BridgeFactory;
}

interface NativeReply {
  ok: boolean;
  value: string;
}

interface NativeBridge {
  callMethod(method: string, ...args: string[]): Promise<string>;
}

export class PlatformBridge {
  private static bridge: NativeBridge | null = null;
  private static checked: boolean = false;
  private static pending: Promise<NativeBridge | null> | null = null;

  static async get(): Promise<NativeBridge | null> {
    if (PlatformBridge.checked) return PlatformBridge.bridge;
    if (PlatformBridge.pending !== null) return PlatformBridge.pending;
    PlatformBridge.pending = PlatformBridge.load();
    return PlatformBridge.pending;
  }

  private static async load(): Promise<NativeBridge | null> {
    try {
      // ArkUI-X's @arkui-x.bridge compiles to this native OHM URL. A variable
      // import keeps the HarmonyOS compiler from requiring an Android SDK API.
      const moduleName: string = '@ohos:bridge';
      const module: BridgeModule = await import(moduleName) as BridgeModule;
      PlatformBridge.bridge = module.default.createBridge('CampusPlatform') as NativeBridge;
    } catch (_) {
      PlatformBridge.bridge = null;
    }
    PlatformBridge.checked = true;
    return PlatformBridge.bridge;
  }

  static async call(method: string, payload: string, timeout: number = 10000): Promise<string> {
    const bridge: NativeBridge | null = await PlatformBridge.get();
    if (bridge === null) throw new Error('Android 原生服务不可用，请更新安装包');
    let timer: number = -1;
    try {
      const raw: string = await Promise.race([
        bridge.callMethod(method, payload),
        new Promise<string>((_, reject) => {
          timer = setTimeout(() => reject(new Error('原生服务响应超时，请重试或更新安装包')), timeout);
        })
      ]);
      const reply: NativeReply = JSON.parse(raw) as NativeReply;
      if (!reply.ok) throw new Error('原生操作失败，请检查网络或解锁设备后重试');
      return reply.value;
    } catch (_) {
      // Native and JSON errors can contain credentials or response bodies.
      throw new Error('原生操作未完成，请检查网络、解锁设备或更新安装包后重试');
    } finally {
      if (timer !== -1) clearTimeout(timer);
    }
  }
}
