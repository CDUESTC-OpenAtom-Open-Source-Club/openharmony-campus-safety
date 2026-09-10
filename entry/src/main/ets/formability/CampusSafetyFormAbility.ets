import { Want } from '@kit.AbilityKit';
import { formBindingData, FormExtensionAbility, formInfo, formProvider } from '@kit.FormKit';
import { AccountService } from '../service/AccountService';
import { RepositoryManager } from '../repository/RepositoryManager';
import { CampusSafetyCardService } from '../service/CampusSafetyCardService';

/** 校园安全服务卡片提供方。 */
export default class CampusSafetyFormAbility extends FormExtensionAbility {
  private initialized: boolean = false;

  onAddForm(want: Want) {
    const formId: string = this.getFormId(want);
    if (formId !== '') {
      this.refreshForm(formId);
    }
    return formBindingData.createFormBindingData(CampusSafetyCardService.createBindingData());
  }

  onUpdateForm(formId: string): void {
    this.refreshForm(formId);
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }

  private getFormId(want: Want): string {
    const params = want.parameters;
    if (params === undefined) {
      return '';
    }
    const value = params['ohos.extra.param.key.form_identity'];
    return typeof value === 'string' ? value : '';
  }

  private async refreshForm(formId: string): Promise<void> {
    try {
      await this.initData();
      const bindingData = formBindingData.createFormBindingData(CampusSafetyCardService.createBindingData());
      await formProvider.updateForm(formId, bindingData);
    } catch (error) {
      console.error('CampusSafetyFormAbility refresh failed: ' + JSON.stringify(error));
    }
  }

  private async initData(): Promise<void> {
    if (this.initialized) {
      return;
    }
    const context = this.context.getApplicationContext();
    await AccountService.init(context);
    await RepositoryManager.init(context);
    this.initialized = true;
  }
}
