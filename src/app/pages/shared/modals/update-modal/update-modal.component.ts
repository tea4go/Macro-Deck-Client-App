import { Component, Input } from '@angular/core';
import { IonicModule, ModalController, AlertController } from "@ionic/angular";
import { TranslatePipe, TranslateService } from "@ngx-translate/core";
import { UpdateService, UpdateInfo } from "../../../../services/update/update.service";
import { LoadingService } from "../../../../services/loading/loading.service";
import { environment } from "../../../../../environments/environment";

/** 发现新版本时的提示弹窗：显示版本号与更新说明，支持 立即更新 / 稍后 / 跳过此版本 */
@Component({
  selector: 'app-update-modal',
  templateUrl: './update-modal.component.html',
  styleUrls: ['./update-modal.component.scss'],
  imports: [
    IonicModule,
    TranslatePipe
  ]
})
export class UpdateModalComponent {

  /** 检查更新得到的信息（由 present 时传入） */
  @Input() info!: UpdateInfo;

  /** 供模板显示当前版本 */
  protected readonly environment = environment;

  constructor(private modalController: ModalController,
              private alertController: AlertController,
              private updateService: UpdateService,
              private loadingService: LoadingService,
              private translate: TranslateService) { }

  /** 立即更新：下载 APK 并触发系统安装器 */
  async updateNow() {
    await this.loadingService.showLoading(this.translate.instant('update.downloading'));
    try {
      await this.updateService.downloadAndInstall(this.info.downloadUrl, this.info.versionCode);
      await this.loadingService.dismiss();
      await this.modalController.dismiss(null, 'updated');
    } catch (e) {
      await this.loadingService.dismiss();
      // 下载/安装失败：提示用户，弹窗保留以便重试
      const alert = await this.alertController.create({
        header: this.translate.instant('update.downloadFailedTitle'),
        message: this.translate.instant('update.downloadFailedMessage'),
        buttons: [this.translate.instant('common.ok')]
      });
      await alert.present();
    }
  }

  /** 稍后：关闭弹窗，下次启动仍会提示 */
  async later() {
    await this.modalController.dismiss(null, 'later');
  }

  /** 跳过此版本：记住该版本号，下次不再提示（更新的版本才再提示） */
  async skip() {
    await this.updateService.skipVersion(this.info.versionCode);
    await this.modalController.dismiss(null, 'skipped');
  }
}
