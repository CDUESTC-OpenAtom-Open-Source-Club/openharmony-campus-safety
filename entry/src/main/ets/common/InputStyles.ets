import { AppTheme } from './AppTheme';

/** Native form styling shared by all pages; validation and field labels stay local. */
export class CampusInputStyle implements AttributeModifier<TextInputAttribute> {
  private invalid: boolean;
  constructor(invalid: boolean = false) { this.invalid = invalid; }
  applyNormalAttribute(input: TextInputAttribute): void {
    input.placeholderColor(AppTheme.inputPlaceholder)
      .placeholderFont({ size: AppTheme.inputTextSize, weight: FontWeight.Normal })
      .fontSize(AppTheme.inputTextSize).fontColor(AppTheme.ink).caretColor(AppTheme.accent)
      .height(48).padding({ left: 14, right: 14 }).borderRadius(AppTheme.inputRadius)
      .backgroundColor(AppTheme.surface).border({ width: 1, color: this.invalid ? AppTheme.danger : AppTheme.line });
  }
  applyFocusedAttribute(input: TextInputAttribute): void {
    input.border({ width: 1, color: this.invalid ? AppTheme.danger : AppTheme.accent });
  }
}

export class CampusTextAreaStyle implements AttributeModifier<TextAreaAttribute> {
  applyNormalAttribute(input: TextAreaAttribute): void {
    input.placeholderColor(AppTheme.inputPlaceholder)
      .placeholderFont({ size: AppTheme.inputTextSize, weight: FontWeight.Normal })
      .fontSize(AppTheme.inputTextSize).fontColor(AppTheme.ink).caretColor(AppTheme.accent)
      .padding(14).borderRadius(AppTheme.inputRadius).backgroundColor(AppTheme.surface)
      .border({ width: 1, color: AppTheme.line });
  }
  applyFocusedAttribute(input: TextAreaAttribute): void {
    input.border({ width: 1, color: AppTheme.accent });
  }
}
