import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';

/** 系统图片选择与应用私有目录持久化。 */
export class AttachmentService {
  static readonly MAX_COUNT: number = 3;
  static readonly MAX_FILE_SIZE: number = 10 * 1024 * 1024;

  static async selectEvidence(context: common.Context): Promise<string[]> {
    const picker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
    const options: photoAccessHelper.PhotoSelectOptions = {
      MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
      maxSelectNumber: AttachmentService.MAX_COUNT,
      isOriginalSupported: false
    };
    const result: photoAccessHelper.PhotoSelectResult = await picker.select(options);
    const evidenceDir: string = context.filesDir + '/evidence';
    if (!fs.accessSync(evidenceDir)) {
      fs.mkdirSync(evidenceDir);
    }
    const storedPaths: string[] = [];
    for (let index: number = 0; index < result.photoUris.length; index++) {
      const targetPath: string = evidenceDir + '/evidence_' + Date.now().toString() + '_' + index.toString() + '.jpg';
      fs.copyFileSync(result.photoUris[index], targetPath);
      const stat: fs.Stat = fs.statSync(targetPath);
      if (stat.size > AttachmentService.MAX_FILE_SIZE) {
        fs.unlinkSync(targetPath);
      } else {
        storedPaths.push(targetPath);
      }
    }
    return storedPaths;
  }

  static remove(path: string): void {
    if (path !== '' && fs.accessSync(path)) {
      fs.unlinkSync(path);
    }
  }
}
