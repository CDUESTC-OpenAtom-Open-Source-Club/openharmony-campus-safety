import { common } from '@kit.AbilityKit';

import { EventRepository } from './EventRepository';
import { RdbEventStore } from './store/RdbEventStore';

/**
 * Repository 初始化入口（C 模块）。
 *
 * 应用启动时开库、建表、把 RDB 数据灌入缓存；
 * 页面出现前完成，避免读空数据的竞态。
 */
export class RepositoryManager {
  private static initialized: boolean = false;

  static async init(context: common.Context): Promise<void> {
    if (RepositoryManager.initialized) {
      return;
    }
    const repository: EventRepository = EventRepository.getInstance();
    const store: RdbEventStore = await RdbEventStore.create(context);
    repository.setStore(store);
    await repository.load();
    RepositoryManager.initialized = true;
  }
}
