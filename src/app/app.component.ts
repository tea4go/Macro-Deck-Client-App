import {AfterViewInit, Component, EventEmitter, OnInit} from '@angular/core';
import {Storage} from "@ionic/storage";
import {WakelockService} from "./services/wakelock/wakelock.service";
import {ScreenOrientationService} from "./services/screen-orientation/screen-orientation.service";
import {SslHandler} from "../../capacitor_plugins/sslhandler/src";
import {SettingsService} from "./services/settings/settings.service";
import {DiagnosticService} from "./services/diagnostic/diagnostic.service";
import {ThemeService} from "./services/theme/theme.service";
import {HomePage} from "./pages/home/home.page";
import {environment} from "../environments/environment";
import {WebHomePage} from "./pages/web-home/web-home.page";
import {App, URLOpenListenerEvent} from "@capacitor/app";
import {QuickSetupQrCodeData} from "./datatypes/quick-setup-qr-code-data";
import {QrCodeScannerComponent} from "./pages/home/modals/add-connection/qr-code-scanner/qr-code-scanner.component";
import {IonicModule, ModalController} from "@ionic/angular";
import {I18nService} from "./services/i18n/i18n.service";
import {UpdateService} from "./services/update/update.service";
import {UpdateModalComponent} from "./pages/shared/modals/update-modal/update-modal.component";
import {SwUpdate, VersionReadyEvent} from "@angular/service-worker";
import {filter} from "rxjs/operators";

/** 应用根组件，负责初始化各项服务并监听深度链接 */
@Component({
  selector: 'app-root',
  templateUrl: 'app.component.html',
  styleUrls: ['app.component.scss'],
  imports: [
    IonicModule
  ]
})
export class AppComponent implements OnInit {
  /** 快速设置链接扫描事件，当通过深度链接接收快速设置数据时触发 */
  public static quickSetupLinkScanned: EventEmitter<QuickSetupQrCodeData> = new EventEmitter();

  constructor(private storage: Storage,
              private wakeLockService: WakelockService,
              private screenOrientationService: ScreenOrientationService,
              private settingsService: SettingsService,
              private diagnosticService: DiagnosticService,
              private themeService: ThemeService,
              private i18nService: I18nService,
              private updateService: UpdateService,
              private modalController: ModalController,
              private swUpdate: SwUpdate) {
  }

  /** 根页面组件，Web 版本使用 WebHomePage，原生版本使用 HomePage */
  rootComponent = environment.webVersion ? WebHomePage : HomePage;

  /**
   * 应用初始化回调
   * 初始化本地存储、语言、屏幕方向、屏幕常亮、主题设置
   * 并在 Android 平台上配置 SSL 证书验证跳过
   */
  async ngOnInit() {
    await this.storage.create();
    await this.i18nService.init();
    await this.screenOrientationService.updateScreenOrientation();
    await this.wakeLockService.updateWakeLock();
    await this.themeService.updateTheme();

    // Android 平台根据用户设置跳过 SSL 证书验证
    if (this.diagnosticService.isAndroid()) {
      let skipSslValidation = await this.settingsService.getSkipSslValidation();
      SslHandler.skipValidation({value: skipSslValidation});
    }

    // 监听深度链接事件，解析快速设置二维码数据
    App.addListener('appUrlOpen', (event: URLOpenListenerEvent) => {
      const dataBase64 = event.url.split("quick-setup/").pop();
      if (dataBase64) {
        const dataJson = atob(dataBase64);
        const data = JSON.parse(dataJson) as QuickSetupQrCodeData;
        AppComponent.quickSetupLinkScanned.emit(data);
      }
    });

    // Service Worker 更新仅在 Web（PWA）平台启用。
    // 原生 Android/iOS 不需要 SW：APK 本身就是更新单元，
    // SW 在 Capacitor 的 http://localhost 环境下会因缓存与当前资源不匹配
    // 导致无限 reload 循环（闪退）。
    if (!this.diagnosticService.isiOSorAndroid()) {
      this.swUpdate.versionUpdates.pipe(
        filter((evt): evt is VersionReadyEvent => evt.type === 'VERSION_READY')
      ).subscribe(() => {
        this.swUpdate.activateUpdate().then(() => document.location.reload());
      });

      if (this.swUpdate.isEnabled) {
        this.swUpdate.checkForUpdate().catch(() => { /* 静默 */ });
      }
    }

    // 启动时静默检查更新（仅 Android，不阻塞启动）
    this.checkForUpdate();
  }

  /**
   * 检查应用更新：有新版本且未被跳过时弹出更新提示弹窗。
   * 静默执行——失败或无更新不打扰用户。
   */
  private async checkForUpdate() {
    try {
      const info = await this.updateService.checkForUpdate(true);
      if (await this.updateService.shouldPrompt(info)) {
        const modal = await this.modalController.create({
          component: UpdateModalComponent,
          componentProps: { info }
        });
        await modal.present();
      }
    } catch {
      // 静默：检查更新失败不影响正常使用
    }
  }
}
