import {Component, EventEmitter, OnInit} from '@angular/core';
import {AlertController, IonicModule, ModalController, Platform} from "@ionic/angular";
import {SettingsService} from "../../../../services/settings/settings.service";
import {WakelockService} from "../../../../services/wakelock/wakelock.service";
import {ScreenOrientationService} from "../../../../services/screen-orientation/screen-orientation.service";
import {SslHandler} from "../../../../../../capacitor_plugins/sslhandler/src";
import {environment} from "../../../../../environments/environment.web";
import {DiagnosticService} from "../../../../services/diagnostic/diagnostic.service";
import {ThemeService} from "../../../../services/theme/theme.service";
import {ButtonWidgetBorderStyle} from "../../../../widget-content-components/button-widget/button-widget-border-style";
import {FormsModule} from "@angular/forms";
import {TranslatePipe, TranslateService} from "@ngx-translate/core";
import {I18nService} from "../../../../services/i18n/i18n.service";
import {LanguageType} from "../../../../enums/language-type";
import {UpdateService} from "../../../../services/update/update.service";
import {UpdateModalComponent} from "../update-modal/update-modal.component";

/** 设置弹窗组件，提供应用各项配置的界面交互 */
@Component({
  selector: 'app-settings-modal',
  templateUrl: './settings-modal.component.html',
  styleUrls: ['./settings-modal.component.scss'],
  imports: [
    IonicModule,
    FormsModule,
    TranslatePipe
  ]
})
export class SettingsModalComponent  implements OnInit {

  /** 设置应用后触发的事件 */
  public static settingsApplied: EventEmitter<any> = new EventEmitter();

  /** 是否为 Android Oreo 平台 */
  isAndroidOreo: boolean = false;
  /** 是否启用屏幕常亮 */
  preventScreenTimeout: boolean = false;
  /** 是否显示菜单按钮 */
  showMenuButton: boolean = false;
  /** 是否跳过 SSL 证书验证 */
  skipSslValidation: boolean = false;
  /** 按钮长按延迟时间（毫秒） */
  buttonLongPressDelay: number = 1000;
  /** 外观主题类型（字符串形式的枚举值） */
  appearanceType: string = "0";
  /** 屏幕方向（字符串形式的枚举值） */
  screenOrientation: string = "0";
  /** USB 是否自动连接 */
  usbAutoConnect: boolean = false;
  /** USB 连接端口号 */
  usbPort: number = 8191;
  /** USB 连接是否使用 SSL */
  usbUseSsl: boolean = false;
  /** 按钮微件边框样式（字符串形式的枚举值） */
  buttonWidgetBorderStyle: string = "0";
  /** 界面语言（字符串形式的枚举值） */
  language: string = "0";

  constructor(private modalController: ModalController,
              private settingsService: SettingsService,
              private wakelockService: WakelockService,
              private alertController: AlertController,
              private screenOrientationService: ScreenOrientationService,
              public diagnosticService: DiagnosticService,
              private themeService: ThemeService,
              private i18nService: I18nService,
              private translate: TranslateService,
              private updateService: UpdateService) { }

  /**
   * 手动检查更新：有新版本弹更新弹窗，已是最新则提示。
   * 仅 Android 有效。
   */
  async checkForUpdate() {
    const info = await this.updateService.checkForUpdate(false);
    if (info.hasUpdate) {
      const modal = await this.modalController.create({
        component: UpdateModalComponent,
        componentProps: { info }
      });
      await modal.present();
    } else {
      const alert = await this.alertController.create({
        header: this.translate.instant('update.checkForUpdate'),
        message: this.translate.instant('update.alreadyLatest'),
        buttons: [this.translate.instant('common.ok')]
      });
      await alert.present();
    }
  }

  /**
   * 组件初始化回调
   * 加载当前设置并检测 Android Oreo
   */
  async ngOnInit() {
    await this.loadCurrentSettings();
    this.isAndroidOreo = await this.diagnosticService.isAndroidOreo();
  }

  /** 确认保存设置并关闭弹窗 */
  async confirm() {
    await this.saveSettings();
    await this.modalController.dismiss(null, 'confirm');
    SettingsModalComponent.settingsApplied.emit();
  }

  /** 取消并关闭弹窗 */
  async cancel() {
    await this.modalController.dismiss(null, 'cancel');
  }

  /**
   * 保存所有设置到持久化存储
   * 同时立即应用屏幕常亮、屏幕方向、主题和 SSL 验证设置
   */
  async saveSettings() {
    await this.settingsService.setWakeLockEnabled(this.preventScreenTimeout);
    await this.settingsService.setShowMenuButton(this.showMenuButton);
    await this.settingsService.setSkipSslValidation(this.skipSslValidation);
    await this.settingsService.setButtonLongPressDelay(this.buttonLongPressDelay);
    await this.settingsService.setAppearance(Number.parseInt(this.appearanceType));
    await this.settingsService.setScreenOrientation(Number.parseInt(this.screenOrientation));
    await this.settingsService.setUsbAutoConnect(this.usbAutoConnect);
    await this.settingsService.setUsbPort(this.usbPort);
    await this.settingsService.setUsbUseSsl(this.usbUseSsl);
    await this.settingsService.setButtonWidgetBorderStyle(Number.parseInt(this.buttonWidgetBorderStyle));

    // 应用语言设置（即时生效 + 持久化）
    await this.i18nService.setLanguage(Number.parseInt(this.language) as LanguageType);

    // 立即应用各项设置
    await this.wakelockService.updateWakeLock();
    await this.screenOrientationService.updateScreenOrientation();
    await this.themeService.updateTheme();
    if (this.diagnosticService.isAndroid()) {
      SslHandler.skipValidation({value: this.skipSslValidation});
    }
  }

  /** 从持久化存储加载当前设置到界面 */
  async loadCurrentSettings() {
    this.preventScreenTimeout = await this.settingsService.getWakeLockEnabled();
    this.showMenuButton = await this.settingsService.getShowMenuButton();
    this.skipSslValidation = await this.settingsService.getSkipSslValidation();
    this.buttonLongPressDelay = await this.settingsService.getButtonLongPressDelay();
    this.appearanceType = (await this.settingsService.getAppearance()).toString();
    this.screenOrientation = (await this.settingsService.getScreenOrientation()).toString();
    this.usbAutoConnect = await this.settingsService.getUsbAutoConnect();
    this.usbPort = await this.settingsService.getUsbPort();
    this.usbUseSsl = await this.settingsService.getUsbUseSsl();
    this.buttonWidgetBorderStyle = (await this.settingsService.getButtonWidgetBorderStyle()).toString();
    this.language = (await this.settingsService.getLanguage()).toString();
  }

  /**
   * 屏幕常亮设置变化时的回调
   * 启用时显示屏幕烧屏风险警告
   * @param event 开关状态
   */
  async preventScreenTimeoutChange(event: any) {
    if (event !== true) {
      return;
    }

    const alert = await this.alertController.create({
      header: this.translate.instant('common.warning'),
      message: this.translate.instant('settings.screenBurnInWarning'),
      buttons: [this.translate.instant('common.ok')],
    });

    await alert.present();
  }

  /**
   * 菜单按钮设置变化时的回调
   * 关闭时提示通过边缘滑动访问菜单
   * @param event 开关状态
   */
  async displayMenuButtonChange(event: any) {
    if (event !== false) {
      return;
    }

    const alert = await this.alertController.create({
      header: this.translate.instant('common.information'),
      message: this.translate.instant('settings.menuButtonHint'),
      buttons: [this.translate.instant('common.ok')],
    });

    await alert.present();
  }

  /** 检测是否为 Android 平台 */
  public isAndroid() {
    return this.diagnosticService.isAndroid()
  }

  /** 检测是否为 iOS 或 Android 原生平台 */
  public isiOSorAndroid() {
    return this.diagnosticService.isiOSorAndroid();
  }

  protected readonly environment = environment;
}
